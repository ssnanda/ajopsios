import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/ops_service_request_model.dart';
import '../../../core/models/service_request_history_model.dart';
import '../../../core/models/staff_model.dart';
import '../../../core/widgets/loading_indicator.dart';

Future<void> showHistorySheet(
  BuildContext context, {
  required OpsServiceRequest request,
  required List<StaffModel> staff,
  required Future<String?> Function(int userId) onAssign,
  required Future<String?> Function(String note) onAddNote,
  required Future<String?> Function() onCancel,
  required Future<String?> Function() onDelete,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _HistorySheetContent(
      request: request,
      staff: staff,
      onAssign: onAssign,
      onAddNote: onAddNote,
      onCancel: onCancel,
      onDelete: onDelete,
    ),
  );
}

class _HistorySheetContent extends StatefulWidget {
  final OpsServiceRequest request;
  final List<StaffModel> staff;
  final Future<String?> Function(int userId) onAssign;
  final Future<String?> Function(String note) onAddNote;
  final Future<String?> Function() onCancel;
  final Future<String?> Function() onDelete;

  const _HistorySheetContent({
    required this.request,
    required this.staff,
    required this.onAssign,
    required this.onAddNote,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  State<_HistorySheetContent> createState() => _HistorySheetContentState();
}

class _HistorySheetContentState extends State<_HistorySheetContent> {
  late Future<List<ServiceRequestHistoryEntry>> _future;
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = OpsApi.instance.getServiceRequestHistory(widget.request.id);
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final canCancel =
        r.hasCancelOption &&
        !['cancelled', 'completed'].contains(r.serviceStatus);

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(r.serviceName, style: Theme.of(context).textTheme.titleMedium),
            Text(
              '${r.customerName.isNotEmpty ? r.customerName : r.stripeCustomerId} · ${r.customerEmail}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue:
                  r.assignedUserId == 0 ||
                      widget.staff.any((s) => s.id == r.assignedUserId)
                  ? r.assignedUserId
                  : 0,
              decoration: const InputDecoration(labelText: 'Assignee'),
              items: [
                const DropdownMenuItem(value: 0, child: Text('Unassigned')),
                ...widget.staff.map(
                  (s) =>
                      DropdownMenuItem(value: s.id, child: Text(s.displayName)),
                ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                final err = await widget.onAssign(v);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Add History Note'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () async {
                            if (_noteCtrl.text.trim().isEmpty) return;
                            setState(() => _saving = true);
                            final err = await widget.onAddNote(
                              _noteCtrl.text.trim(),
                            );
                            if (!context.mounted) return;
                            setState(() {
                              _saving = false;
                              _future = OpsApi.instance
                                  .getServiceRequestHistory(r.id);
                            });
                            if (err == null) {
                              _noteCtrl.clear();
                            } else {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(err)));
                            }
                          },
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Note'),
                  ),
                ),
                if (canCancel) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Cancel "${r.serviceName}"?'),
                          content: const Text(
                            'This can be reopened later if needed.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Back'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Cancel Request'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        final err = await widget.onCancel();
                        if (context.mounted) {
                          if (err == null) {
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(err)));
                          }
                        }
                      }
                    },
                    child: const Text('Cancel Request'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            Text('History', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            FutureBuilder<List<ServiceRequestHistoryEntry>>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData)
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: AjLoadingIndicator(),
                  );
                final history = snap.data!;
                if (history.isEmpty) {
                  return const Text(
                    'No history yet.',
                    style: TextStyle(color: Colors.grey),
                  );
                }
                return Column(
                  children: history
                      .map(
                        (h) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                h.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (h.note.isNotEmpty) Text(h.note),
                              Text(
                                h.actorEmail.isNotEmpty
                                    ? '${h.createdAt} · ${h.actorEmail}'
                                    : h.createdAt,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.delete_outline_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete Service Request',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Permanently remove this request'),
              onTap: _saving
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete service request?'),
                          content: Text(
                            'Permanently delete ${r.requestNumber.isNotEmpty ? r.requestNumber : r.serviceName}? This cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Back'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      setState(() => _saving = true);
                      final err = await widget.onDelete();
                      if (!context.mounted) return;
                      if (err == null) {
                        Navigator.pop(context);
                      } else {
                        setState(() => _saving = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
