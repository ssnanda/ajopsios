import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/hoa_models.dart';

/// Community inspection: pick the community once, then for each problem: photo -> address (auto, editable)
/// -> violation type -> submit. The community stays selected so the next house is one tap away.
class InspectionScreen extends StatefulWidget {
  const InspectionScreen({super.key});

  @override
  State<InspectionScreen> createState() => _InspectionScreenState();
}

class _InspectionScreenState extends State<InspectionScreen> {
  static const _prefKey = 'inspect_last_community';

  List<HoaCommunity> _communities = const [];
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
  bool _submitting = false;
  int _done = 0;
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([OpsApi.instance.getHoaCommunities(), OpsApi.instance.getHoaViolationTypes()]);
      final communities = (results[0] as List<HoaCommunity>).where((c) => c.units > 0).toList();
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getString(_prefKey);
      if (!mounted) return;
      setState(() {
        _communities = communities;
        _types = results[1] as List<String>;
        _community = communities.where((c) => c.id == last).firstOrNull ?? (communities.length == 1 ? communities.first : null);
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
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
        final line = [street, m.locality ?? '', region].where((s) => s.isNotEmpty).join(', ');
        _addressCtrl.text = line;
      }
      _locateNote = '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)} · ±${pos.accuracy.round()} m';
    } catch (e) {
      _locateNote = 'Could not detect the address ($e). Type it in.';
    }
    if (mounted) setState(() => _locating = false);
  }

  bool get _ready => _community != null && _photo != null && _addressCtrl.text.trim().isNotEmpty && _type != null && !_submitting;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final r = await OpsApi.instance.submitInspection(
        communityId: _community!.id,
        address: _addressCtrl.text.trim(),
        violationType: _type!,
        notes: _notesCtrl.text.trim(),
        lat: _lat,
        lng: _lng,
        photoPath: _photo?.path,
      );
      if (!mounted) return;
      final where = r.unit.isNotEmpty ? 'Unit ${r.unit}' : _addressCtrl.text.trim().split(',').first;
      setState(() {
        _done++;
        _log.insert(0, '$where — $_type');
        _photo = null;
        _lat = null;
        _lng = null;
        _type = null;
        _addressCtrl.clear();
        _notesCtrl.clear();
        _locateNote = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.unit.isNotEmpty ? 'Violation filed for Unit ${r.unit}.' : 'Violation filed (no unit matched that address).')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection'), actions: [if (_done > 0) Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: Text('$_done filed', style: const TextStyle(fontWeight: FontWeight.w600))))]),
      body: _loadError != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_loadError!)))
          : ListView(padding: const EdgeInsets.all(14), children: [
              // 1 — community
              _StepCard(
                n: 1,
                title: 'Community',
                done: _community != null,
                child: InkWell(
                  onTap: _communities.isEmpty ? null : _pickCommunity,
                  child: InputDecorator(
                    decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down_rounded)),
                    child: Text(_community?.name ?? (_communities.isEmpty ? 'Loading…' : 'Choose community'), style: const TextStyle(fontSize: 16)),
                  ),
                ),
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
                    Row(children: [
                      TextButton.icon(onPressed: _takePhoto, icon: const Icon(Icons.replay_rounded, size: 18), label: const Text('Retake')),
                    ]),
                    TextField(
                      controller: _addressCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Address',
                        helperText: _locating ? 'Finding the address…' : (_locateNote.isEmpty ? null : _locateNote),
                        border: const OutlineInputBorder(),
                        suffixIcon: _locating
                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                            : IconButton(tooltip: 'Detect again from my location', icon: const Icon(Icons.my_location_rounded), onPressed: _locate),
                      ),
                    ),
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
                onPressed: _ready ? _submit : null,
                icon: _submitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                label: const Text('Submit finding', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              if (_log.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('THIS INSPECTION', style: TextStyle(fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                for (final line in _log) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [const Icon(Icons.check_circle_rounded, size: 16, color: Colors.green), const SizedBox(width: 8), Expanded(child: Text(line))])),
              ],
            ]),
    );
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
          Padding(padding: const EdgeInsets.all(12), child: TextField(autofocus: false, decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search communities', border: OutlineInputBorder()), onChanged: (v) => setState(() => _q = v))),
          Expanded(
            child: ListView(children: [
              for (final c in shown) ListTile(title: Text(c.name), subtitle: Text('${c.units} units'), onTap: () => Navigator.pop(context, c)),
            ]),
          ),
        ]),
      ),
    );
  }
}
