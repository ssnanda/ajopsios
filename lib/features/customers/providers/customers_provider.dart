import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/error_utils.dart';

class CustomersState {
  final List<Customer> customers;
  final bool loading;
  final String? error;
  final String search;
  final bool includeArchived;

  const CustomersState({
    this.customers = const [],
    this.loading = true,
    this.error,
    this.search = '',
    this.includeArchived = false,
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? loading,
    String? error,
    bool clearError = false,
    String? search,
    bool? includeArchived,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  // Matches AJOps web: archived customers are filtered out client-side unless asked for.
  List<Customer> get visible =>
      includeArchived ? customers : customers.where((c) => c.portalStatus != 'archived').toList();
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

  void toggleIncludeArchived() => state = state.copyWith(includeArchived: !state.includeArchived);
}

final customersProvider = StateNotifierProvider.autoDispose<CustomersNotifier, CustomersState>(
  (ref) => CustomersNotifier(),
);
