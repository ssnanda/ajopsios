import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/hoa_models.dart';
import '../../../core/services/inspection_queue.dart';

/// What the inspector sees for a finding already saved in this inspection.
class _Saved {
  final String id; // queue item id
  final String where;
  final String address;
  final String type;
  final String notes;
  final Uint8List? photo;
  const _Saved({required this.id, required this.where, required this.address, required this.type, required this.notes, required this.photo});
}

/// Community inspection. Pick the community once; for each problem: photo -> address (auto, editable) -> violation
/// type -> Next. Findings are saved on the phone and uploaded in the background, so Next is instant. The arrows go
/// back through the findings already taken in this inspection and forward again.
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  static const _prefKey = 'inspect_last_community';
  final _queue = InspectionQueue.instance;

  List<HoaCommunity> _communities = const [];
  bool _loaded = false;
  List<String> _types = const [];
  HoaCommunity? _community;
  String? _loadError;

  final _picker = ImagePicker();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  File? _photo;
  double? _lat;
  double? _lng;
  bool _locating = false;
  String _locateNote = '';
  String? _type;

  // Discovery: while the form is open, check where the inspector is standing and surface what is already on file.
  bool _discovery = true;
  Timer? _discoveryTimer;
  Position? _lastChecked;
  String _nearbyAddress = '';
  HoaAddressInfo? _nearby;
  String _promptedFor = '';
  bool _checking = false;
  // The same lookup for the address of the finding being entered.
  String _lookedUp = '';
  HoaAddressInfo? _atAddress;

  final List<_Saved> _saved = [];
  int? _view; // null = the new-finding form; otherwise an index into _saved

  @override
  void initState() {
    super.initState();
    _load();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 20), (_) => _discover());
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _lookupDebounce?.cancel();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([OpsApi.instance.getHoaCommunities(), OpsApi.instance.getHoaViolationTypes()]);
      final communities = results[0] as List<HoaCommunity>; // all of them, including ones with no units yet
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_prefKey);
      if (!mounted) return;
      setState(() {
        _communities = communities;
        _loaded = true;
        _types = results[1] as List<String>;
        _community = communities.where((c) => c.id == last).firstOrNull ?? (communities.length == 1 ? communities.first : null);
      });
    } catch (e) {
      if (mounted) setState(() { _loadError = e.toString(); _loaded = true; });
    }
  }

  Future<void> _pickCommunity() async {
    final picked = await showModalBottomSheet<HoaCommunity>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CommunitySheet(communities: _communities),
    );
    if (picked == null) return;
    (await SharedPreferences.getInstance()).setString(_prefKey, picked.id);
    setState(() => _community = picked);
  }

  Future<void> _takePhoto() async {
    final shot = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 2200);
    if (shot == null) return;
    setState(() {
      _photo = File(shot.path);
      _addressCtrl.clear();
      _lat = null;
      _lng = null;
    });
    await _locate();
  }

  /// GPS fix -> street address (native reverse geocoding). The address stays editable.
  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _locateNote = '';
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) throw 'Location is turned off.';
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) throw 'Location permission is off for this app.';
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      _lat = pos.latitude;
      _lng = pos.longitude;
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final street = [m.subThoroughfare, m.thoroughfare].where((s) => s != null && s.isNotEmpty).join(' ');
        final region = [m.administrativeArea, m.postalCode].where((s) => s != null && s.isNotEmpty).join(' ');
        _addressCtrl.text = [street, m.locality ?? '', region].where((s) => s.isNotEmpty).join(', ');
      }
      _locateNote = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} · ±${pos.accuracy.round()} m';
    } catch (e) {
      _locateNote = 'Could not detect the address ($e). Type it in.';
    }
    if (mounted) setState(() => _locating = false);
    unawaited(_lookupEntered());
  }

  /// Existing violations for the address in the form (after detection, or when the inspector edits it).
  Future<void> _lookupEntered() async {
    final addr = _addressCtrl.text.trim();
    if (_community == null || addr.isEmpty || addr == _lookedUp) return;
    _lookedUp = addr;
    try {
      final info = await OpsApi.instance.getHoaAddressViolations(communityId: _community!.id, address: addr);
      if (mounted && addr == _addressCtrl.text.trim()) setState(() => _atAddress = info);
    } catch (_) {
      // optional extra; never blocks the form
    }
  }

  /// Every 20 s while the form is showing: if the inspector has moved, find the address and check it.
  Future<void> _discover() async {
    if (!_discovery || _checking || _community == null || _view != null || !mounted) return;
    _checking = true;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)));
      final last = _lastChecked;
      if (last != null && Geolocator.distanceBetween(last.latitude, last.longitude, pos.latitude, pos.longitude) < 25) return; // hasn't moved
      _lastChecked = pos;
      final marks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isEmpty) return;
      final m = marks.first;
      final street = [m.subThoroughfare, m.thoroughfare].where((s) => s != null && s.isNotEmpty).join(' ');
      if (street.isEmpty || street == _nearbyAddress) return;
      final info = await OpsApi.instance.getHoaAddressViolations(communityId: _community!.id, address: [street, m.locality ?? ''].where((s) => s.isNotEmpty).join(', '));
      if (!mounted) return;
      setState(() {
        _nearbyAddress = street;
        _nearby = info;
      });
      // Prompt once per address when something is open there.
      if (info.openCount > 0 && _promptedFor != street) {
        _promptedFor = street;
        HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // discovery is best-effort
    } finally {
      _checking = false;
    }
  }

  void _showViolations(String address, HoaAddressInfo info) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ViolationsSheet(address: address, info: info),
    );
  }

  Timer? _lookupDebounce;

  bool get _ready => _community != null && _photo != null && _addressCtrl.text.trim().isNotEmpty && _type != null;
  bool get _started => _photo != null || _addressCtrl.text.trim().isNotEmpty || _type != null || _notesCtrl.text.trim().isNotEmpty;

  void _clearDraft() {
    _photo = null;
    _lat = null;
    _lng = null;
    _type = null;
    _addressCtrl.clear();
    _notesCtrl.clear();
    _locateNote = '';
    _atAddress = null;
    _lookedUp = '';
  }

  /// Saves the current form to the phone's upload queue and clears it. Instant; the upload happens in the background.
  Future<void> _saveDraft() async {
    final photo = _photo!;
    final address = _addressCtrl.text.trim();
    final type = _type!;
    final notes = _notesCtrl.text.trim();
    final bytes = await photo.readAsBytes();
    final id = await _queue.enqueue(
      communityId: _community!.id,
      communityName: _community!.name,
      address: address,
      lat: _lat,
      lng: _lng,
      violationType: type,
      notes: notes,
      photo: photo,
    );
    if (!mounted) return;
    setState(() {
      _saved.add(_Saved(id: id, where: address.split(',').first, address: address, type: type, notes: notes, photo: bytes));
      _clearDraft();
      _view = null;
    });
  }

  Future<void> _next() async {
    await _saveDraft();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. Uploading in the background.'), duration: Duration(seconds: 2)));
  }

  Future<void> _end() async {
    if (_view == null && _ready) {
      await _saveDraft();
    } else if (_view == null && _started) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Unfinished finding'),
          content: const Text('The current finding is missing a photo, address or type. Discard it and end the inspection?'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard and end'))],
        ),
      );
      if (discard != true) return;
    }
    if (!mounted) return;
    final waiting = _queue.waiting;
    if (waiting > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$waiting finding${waiting == 1 ? '' : 's'} still uploading in the background.')));
    }
    context.go('/dashboard');
  }

  /// Pull a saved finding that has not started uploading back into the form to change it.
  Future<void> _edit(_Saved s, int index) async {
    final item = await _queue.take(s.id);
    if (item == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('That finding is already uploading.')));
      return;
    }
    setState(() {
      _saved.removeAt(index);
      _photo = File(item.photoPath);
      _addressCtrl.text = item.address;
      _lat = item.lat;
      _lng = item.lng;
      _type = item.violationType;
      _notesCtrl.text = item.notes;
      _locateNote = '';
      _view = null;
    });
  }

  // ---- UI ---------------------------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final viewing = _view != null && _view! < _saved.length ? _saved[_view!] : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection'),
        actions: [
          IconButton(
            tooltip: _discovery ? 'Discovery on: checking nearby addresses' : 'Discovery off',
            icon: Icon(_discovery ? Icons.radar_rounded : Icons.location_disabled_rounded),
            onPressed: () => setState(() {
              _discovery = !_discovery;
              if (_discovery) {
                _lastChecked = null;
                _nearbyAddress = '';
                _discover();
              } else {
                _nearby = null;
              }
            }),
          ),
          TextButton.icon(onPressed: _end, icon: const Icon(Icons.flag_rounded), label: const Text('End')),
        ],
      ),
      body: _loadError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
          : Column(children: [
              Expanded(child: viewing != null ? _savedView(viewing, _view!) : _form()),
              _arrowBar(),
            ]),
    );
  }

  /// ◀ previous finding · label · next finding ▶ (the last step forward is the new-finding form).
  Widget _arrowBar() {
    final total = _saved.length;
    final canBack = total > 0 && (_view == null || _view! > 0);
    final canForward = _view != null;
    final label = _view == null ? 'New finding' : 'Finding ${_view! + 1} of $total';
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        child: Row(children: [
          IconButton(
            tooltip: 'Previous finding',
            iconSize: 32,
            onPressed: canBack ? () => setState(() => _view = _view == null ? total - 1 : _view! - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(child: Center(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)))),
          IconButton(
            tooltip: 'Next finding',
            iconSize: 32,
            onPressed: canForward ? () => setState(() => _view = (_view! + 1 >= total) ? null : _view! + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ]),
      ),
    );
  }

  Widget _savedView(_Saved s, int index) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: _queue,
      builder: (context, _) {
        final item = _queue.byId(s.id);
        final sent = item == null;
        return ListView(padding: const EdgeInsets.all(14), children: [
          if (s.photo != null) ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(s.photo!, height: 240, fit: BoxFit.cover)),
          const SizedBox(height: 12),
          Text(s.type, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(s.address, style: TextStyle(color: scheme.onSurfaceVariant)),
          if (s.notes.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.notes)),
          const SizedBox(height: 16),
          if (sent)
            const Row(children: [Icon(Icons.check_circle_rounded, color: Colors.green, size: 20), SizedBox(width: 8), Text('Sent')])
          else if (item.failed) ...[
            Row(children: [const Icon(Icons.error_rounded, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text(item.error.isEmpty ? 'Could not be sent.' : item.error))]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              FilledButton.tonal(onPressed: () => _queue.retry(s.id), child: const Text('Retry')),
              OutlinedButton(onPressed: () => _edit(s, index), child: const Text('Edit')),
              TextButton(onPressed: () async { await _queue.discard(s.id); if (mounted) setState(() { _saved.removeAt(index); _view = null; }); }, child: const Text('Discard')),
            ]),
          ] else ...[
            Row(children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(item.sending ? 'Uploading…' : 'Waiting to upload'),
            ]),
            if (!item.sending) Padding(padding: const EdgeInsets.only(top: 8), child: OutlinedButton(onPressed: () => _edit(s, index), child: const Text('Edit'))),
          ],
        ]);
      },
    );
  }

  Widget _form() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(14), children: [
      if (_discovery && _nearby != null && _nearby!.violations.isNotEmpty)
        _DiscoveryBanner(address: _nearbyAddress, info: _nearby!, onTap: () => _showViolations(_nearbyAddress, _nearby!)),
      // 1 — community
      _StepCard(
        n: 1,
        title: 'Community',
        done: _community != null,
        child: InkWell(
          onTap: _communities.isEmpty ? null : _pickCommunity,
          child: InputDecorator(
            decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down_rounded)),
            child: Text(_community?.name ?? (!_loaded ? 'Loading…' : _communities.isEmpty ? 'No communities yet' : 'Choose community'), style: const TextStyle(fontSize: 16)),
          ),
        ),
      ),
      if (_community != null && _community!.units == 0)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('This community has no units yet, so findings are filed against the community by address only.', style: TextStyle(fontSize: 12)),
        ),
      // 2 — photo + address
      _StepCard(
        n: 2,
        title: 'Photo and address',
        done: _photo != null && _addressCtrl.text.trim().isNotEmpty,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_photo == null)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(96)),
              onPressed: _community == null ? null : _takePhoto,
              icon: const Icon(Icons.photo_camera_rounded, size: 30),
              label: Text(_community == null ? 'Choose a community first' : 'Take photo', style: const TextStyle(fontSize: 16)),
            )
          else ...[
            ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_photo!, height: 220, fit: BoxFit.cover)),
            const SizedBox(height: 6),
            Row(children: [TextButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.replay_rounded, size: 18), label: const Text('Retake'))]),
            TextField(
              controller: _addressCtrl,
              onChanged: (_) {
                setState(() {});
                _lookupDebounce?.cancel();
                _lookupDebounce = Timer(const Duration(milliseconds: 900), _lookupEntered);
              },
              decoration: InputDecoration(
                labelText: 'Address',
                helperText: _locating ? 'Finding the address…' : (_locateNote.isEmpty ? null : _locateNote),
                border: const OutlineInputBorder(),
                suffixIcon: _locating
                    ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(tooltip: 'Detect again from my location', icon: const Icon(Icons.my_location_rounded), onPressed: _locate),
              ),
            ),
            if (_atAddress != null && _atAddress!.violations.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 10), child: _DiscoveryBanner(address: _addressCtrl.text.trim().split(',').first, info: _atAddress!, onTap: () => _showViolations(_addressCtrl.text.trim(), _atAddress!))),
            if (_atAddress != null && _atAddress!.matched && _atAddress!.violations.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('Unit ${_atAddress!.unit}: no violations on file.', style: const TextStyle(fontSize: 12))),
          ],
        ]),
      ),
      // 3 — type
      _StepCard(
        n: 3,
        title: 'Violation',
        done: _type != null,
        child: Column(children: [
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Type'),
            items: [for (final t in _types) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 10),
          TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Notes (optional)')),
        ]),
      ),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
        onPressed: _ready ? _next : null,
        icon: const Icon(Icons.arrow_forward_rounded),
        label: const Text('Save and next finding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 8),
      ListenableBuilder(
        listenable: _queue,
        builder: (context, _) {
          final w = _queue.waiting;
          final f = _queue.failed;
          if (w == 0 && f == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              [if (w > 0) '$w uploading in the background', if (f > 0) '$f failed — open it with the back arrow'].join(' · '),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: f > 0 ? Colors.red : scheme.onSurfaceVariant),
            ),
          );
        },
      ),
    ]);
  }
}

