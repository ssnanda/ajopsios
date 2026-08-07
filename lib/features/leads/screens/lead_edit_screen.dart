import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/connected_site_model.dart';
import '../../../core/api/ops_api.dart';
import '../providers/lead_detail_provider.dart';

/// Parity with AJOps web's Edit Lead form (LeadEditForm in LeadsClient.tsx) —
/// same field set, including the Site picker (site drives which pipeline a
/// lead walks, see leadPipelineStages on lead_model.dart). Also carries the
/// Notes thread (list + add box) alongside the form, same as web keeps
/// NotesList mounted regardless of edit/view state — so staff don't have to
/// leave the edit screen just to log a note.
class LeadEditScreen extends ConsumerStatefulWidget {
  final Lead lead;
  const LeadEditScreen({super.key, required this.lead});

  @override
  ConsumerState<LeadEditScreen> createState() => _LeadEditScreenState();
}

const _sourceOptions = {
  'manual': 'Manual entry',
  'phone': 'Phone call',
  'email': 'Email',
  'referral': 'Referral',
  'walk_in': 'Walk-in',
  'other': 'Other',
};

class _LeadEditScreenState extends ConsumerState<LeadEditScreen> {
  late final _nameCtrl = TextEditingController(text: widget.lead.name);
  late final _emailCtrl = TextEditingController(text: widget.lead.email);
  late final _phoneCtrl = TextEditingController(text: widget.lead.phone);
  late final _companyCtrl = TextEditingController(text: widget.lead.company);
  late final _notesCtrl = TextEditingController(text: widget.lead.notes);
  late String _source = widget.lead.source;
  late String _siteUuid = widget.lead.siteUuid;

  final _newNoteCtrl = TextEditingController();

  List<ConnectedSite>? _sites;
  String? _sitesError;

  @override
  void initState() {
    super.initState();
    _loadSites();
  }

  Future<void> _loadSites() async {
    try {
      final sites = await OpsApi.instance.getConnectedSites();
      if (!mounted) return;
      setState(() => _sites = sites);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sitesError = e.toString());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _companyCtrl.dispose();
    _notesCtrl.dispose();
    _newNoteCtrl.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    final text = _newNoteCtrl.text.trim();
    if (text.isEmpty) return;
    final notifier = ref.read(leadDetailProvider(widget.lead).notifier);
    _newNoteCtrl.clear();
    final err = await notifier.addNote(text);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _save() async {
    final notifier = ref.read(leadDetailProvider(widget.lead).notifier);
    final err = await notifier.updateLead(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      company: _companyCtrl.text.trim(),
      source: _source,
      notes: _notesCtrl.text.trim(),
      siteUuid: _siteUuid,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadDetailProvider(widget.lead));
    final busy = state.busy;
    // Site options come from the live connected-sites registry, but always keep the lead's
    // current site selectable even if it's since dropped out of that list.
    final siteOptions = <String, String>{
      for (final s in _sites ?? const <ConnectedSite>[]) s.siteUuid: s.label,
    };
    if (_siteUuid.isNotEmpty && !siteOptions.containsKey(_siteUuid)) {
      siteOptions[_siteUuid] = widget.lead.siteLabel.isNotEmpty
          ? widget.lead.siteLabel
          : _siteUuid;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Lead')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _companyCtrl,
            decoration: const InputDecoration(labelText: 'Company'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _sourceOptions.containsKey(_source) ? _source : null,
            decoration: const InputDecoration(labelText: 'Source'),
            items: [
              for (final entry in _sourceOptions.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => setState(() => _source = v ?? ''),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: siteOptions.containsKey(_siteUuid) ? _siteUuid : null,
            decoration: InputDecoration(
              labelText: 'Site',
              helperText: _sitesError != null ? 'Failed to load sites' : null,
            ),
            items: [
              for (final entry in siteOptions.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: _sites == null
                ? null
                : (v) => setState(() => _siteUuid = v ?? ''),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
              // "Message" — what the lead is looking for, distinct from the
              // staff Notes thread below (was mislabeled "Notes" too, which
              // read as a duplicate of that section).
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Saving…' : 'Save Changes'),
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'NOTES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          if (state.lead.notesList.isEmpty)
            Text('No notes yet.', style: TextStyle(color: Colors.grey.shade600))
          else
            ...state.lead.notesList.map(
              (n) => Card(
                elevation: 0,
                color: Colors.grey.shade50,
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.note),
                      const SizedBox(height: 4),
                      Text(
                        '${n.authorName.isNotEmpty ? n.authorName : "Staff"} · ${n.createdAt}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _newNoteCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Add a note...',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : _addNote,
                child: const Text('Add Note'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
