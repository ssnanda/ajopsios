import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/gmail_intake_item_model.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';

class GmailIntakeDetailScreen extends StatefulWidget {
  final GmailIntakeItem item;
  const GmailIntakeDetailScreen({super.key, required this.item});

  @override
  State<GmailIntakeDetailScreen> createState() => _GmailIntakeDetailScreenState();
}

class _GmailIntakeDetailScreenState extends State<GmailIntakeDetailScreen> {
  final _api = OpsApi.instance;
  final _customerIdCtrl = TextEditingController();
  GmailIntakePreview? _preview;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
    _customerIdCtrl.text = widget.item.stripeCustomerId;
  }

  @override
  void dispose() {
    _customerIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final preview = await _api.getGmailIntakePreview(widget.item.id);
      setState(() { _preview = preview; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _file({required bool notify}) async {
    final customerId = _customerIdCtrl.text.trim();
    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a customer ID first.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.fileGmailIntakeItem(widget.item.id, stripeCustomerId: customerId, notify: notify);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Filed.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _resolveWithoutFiling() async {
    setState(() => _busy = true);
    try {
      await _api.resolveGmailIntakeItem(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item.subject.isEmpty ? '(no subject)' : widget.item.subject)),
      body: _loading
          ? const AjLoadingIndicator()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_preview?.sender ?? widget.item.sender, style: const TextStyle(fontWeight: FontWeight.w700)),
                            if ((_preview?.date ?? '').isNotEmpty)
                              Text(_preview!.date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(height: 10),
                            Text(_preview?.body ?? widget.item.snippet),
                          ],
                        ),
                      ),
                    ),
                    if ((_preview?.attachments.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 16),
                      Text('ATTACHMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      ..._preview!.attachments.map((a) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.attach_file_rounded),
                            title: Text(a.filename),
                          )),
                    ],
                    const SizedBox(height: 20),
                    Text('FILE TO CUSTOMER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customerIdCtrl,
                      decoration: const InputDecoration(labelText: 'Stripe customer ID', isDense: true, border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy ? null : () => _file(notify: false),
                            child: const Text('File'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => _file(notify: true),
                            child: const Text('File + notify'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : _resolveWithoutFiling,
                      child: const Text('Mark resolved without filing'),
                    ),
                  ],
                ),
    );
  }
}
