import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/error_utils.dart';

/// Service filter keys, same as AJOps > Customers.
const serviceFilters = [
  ('all', 'All'),
  ('ra', 'Registered Agent'),
  ('vo', 'Virtual Office'),
  ('none', 'No Subscription'),
  ('suite', 'Suite Clients'),
  ('archived', 'Archived'),
];

class CustomersState {
  final List<Customer> customers;
  final bool loading;
  final String? error;
  final String search;
  final List<({String key, String name})> partners;
  final bool showPartners;
  final bool showSubscriptionTypes; // Registered Agent / Virtual Office / No Subscription (AJCore-RA sites)
  final Set<String> ra;
  final Set<String> vo;
  final Set<String> any;
  final String serviceFilter;
  final String partnerFilter; // '' = all partners

  const CustomersState({
    this.customers = const [],
    this.loading = true,
    this.error,
    this.search = '',
    this.partners = const [],
    this.showPartners = false,
    this.showSubscriptionTypes = true,
    this.ra = const {},
    this.vo = const {},
    this.any = const {},
    this.serviceFilter = 'all',
    this.partnerFilter = '',
  });

  CustomersState copyWith({
    List<Customer>? customers,
    bool? loading,
    String? error,
    bool clearError = false,
    String? search,
    List<({String key, String name})>? partners,
    bool? showPartners,
    bool? showSubscriptionTypes,
    Set<String>? ra,
    Set<String>? vo,
    Set<String>? any,
    String? serviceFilter,
    String? partnerFilter,
  }) {
    return CustomersState(
      customers: customers ?? this.customers,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      partners: partners ?? this.partners,
      showPartners: showPartners ?? this.showPartners,
      showSubscriptionTypes: showSubscriptionTypes ?? this.showSubscriptionTypes,
      ra: ra ?? this.ra,
      vo: vo ?? this.vo,
      any: any ?? this.any,
      serviceFilter: serviceFilter ?? this.serviceFilter,
      partnerFilter: partnerFilter ?? this.partnerFilter,
    );
  }

  bool _isSuite(Customer c) => c.customerKind == 'suite_client';

  bool _matchesService(Customer c, String key) {
    final id = c.stripeCustomerId;
    if (key == 'archived') return c.portalStatus == 'archived';
    if (c.portalStatus == 'archived') return false;
    return switch (key) {
      'all' => true,
      'ra' => ra.contains(id),
      'vo' => vo.contains(id),
      'suite' => _isSuite(c),
      _ => !any.contains(id) && !_isSuite(c), // 'none'
    };
  }

  /// The two filter rows combine, so each chip's number is what you would get by picking it
  /// given what is already picked in the other row (same as AJOps).
  int serviceCount(String key) => customers.where((c) => _matchesService(c, key) && (partnerFilter.isEmpty || c.partnerKey == partnerFilter)).length;

  int partnerCount(String key) => customers.where((c) => _matchesService(c, serviceFilter) && (key.isEmpty || c.partnerKey == key)).length;

  bool get filtered => serviceFilter != 'all' || partnerFilter.isNotEmpty;

  // customer_number is a fixed-width "YYYY-MM-NNNN" string assigned at creation time — sorting
  // it descending as a string puts the most recently created customers first.
  List<Customer> get visible {
    final list = customers.where((c) => _matchesService(c, serviceFilter) && (partnerFilter.isEmpty || c.partnerKey == partnerFilter)).toList();
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
      // Filter inputs are optional extras: a failure here just leaves those rows out.
      final features = await _api.getCustomerFeatures().catchError((_) => (partners: false, registeredAgent: true));
      final partners = features.partners ? await _api.getPartners().catchError((_) => <({String key, String name})>[]) : <({String key, String name})>[];
      final counts = await _api.getProductCounts().catchError((_) => (ra: <String>{}, vo: <String>{}, any: <String>{}));
      state = state.copyWith(
        partners: partners,
        showPartners: partners.isNotEmpty,
        showSubscriptionTypes: features.registeredAgent,
        ra: counts.ra,
        vo: counts.vo,
        any: counts.any,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    load();
  }

  void setServiceFilter(String value) => state = state.copyWith(serviceFilter: value);

  void setPartnerFilter(String value) => state = state.copyWith(partnerFilter: value);

  void clearFilters() => state = state.copyWith(serviceFilter: 'all', partnerFilter: '');
}

final customersProvider = StateNotifierProvider.autoDispose<CustomersNotifier, CustomersState>(
  (ref) => CustomersNotifier(),
);
