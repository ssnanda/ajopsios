import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/lead_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/leads_provider.dart';
import 'lead_detail_screen.dart';

class LeadsScreen extends ConsumerStatefulWidget {
  const LeadsScreen({super.key});

  @override
  ConsumerState<LeadsScreen> createState() => _LeadsScreenState();
}

class _LeadsScreenState extends ConsumerState<LeadsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(leadsProvider);
    final notifier = ref.read(leadsProvider.notifier);
    final filtered = state.filtered;

    return Scaffold(
      appBar: AppBar(title: const Text('Leads')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, email, company...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          notifier.setSearch('');
                        },
                      ),
              ),
              onSubmitted: notifier.setSearch,
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _ViewChip(label: 'Active', view: LeadsView.active, current: state.view, onSelect: notifier.setView),
                _ViewChip(label: 'Customer', view: LeadsView.customer, current: state.view, onSelect: notifier.setView),
                _ViewChip(label: 'Lost', view: LeadsView.lost, current: state.view, onSelect: notifier.setView),
                _ViewChip(label: 'All', view: LeadsView.all, current: state.view, onSelect: notifier.setView),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Hide Future Follow-up'),
                selected: state.hideFutureFollowUp,
                onSelected: notifier.setHideFutureFollowUp,
                tooltip: "Leads marked Future Follow-Up with a date that hasn't arrived yet are hidden until that date.",
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : filtered.isEmpty
                        ? const EmptyState(
                            icon: Icons.person_search_outlined,
                            title: 'No leads',
                            subtitle: 'Nothing matches the current filters.',
                          )
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final lead = filtered[i];
                                return _LeadCard(
                                  lead: lead,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ViewChip extends StatelessWidget {
  final String label;
  final LeadsView view;
  final LeadsView current;
  final void Function(LeadsView) onSelect;

  const _ViewChip({required this.label, required this.view, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final selected = view == current;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onSelect(view)),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onTap;
  const _LeadCard({required this.lead, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final latestNote = lead.latestNote;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#${lead.id}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            lead.siteLabel.isNotEmpty ? lead.siteLabel : 'Source form',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(lead.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (lead.company.isNotEmpty)
                      Text(lead.company, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _StageBadge(status: lead.leadStatus),
                        if (lead.source.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(lead.source, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ],
                    ),
                    if (latestNote != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        latestNote.note,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String status;
  const _StageBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == 'customer' ? Colors.green : (status == 'lost' ? Colors.red : Colors.blue);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        leadPipelineLabels[status] ?? status,
        style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
