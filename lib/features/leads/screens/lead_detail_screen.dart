import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/widgets/customer_picker.dart';
import '../providers/lead_detail_provider.dart';

class LeadDetailScreen extends ConsumerStatefulWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    final err = await action();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _setStage(
    LeadDetailNotifier notifier,
    String stage,
  ) async {
    if (stage != 'customer') {
      await _run(() => notifier.setStage(stage));
      return;
    }

    final customer = await pickCustomer(context);
    if (customer == null || !mounted) return;
    await _run(
      () => notifier.setStage(
        'customer',
        stripeCustomerId: customer.stripeCustomerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadDetailProvider(widget.lead));
    final notifier = ref.read(leadDetailProvider(widget.lead).notifier);
    final lead = state.lead;

    return Scaffold(
      appBar: AppBar(title: Text(lead.displayName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(lead: lead),
          const SizedBox(height: 16),
          Text('PIPELINE STAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...leadPipelineStages.map((stage) => ChoiceChip(
                    label: Text(leadPipelineLabels[stage] ?? stage),
                    selected: lead.leadStatus == stage,
                    onSelected: state.busy
                        ? null
                        : (_) => _setStage(notifier, stage),
                  )),
              ChoiceChip(
                label: const Text('Lost'),
                selected: lead.leadStatus == 'lost',
                selectedColor: Colors.red.shade100,
                onSelected: state.busy ? null : (_) => _run(() => notifier.setStage('lost')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('NOTES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          if (lead.notesList.isEmpty)
            Text('No notes yet.', style: TextStyle(color: Colors.grey.shade600))
          else
            ...lead.notesList.map((n) => Card(
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
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(hintText: 'Add a note...', isDense: true, border: OutlineInputBorder()),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.busy
                    ? null
                    : () async {
                        final text = _noteCtrl.text.trim();
                        if (text.isEmpty) return;
                        _noteCtrl.clear();
                        await _run(() => notifier.addNote(text));
                      },
                child: const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Lead lead;
  const _InfoCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lead.company.isNotEmpty) _Row(icon: Icons.business_rounded, text: lead.company),
            if (lead.email.isNotEmpty) _Row(icon: Icons.email_outlined, text: lead.email),
            if (lead.phone.isNotEmpty) _Row(icon: Icons.phone_outlined, text: lead.phone),
            if (lead.source.isNotEmpty) _Row(icon: Icons.source_outlined, text: lead.source),
            if (lead.formTitle.isNotEmpty) _Row(icon: Icons.description_outlined, text: lead.formTitle),
            if (lead.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(lead.notes, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
