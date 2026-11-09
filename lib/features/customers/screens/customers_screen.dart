import '../../../core/widgets/site_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/customers_provider.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customersProvider);
    final notifier = ref.read(customersProvider.notifier);
    final visible = state.visible;

    return Scaffold(
      appBar: AppBar(
        title: const AjAppBarTitle('Customers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search name, email, customer #...',
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
          // Same two filter rows as AJOps (Partner, Service), kept small: one scrolling line each.
          if (state.showPartners)
            _FilterRow(
              label: 'Partner',
              chips: [
                for (final t in [(key: '', name: 'All'), ...state.partners])
                  _MiniChip(
                    label: '${t.name} ${state.partnerCount(t.key)}',
                    selected: state.partnerFilter == t.key,
                    dim: state.partnerCount(t.key) == 0 && state.partnerFilter != t.key,
                    onTap: () => notifier.setPartnerFilter(t.key),
                  ),
              ],
            ),
          _FilterRow(
            label: 'Service',
            chips: [
              for (final f in serviceFilters)
                if (state.showSubscriptionTypes || !const {'ra', 'vo', 'none'}.contains(f.$1))
                  _MiniChip(
                    label: '${f.$2} ${state.serviceCount(f.$1)}',
                    selected: state.serviceFilter == f.$1,
                    dim: state.serviceCount(f.$1) == 0 && state.serviceFilter != f.$1,
                    onTap: () => notifier.setServiceFilter(f.$1),
                  ),
            ],
          ),
          if (state.filtered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Row(children: [
                Text('Showing ${visible.length}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: notifier.clearFilters,
                  child: Text('Clear all', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.primary)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : visible.isEmpty
                        ? const EmptyState(icon: Icons.people_outline_rounded, title: 'No customers', subtitle: 'Nothing matches the current search.')
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: visible.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                final c = visible[i];
                                return _CustomerCard(
                                  customer: c,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
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

class _FilterRow extends StatelessWidget {
  final String label;
  final List<Widget> chips;
  const _FilterRow({required this.label, required this.chips});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1, color: Colors.grey.shade500)),
            ),
          ),
          ...chips,
        ],
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dim;
  final VoidCallback onTap;
  const _MiniChip({required this.label, required this.selected, required this.onTap, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dim ? Colors.grey.shade400 : null)),
        selected: selected,
        showCheckmark: false,
        onSelected: dim ? null : (_) => onTap(),
        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 2),
      ),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;
  const _CustomerCard({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
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
                    Text(customer.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (customer.email.isNotEmpty)
                      Text(customer.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _StatusBadge(status: customer.portalStatus),
                        for (final service in customer.serviceTypes) _ServiceBadge(label: service),
                      ],
                    ),
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

class _ServiceBadge extends StatelessWidget {
  final String label;
  const _ServiceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'active' => Colors.green,
      'disabled' => Colors.orange,
      'archived' => Colors.grey,
      _ => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.isEmpty ? 'unknown' : status.replaceAll('_', ' '),
        style: TextStyle(color: color.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }
}
