import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/mail_item_model.dart';
import '../../../core/widgets/customer_picker.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/mail_provider.dart';

class MailScreen extends ConsumerWidget {
  const MailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mailProvider);
    final notifier = ref.read(mailProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Mail')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMailSheet(context, notifier),
        child: const Icon(Icons.add_rounded),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _StatusChip(label: 'All', value: '', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Received', value: 'received', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Scanned', value: 'scanned', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Notified', value: 'notified', current: state.status, onSelect: notifier.setStatus),
                _StatusChip(label: 'Closed', value: 'closed', current: state.status, onSelect: notifier.setStatus),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : state.items.isEmpty
                        ? const EmptyState(icon: Icons.mail_outline_rounded, title: 'No mail', subtitle: 'Tap + to log a new piece of mail.')
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                              itemCount: state.items.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _MailCard(item: state.items[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  void _showAddMailSheet(BuildContext context, MailNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddMailSheet(notifier: notifier),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onSelect;
  const _StatusChip({required this.label, required this.value, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: value == current, onSelected: (_) => onSelect(value)),
    );
  }
}

class _MailCard extends StatelessWidget {
  final MailItem item;
  const _MailCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (item.scanUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(item.scanUrl, width: 48, height: 48, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(width: 48, height: 48, color: Colors.grey.shade200, child: const Icon(Icons.description_outlined))),
              )
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: Icon(_iconFor(item.mailType), color: Colors.grey.shade600),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.recipientName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (item.senderName.isNotEmpty)
                    Text('From ${item.senderName}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _Badge(text: item.mailType),
                      const SizedBox(width: 6),
                      _Badge(text: item.status, color: item.status == 'closed' ? Colors.grey : Colors.blue),
                      if (item.isSop) ...[
                        const SizedBox(width: 6),
                        _Badge(text: 'SOP', color: Colors.red),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'package' => Icons.inventory_2_outlined,
        'legal' => Icons.gavel_rounded,
        'government' => Icons.account_balance_outlined,
        'check' => Icons.attach_money_rounded,
        _ => Icons.mail_outline_rounded,
      };
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  const _Badge({required this.text, this.color = Colors.blueGrey});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11)),
    );
  }
}

class _AddMailSheet extends StatefulWidget {
  final MailNotifier notifier;
  const _AddMailSheet({required this.notifier});

  @override
  State<_AddMailSheet> createState() => _AddMailSheetState();
}

class _AddMailSheetState extends State<_AddMailSheet> {
  final _recipientCtrl = TextEditingController();
  final _senderCtrl = TextEditingController();
  final _trackingCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _mailType = 'letter';
  XFile? _scan;
  Customer? _customer;
  bool _submitting = false;

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _senderCtrl.dispose();
    _trackingCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickScan(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked != null) setState(() => _scan = picked);
  }

  Future<void> _submit() async {
    if (_recipientCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final err = await widget.notifier.createMailItem(
      recipientName: _recipientCtrl.text.trim(),
      mailType: _mailType,
      senderName: _senderCtrl.text.trim(),
      trackingNumber: _trackingCtrl.text.trim(),
      description: _descriptionCtrl.text.trim(),
      scanFilePath: _scan?.path,
      stripeCustomerId: _customer?.stripeCustomerId,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Log new mail', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(controller: _recipientCtrl, decoration: const InputDecoration(labelText: 'Recipient name *')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: _mailType,
              decoration: const InputDecoration(labelText: 'Mail type'),
              items: mailTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (v) => setState(() => _mailType = v ?? 'letter'),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: () async {
                final picked = await pickCustomer(context);
                if (picked?.customer != null) setState(() => _customer = picked!.customer);
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Customer (optional)',
                  suffixIcon: _customer == null
                      ? const Icon(Icons.search_rounded)
                      : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(() => _customer = null)),
                ),
                child: Text(_customer?.displayName ?? 'Not linked to a customer'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(controller: _senderCtrl, decoration: const InputDecoration(labelText: 'Sender')),
            const SizedBox(height: 10),
            TextField(controller: _trackingCtrl, decoration: const InputDecoration(labelText: 'Tracking number')),
            const SizedBox(height: 10),
            TextField(controller: _descriptionCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 2),
            const SizedBox(height: 14),
            if (_scan != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    const Text('Scan attached'),
                    const Spacer(),
                    TextButton(onPressed: () => setState(() => _scan = null), child: const Text('Remove')),
                  ],
                ),
              ),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickScan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Text('Scan photo'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _pickScan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose photo'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
