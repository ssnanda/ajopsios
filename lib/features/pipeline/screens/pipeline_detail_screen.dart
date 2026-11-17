import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/pipeline_item_model.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';

class PipelineDetailScreen extends StatefulWidget {
  final PipelineItem item;
  const PipelineDetailScreen({super.key, required this.item});

  @override
  State<PipelineDetailScreen> createState() => _PipelineDetailScreenState();
}

class _PipelineDetailScreenState extends State<PipelineDetailScreen> {
  final _api = OpsApi.instance;
  final _customerIdCtrl = TextEditingController();
  PipelinePreview? _preview;
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preview = await _api.getPipelinePreview(widget.item.id);
      setState(() {
        _preview = preview;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _file({required bool notify}) async {
    final customerId = _customerIdCtrl.text.trim();
    if (customerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a customer ID first.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await _api.filePipelineItem(
        widget.item.id,
        stripeCustomerId: customerId,
        notify: notify,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Filed.')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  /// Same as "Mark as Already Filed" on the web: clears the entry from Pending without uploading or attaching anything.
  Future<void> _markAlreadyFiled() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as already filed?'),
        content: const Text(
          'This just clears it from Pending. It does not upload or attach anything.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Mark as filed'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _api.markPipelineItemFiled(widget.item.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review document')),
      body: _loading
          ? const AjLoadingIndicator()
          : _error != null
          ? ErrorState(message: _error!, onRetry: _load)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.subject.isEmpty
                              ? 'No subject'
                              : widget.item.subject,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _preview?.sender ?? widget.item.sender,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if ((_preview?.date ?? '').isNotEmpty)
                          Text(
                            _preview!.date,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        const SizedBox(height: 10),
                        Text(_preview?.body ?? widget.item.snippet),
                      ],
                    ),
                  ),
                ),
                if ((_preview?.attachments.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 16),
                  Text(
                    'ATTACHMENTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._preview!.attachments.map(
                    (a) => ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.attach_file_rounded),
                      title: Text(a.filename),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'File for customer',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  'Attach this document to the matching customer account.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _customerIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Customer ID',
                    hintText: 'cus_…',
                    prefixIcon: Icon(Icons.person_search_outlined),
                    helperText: 'Stripe customer ID',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _file(notify: false),
                  icon: const Icon(Icons.drive_file_move_outline),
                  label: const Text('File document'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _file(notify: true),
                  icon: const Icon(Icons.outgoing_mail),
                  label: const Text('File and notify customer'),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _markAlreadyFiled,
                    icon: const Icon(Icons.task_alt_rounded, size: 18),
                    label: const Text('Already filed elsewhere'),
                  ),
                ),
              ],
            ),
    );
  }
}
