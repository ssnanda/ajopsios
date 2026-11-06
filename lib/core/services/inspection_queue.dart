import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_interceptors.dart';
import '../api/ops_api.dart';
import '../storage/secure_storage.dart';

/// One inspection finding waiting to be uploaded.
class InspectionItem {
  final String id; // also the idempotency key sent to the server
  final String siteUrl; // findings only go to the site they were taken for
  final String communityId;
  final String communityName;
  final String address;
  final double? lat;
  final double? lng;
  final String violationType;
  final String notes;
  final String photoPath;
  final int createdAt;
  bool failed;
  String error;
  int attempts;
  bool sending = false; // not persisted: an upload is in flight right now

  InspectionItem({
    required this.id,
    required this.siteUrl,
    required this.communityId,
    required this.communityName,
    required this.address,
    required this.lat,
    required this.lng,
    required this.violationType,
    required this.notes,
    required this.photoPath,
    required this.createdAt,
    this.failed = false,
    this.error = '',
    this.attempts = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id, 'siteUrl': siteUrl, 'communityId': communityId, 'communityName': communityName, 'address': address,
        'lat': lat, 'lng': lng, 'violationType': violationType, 'notes': notes, 'photoPath': photoPath,
        'createdAt': createdAt, 'failed': failed, 'error': error, 'attempts': attempts,
      };

  factory InspectionItem.fromJson(Map<String, dynamic> j) => InspectionItem(
        id: j['id'] as String,
        siteUrl: (j['siteUrl'] ?? '') as String,
        communityId: j['communityId'] as String,
        communityName: (j['communityName'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        violationType: j['violationType'] as String,
        notes: (j['notes'] ?? '') as String,
        photoPath: (j['photoPath'] ?? '') as String,
        createdAt: (j['createdAt'] as num?)?.toInt() ?? 0,
        failed: j['failed'] == true,
        error: (j['error'] ?? '') as String,
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// Inspection findings are saved on the phone first and uploaded in the background, one at a time, so the
/// inspector never waits on a photo upload. Survives app restarts; retries on network errors; a finding the
/// server rejects is kept (marked failed) until it is retried or discarded.
class InspectionQueue extends ChangeNotifier {
  InspectionQueue._();
  static final InspectionQueue instance = InspectionQueue._();

  static const _prefKey = 'inspection_queue_v1';

  final List<InspectionItem> _items = [];
  bool _running = false;
  bool _ready = false;

  List<InspectionItem> get items => List.unmodifiable(_items);
  int get waiting => _items.where((i) => !i.failed).length;
  int get failed => _items.where((i) => i.failed).length;
  bool contains(String id) => _items.any((i) => i.id == id);
  InspectionItem? byId(String id) => _items.where((i) => i.id == id).firstOrNull;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List<dynamic>).map((e) => InspectionItem.fromJson(e as Map<String, dynamic>)));
      } catch (_) {
        // A corrupt queue must never block the app.
      }
    }
    notifyListeners();
    Timer.periodic(const Duration(seconds: 20), (_) => process());
    unawaited(process());
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  /// Saves the finding (copying the photo somewhere durable) and starts uploading. Returns the item id.
  Future<String> enqueue({
    required String communityId,
    required String communityName,
    required String address,
    required double? lat,
    required double? lng,
    required String violationType,
    required String notes,
    required File photo,
  }) async {
    final id = '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}${(_items.length + 1).toRadixString(16)}';
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/inspection_queue');
    await dir.create(recursive: true);
    final saved = await photo.copy('${dir.path}/$id.jpg');
    _items.add(InspectionItem(
      id: id,
      siteUrl: await SecureStorage.instance.getSiteUrl() ?? '',
      communityId: communityId,
      communityName: communityName,
      address: address,
      lat: lat,
      lng: lng,
      violationType: violationType,
      notes: notes,
      photoPath: saved.path,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
    await _save();
    notifyListeners();
    unawaited(process());
    return id;
  }

  Future<void> retry(String id) async {
    final item = byId(id);
    if (item == null) return;
    item
      ..failed = false
      ..error = '';
    await _save();
    notifyListeners();
    unawaited(process());
  }

  /// Takes a finding back out of the queue so it can be edited (the photo file is kept). Null if it is already
  /// uploading or gone.
  Future<InspectionItem?> take(String id) async {
    final item = byId(id);
    if (item == null || item.sending) return null;
    _items.remove(item);
    await _save();
    notifyListeners();
    return item;
  }

  Future<void> discard(String id) async {
    final item = byId(id);
    if (item == null) return;
    _items.remove(item);
    await _deleteFile(item.photoPath);
    await _save();
    notifyListeners();
  }

  Future<void> _deleteFile(String path) async {
    try {
      if (path.isNotEmpty) await File(path).delete();
    } catch (_) {
      // already gone
    }
  }

  Future<void> process() async {
    if (_running || !_ready) return;
    _running = true;
    try {
      final site = await SecureStorage.instance.getSiteUrl() ?? '';
      for (final item in List<InspectionItem>.from(_items)) {
        if (item.failed) continue;
        if (item.siteUrl.isNotEmpty && item.siteUrl != site) continue; // wrong site signed in right now
        final ok = await _send(item);
        if (!ok) break; // network trouble: stop this round, try again later
      }
    } finally {
      _running = false;
    }
  }

  /// true = handled (sent, or permanently failed); false = try again later.
  Future<bool> _send(InspectionItem item) async {
    item.sending = true;
    notifyListeners();
    try {
      await OpsApi.instance.submitInspection(
        communityId: item.communityId,
        address: item.address,
        violationType: item.violationType,
        notes: item.notes,
        lat: item.lat,
        lng: item.lng,
        photoPath: File(item.photoPath).existsSync() ? item.photoPath : null,
        clientRequestId: item.id,
      );
      _items.remove(item);
      await _deleteFile(item.photoPath);
      await _save();
      notifyListeners();
      return true;
    } on DioException catch (e) {
      item.sending = false;
      final inner = e.error;
      final status = e.response?.statusCode ?? (inner is ApiException ? inner.statusCode : 0);
      item.attempts++;
      if (status >= 400 && status < 500 && status != 401 && status != 408 && status != 429) {
        item.failed = true;
        item.error = inner is ApiException ? inner.message : 'The server rejected this finding.';
        await _save();
        notifyListeners();
        return true;
      }
      await _save();
      notifyListeners();
      return false;
    } catch (_) {
      item.sending = false;
      item.attempts++;
      await _save();
      notifyListeners();
      return false;
    }
  }
}
