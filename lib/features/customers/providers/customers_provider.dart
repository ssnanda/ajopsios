import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/error_utils.dart';

class CustomersState {
  final List<Customer> customers;
  final bool loading;
  final String? error;
  final String search;
  /// 'all' (everything not archived), 'active', 'disabled', 'no_login' or 'archived'.
  final String statusFilter;
  /// Only customers with a Suite lease service.
  final bool suiteOnly;

  const CustomersState({
    this.customers = const [],
    this.loading = true,
    this.error,
    this.search = '',
    this.statusFilter = 'all',
    this.suiteOnly = false,
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? loading,
    String? error,
    bool clearError = false,
    String? search,
    String? statusFilter,
    bool? suiteOnly,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      suiteOnly: suiteOnly ?? this.suiteOnly,
    );
  }

  // Matches AJOps web: archived customers are filtered out client-side unless asked for.
  // customer_number is a fixed-width "YYYY-MM-NNNN" string assigned at creation time — sorting
  // it descending as a string puts the most recently created customers first.
  List<Customer> get visible {
    final list = customers.where((c) {
      final status = c.portalStatus;
      final statusOk = switch (statusFilter) {
        'active' => status == 'active',
        'disabled' => status == 'disabled',
        'no_login' => status == 'without_portal_login',
        'archived' => status == 'archived',
        _ => status != 'archived',
      };
      return statusOk && (!suiteOnly || c.serviceTypes.any((s) => s.toLowerCase().startsWith('suite')));
    }).toList();
    list.sort((a, b) => b.customerNumber.compareTo(a.customerNumber));
    return list;
  }
}

class CustomersNotifier extends StateNotifier<CustomersState> {
  CustomersNotifier() : super(const CustomersState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final customers = await _api.getCustomers(search: state.search.isEmpty ? null : state.search);
      state = state.copyWith(customers: customers, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    load();
  }

  void setStatusFilter(String value) => state = state.copyWith(statusFilter: value);

  void toggleSuiteOnly() => state = state.copyWith(suiteOnly: !state.suiteOnly);
}

final customersProvider = StateNotifierProvider.autoDispose<CustomersNotifier, CustomersState>(
  (ref) => CustomersNotifier(),
);
