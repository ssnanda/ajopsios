import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/models/connected_site_model.dart';
import '../../../core/api/ops_api.dart';
import '../providers/lead_detail_provider.dart';

/// Parity with AJOps web's Edit Lead form (LeadEditForm in LeadsClient.tsx) —
/// same field set, including the Site picker (site drives which pipeline a
/// lead walks, see leadPipelineStages on lead_model.dart).
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
    super.dispose();
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
    final busy = ref.watch(leadDetailProvider(widget.lead)).busy;
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
              labelText: 'Notes',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : _save,
            child: Text(busy ? 'Saving…' : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}