class _StepCard extends StatelessWidget {
  final int n;
  final String title;
  final bool done;
  final Widget child;
  const _StepCard({required this.n, required this.title, required this.done, required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            CircleAvatar(radius: 12, backgroundColor: done ? Colors.green : scheme.surfaceContainerHighest, child: done ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : Text('$n', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class _CommunitySheet extends StatefulWidget {
  final List<HoaCommunity> communities;
  const _CommunitySheet({required this.communities});

  @override
  State<_CommunitySheet> createState() => _CommunitySheetState();
}

class _CommunitySheetState extends State<_CommunitySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final shown = widget.communities.where((c) => c.name.toLowerCase().contains(_q.toLowerCase())).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(padding: const EdgeInsets.all(12), child: TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search communities', border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v))),
          Expanded(
            child: ListView(children: [
              for (final c in shown) ListTile(title: Text(c.name), subtitle: Text(c.units == 0 ? 'No units yet' : '${c.units} units'), onTap: () => Navigator.pop(context, c)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// "9318 Ansley Park Pl — 2 open violations" strip. Tap to review them.
class _DiscoveryBanner extends StatelessWidget {
  final String address;
  final HoaAddressInfo info;
  final VoidCallback onTap;
  const _DiscoveryBanner({required this.address, required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final open = info.openCount;
    final color = open > 0 ? Colors.red : Colors.blueGrey;
    final unit = info.matched && info.unit.isNotEmpty ? 'Unit ${info.unit} · ' : '';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Row(children: [
          Icon(open > 0 ? Icons.warning_amber_rounded : Icons.history_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$unit$address', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(open > 0 ? '$open open violation${open == 1 ? '' : 's'}${info.violations.length > open ? ' · ${info.violations.length - open} past' : ''}' : '${info.violations.length} past violation${info.violations.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: color)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _ViolationsSheet extends StatelessWidget {
  final String address;
  final HoaAddressInfo info;
  const _ViolationsSheet({required this.address, required this.info});

  String _date(String d) {
    final t = DateTime.tryParse(d.length >= 10 ? d.substring(0, 10) : d);
    if (t == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[t.month - 1]} ${t.day}, ${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
          Text(address, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (info.matched) Padding(padding: const EdgeInsets.only(top: 2), child: Text('Unit ${info.unit}${info.owners.isEmpty ? '' : ' · ${info.owners.join(', ')}'}', style: TextStyle(color: scheme.onSurfaceVariant))),
          const SizedBox(height: 12),
          for (final v in info.violations)
            Card(
              child: ListTile(
                leading: Icon(v.open ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, color: v.open ? Colors.red : Colors.green),
                title: Text(v.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text([v.number, _date(v.createdAt), if (v.ownersAtTime.isNotEmpty) 'Owner(s) then: ${v.ownersAtTime}'].where((e) => e.isNotEmpty).join(' · ')),
                trailing: Text(v.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: v.open ? Colors.red : Colors.green)),
              ),
            ),
        ]),
      ),
    );
  }
}
