import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/status_badge.dart';
import '../providers/customer_detail_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String action, {
    String? confirmMessage,
    Map<String, String>? extra,
  }) async {
    if (confirmMessage != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Are you sure?'),
          content: Text(confirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    final err = await ref
        .read(customerDetailProvider(customer.stripeCustomerId).notifier)
        .runAction(action, extra: extra);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err ??
                (action == 'send_ra_authorization'
                    ? 'RA authorization sent.'
                    : 'Done.'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(customerDetailProvider(customer.stripeCustomerId));
    final notifier = ref.read(
      customerDetailProvider(customer.stripeCustomerId).notifier,
    );

    return Scaffold(
      appBar: AppBar(title: Text(customer.displayName)),
      body: state.loading
          ? const AjLoadingIndicator()
          : state.error != null
          ? ErrorState(message: state.error!, onRetry: notifier.load)
          : state.detail == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: notifier.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _InfoCard(detail: state.detail!),
                  const SizedBox(height: 12),
                  _ActionsCard(
                    detail: state.detail!,
                    busy: state.actionBusy,
                    onAction: (action, confirm) => _runAction(
                      context,
                      ref,
                      action,
                      confirmMessage: confirm,
                      // {company} in the authorization email is the filing entity, not the contact person.
                      extra: action == 'send_ra_authorization'
                          ? {
                              'company': state.detail!.businessName.isNotEmpty
                                  ? state.detail!.businessName
                                  : customer.displayName,
                            }
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _SubscriptionsSection(
                    subscriptions: state.detail!.subscriptions,
                  ),
                  const SizedBox(height: 20),
                  _ServiceRequestsSection(
                    requests: state.detail!.serviceRequests,
                  ),
                ],
              ),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final CustomerDetail detail;
  const _InfoCard({required this.detail});

  @override
  Widget build(BuildContext context) {
    final c = detail.customer;
    return Card(
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
            if (detail.businessName.isNotEmpty)
              _Row(icon: Icons.business_rounded, text: detail.businessName),
            if (detail.individualName.isNotEmpty)
              _Row(
                icon: Icons.person_outline_rounded,
                text: detail.individualName,
              ),
            if (c.email.isNotEmpty)
              _Row(icon: Icons.email_outlined, text: c.email),
            if (c.phone.isNotEmpty)
              _Row(icon: Icons.phone_outlined, text: c.phone),
            if (c.address.isNotEmpty)
              _Row(icon: Icons.location_on_outlined, text: c.address),
            if (c.customerNumber.isNotEmpty)
              _Row(
                icon: Icons.tag_rounded,
                text: 'Customer #${c.customerNumber}',
              ),
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  final CustomerDetail detail;
  final bool busy;
  final void Function(String action, String? confirm) onAction;
  const _ActionsCard({
    required this.detail,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final status = detail.customer.portalStatus;
    final scheme = Theme.of(context).colorScheme;
    final statusLabel = status.isEmpty
        ? 'Unknown'
        : status.replaceAll('_', ' ');
    return Card(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Customer portal',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                StatusBadge.fromStatus(statusLabel),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Manage access and customer emails.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (status != 'active' && status != 'archived')
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : () => onAction('enable', null),
                      icon: const Icon(Icons.lock_open_rounded, size: 18),
                      label: const Text('Enable portal'),
                    ),
                  ),
                if (status == 'active')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy
                          ? null
                          : () => onAction(
                              'disable',
                              'Disable this customer’s portal access?',
                            ),
                      icon: const Icon(Icons.lock_outline_rounded, size: 18),
                      label: const Text('Disable portal'),
                    ),
                  ),
                if (status == 'archived')
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => onAction('restore', null),
                      icon: const Icon(Icons.restore_rounded, size: 18),
                      label: const Text('Restore'),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => onAction(
                            'reset_password',
                            'Send a password reset link to this customer?',
                          ),
                    icon: const Icon(Icons.password_rounded, size: 18),
                    label: const Text('Reset password'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => onAction(
                            'send_welcome',
                            'Resend the welcome email?',
                          ),
                    icon: const Icon(Icons.waving_hand_outlined, size: 18),
                    label: const Text('Welcome email'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => onAction(
                      'send_ra_authorization',
                      'Email the Registered Agent authorization to ${detail.customer.email}?',
                    ),
              icon: const Icon(Icons.verified_user_outlined, size: 18),
              label: const Text('Send RA authorization'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionsSection extends StatelessWidget {
  final List<CustomerSubscription> subscriptions;
  const _SubscriptionsSection({required this.subscriptions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Subscriptions',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        if (subscriptions.isEmpty)
          Text(
            'No subscriptions.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...subscriptions.map(
            (s) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(s.priceLabel),
                trailing: StatusBadge.fromStatus(s.status),
              ),
            ),
          ),
      ],
    );
  }
}

class _ServiceRequestsSection extends StatelessWidget {
  final List<CustomerServiceRequestSummary> requests;
  const _ServiceRequestsSection({required this.requests});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service requests',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Text('No requests.', style: TextStyle(color: Colors.grey.shade600))
        else
          ...requests.map(
            (r) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(
                  '${r.requestNumber.isNotEmpty ? r.requestNumber : '#${r.id}'} · ${r.serviceName.isEmpty ? 'Service Request' : r.serviceName}',
                ),
                subtitle: Text(
                  r.serviceStatus.replaceAll('_', ' '),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
