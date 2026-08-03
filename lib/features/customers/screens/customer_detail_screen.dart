import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/customer_detail_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    String action, {
    String? confirmMessage,
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
        .runAction(action);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
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
                  const SizedBox(height: 16),
                  _ActionsCard(
                    detail: state.detail!,
                    busy: state.actionBusy,
                    onAction: (action, confirm) => _runAction(
                      context,
                      ref,
                      action,
                      confirmMessage: confirm,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SubscriptionsSection(
                    subscriptions: state.detail!.subscriptions,
                  ),
                  const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(14),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PORTAL STATUS: ${status.isEmpty ? "unknown" : status.replaceAll('_', ' ')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'active')
                  OutlinedButton(
                    onPressed: busy ? null : () => onAction('enable', null),
                    child: const Text('Enable'),
                  ),
                if (status == 'active')
                  OutlinedButton(
                    onPressed: busy ? null : () => onAction('disable', null),
                    child: const Text('Disable'),
                  ),
                if (status != 'archived')
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () => onAction('archive', 'Archive this customer?'),
                    child: const Text('Archive'),
                  ),
                if (status == 'archived')
                  OutlinedButton(
                    onPressed: busy ? null : () => onAction('restore', null),
                    child: const Text('Restore'),
                  ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => onAction(
                          'reset_password',
                          'Send a password reset link to this customer?',
                        ),
                  child: const Text('Reset password'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => onAction(
                          'send_welcome',
                          'Resend the welcome email?',
                        ),
                  child: const Text('Send welcome'),
                ),
              ],
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
          'SUBSCRIPTIONS',
          style: TextStyle(
            fontSize: 11,
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
              color: Colors.grey.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(s.priceLabel),
                trailing: Text(
                  s.status,
                  style: TextStyle(
                    color: s.status == 'active'
                        ? Colors.green
                        : Colors.grey.shade600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          'SERVICE REQUESTS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 8),
        if (requests.isEmpty)
          Text(
            'No service requests.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          ...requests.map(
            (r) => Card(
              elevation: 0,
              color: Colors.grey.shade50,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                dense: true,
                title: Text(
                  '${r.requestNumber.isNotEmpty ? r.requestNumber : '#${r.id}'} · ${r.serviceName.isEmpty ? 'Service Request' : r.serviceName}',
                ),
                subtitle: Text(r.serviceStatus.replaceAll('_', ' ')),
              ),
            ),
          ),
      ],
    );
  }
}
