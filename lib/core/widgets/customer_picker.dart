import 'dart:async';
import 'package:flutter/material.dart';
import '../api/ops_api.dart';
import '../models/customer_model.dart';

/// Result of [pickCustomer]: either a real Stripe-linked customer, or (only
/// when `allowManualEntry: true`) a plain name for a customer of another
/// business — office space, residential, etc. — that never goes through
/// Stripe. Exactly one of [customer]/[manualName] is non-null.
class CustomerPickResult {
  final Customer? customer;
  final String? manualName;
  const CustomerPickResult.customer(Customer this.customer) : manualName = null;
  const CustomerPickResult.manual(String this.manualName) : customer = null;
}

/// Opens a searchable customer list and resolves to the one the user tapped,
/// or null if they backed out. Reusable anywhere a customer needs to be
/// linked to something (Mail's stripe_customer_id, Files' assigned_emails, ...).
/// Pass `allowManualEntry: true` (leads' "mark as Customer" flow) to also offer
/// a plain-name entry for customers of other businesses that aren't in Stripe.
Future<CustomerPickResult?> pickCustomer(
  BuildContext context, {
  bool allowManualEntry = false,
}) {
  return showModalBottomSheet<CustomerPickResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _CustomerPickerSheet(allowManualEntry: allowManualEntry),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  final bool allowManualEntry;
  const _CustomerPickerSheet({required this.allowManualEntry});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  final _manualNameCtrl = TextEditingController();
  List<Customer> _results = [];
  bool _loading = true;
  bool _manualMode = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _manualNameCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(value));
  }

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await OpsApi.instance.getCustomers(
        search: query.isEmpty ? null : query,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard-safe sizing: the bottom padding that dodges the keyboard has to sit OUTSIDE the
    // fixed-height box, not inside it — padding applied to a child inside a fixed-height SizedBox
    // just eats into that same fixed height, squeezing the Expanded results list down to almost
    // nothing once the keyboard opens (this is why the list used to look empty until dismissing
    // the keyboard — "have to hit search to see anything"). Shifting the whole box up instead
    // keeps the list's own proportions intact.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 48), // balances the close button so the handle stays centered
                Expanded(
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Cancel',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            Expanded(
              child: _manualMode ? _buildManualEntry(context) : _buildSearch(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Search customers...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
            onChanged: _onChanged,
          ),
        ),
        if (widget.allowManualEntry)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                onPressed: () => setState(() => _manualMode = true),
                child: const Text(
                  "Customer isn't in Stripe (another business — office space, residential, etc.) →",
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _results.isEmpty
              ? const Center(child: Text('No customers found.'))
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final c = _results[i];
                    return ListTile(
                      title: Text(c.displayName),
                      subtitle: Text(
                        c.email.isNotEmpty ? c.email : c.stripeCustomerId,
                      ),
                      onTap: () => Navigator.of(context).pop(CustomerPickResult.customer(c)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildManualEntry(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              onPressed: () => setState(() => _manualMode = false),
              child: const Text('← Back to Stripe customer search', style: TextStyle(fontSize: 12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _manualNameCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Customer name',
              hintText: 'e.g. Jane Doe — Office Space',
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 6),
          Text(
            'Not linked to Stripe or any billing data — just a name for the record.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _manualNameCtrl.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(CustomerPickResult.manual(_manualNameCtrl.text.trim())),
            child: const Text('Mark as Customer'),
          ),
        ],
      ),
    );
  }
}
