import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/connected_site_model.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/utils/error_utils.dart';
import '../providers/leads_provider.dart';

const _sourceOptions = {
  'manual': 'Manual entry',
  'phone': 'Phone call',
  'email': 'Email',
  'referral': 'Referral',
  'walk_in': 'Walk-in',
  'other': 'Other',
};

/// Parity with AJOps web's New Lead form (AddLeadModal in LeadsClient.tsx).
class LeadAddScreen extends ConsumerStatefulWidget {
  const LeadAddScreen({super.key});

  @override
  ConsumerState<LeadAddScreen> createState() => _LeadAddScreenState();
}

class _LeadAddScreenState extends ConsumerState<LeadAddScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _source = 'manual';
  String _siteUuid = '';
  bool _saving = false;
  String? _error;

  List<ConnectedSite>? _sites;

  @override
  void initState() {
    super.initState();
    OpsApi.instance
        .getConnectedSites()
        .then((sites) {
          if (mounted) setState(() => _sites = sites);
        })
        .catchError((_) {
          if (mounted) setState(() => _sites = const []);
        });
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
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final lead = await OpsApi.instance.createLead(
        name: name,
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        source: _source,
        notes: _notesCtrl.text.trim(),
        siteUuid: _siteUuid,
      );
      if (!mounted) return;
      ref.read(leadsProvider.notifier).addLead(lead);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final siteOptions = <String, String>{
      for (final s in _sites ?? const <ConnectedSite>[]) s.siteUuid: s.label,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('New Lead')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name *'),
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
            initialValue: _source,
            decoration: const InputDecoration(labelText: 'Source'),
            items: [
              for (final entry in _sourceOptions.entries)
                DropdownMenuItem(value: entry.key, child: Text(entry.value)),
            ],
            onChanged: (v) => setState(() => _source = v ?? 'manual'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: siteOptions.containsKey(_siteUuid) ? _siteUuid : null,
            decoration: const InputDecoration(labelText: 'Site'),
            hint: const Text('— Default site —'),
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
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Create Lead'),
          ),
        ],
      ),
    );
  }
}
