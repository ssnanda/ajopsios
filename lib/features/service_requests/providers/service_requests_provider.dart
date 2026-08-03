import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/ops_service_request_model.dart';
import '../../../core/models/staff_model.dart';

/// Matches AJCore's view filters. Open on All so requests without a generated
/// next-action button remain visible; Needs Action stays available as a filter.
enum ServiceRequestsView { needsAction, all, active, completed }

extension on ServiceRequestsView {
  String? get queryValue => switch (this) {
    ServiceRequestsView.needsAction => null,
    ServiceRequestsView.all => 'all',
    ServiceRequestsView.active => 'active',
    ServiceRequestsView.completed => 'completed',
  };
}

class ServiceRequestsState {
  final List<OpsServiceRequest> requests;
  final OpsServiceRequestStats stats;
  final List<StaffModel> staff;
  final bool loading;
  final String? error;
  final ServiceRequestsView view;
  final String search;
  final Set<int> selectedIds;
  final Set<int>
  busyIds; // requests currently mid-update, to disable their controls

  const ServiceRequestsState({
    this.requests = const [],
    this.stats = OpsServiceRequestStats.empty,
    this.staff = const [],
    this.loading = true,
    this.error,
    this.view = ServiceRequestsView.all,
    this.search = '',
    this.selectedIds = const {},
    this.busyIds = const {},
  });

  ServiceRequestsState copyWith({
    List<OpsServiceRequest>? requests,
    OpsServiceRequestStats? stats,
    List<StaffModel>? staff,
    bool? loading,
    String? error,
    bool clearError = false,
    ServiceRequestsView? view,
    String? search,
    Set<int>? selectedIds,
    Set<int>? busyIds,
  }) {
    return ServiceRequestsState(
      requests: requests ?? this.requests,
      stats: stats ?? this.stats,
      staff: staff ?? this.staff,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      view: view ?? this.view,
      search: search ?? this.search,
      selectedIds: selectedIds ?? this.selectedIds,
      busyIds: busyIds ?? this.busyIds,
    );
  }
}

class ServiceRequestsNotifier extends StateNotifier<ServiceRequestsState> {
  ServiceRequestsNotifier() : super(const ServiceRequestsState()) {
    _loadStaff();
    load();
  }

  final _api = OpsApi.instance;

  Future<void> _loadStaff() async {
    try {
      final staff = await _api.getStaff();
      state = state.copyWith(staff: staff);
    } catch (_) {
      // Non-fatal — assignee dropdown just shows "Unassigned" only.
    }
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (rows, stats) = await _api.getServiceRequests(
        status: state.view.queryValue,
        search: state.search.isEmpty ? null : state.search,
      );
      state = state.copyWith(requests: rows, stats: stats, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setView(ServiceRequestsView view) {
    state = state.copyWith(view: view, selectedIds: {});
    load();
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    load();
  }

  void toggleSelected(int id) {
    final next = {...state.selectedIds};
    if (!next.add(id)) next.remove(id);
    state = state.copyWith(selectedIds: next);
  }

  void toggleSelectAll() {
    final allSelected =
        state.requests.isNotEmpty &&
        state.requests.every((r) => state.selectedIds.contains(r.id));
    state = state.copyWith(
      selectedIds: allSelected ? {} : state.requests.map((r) => r.id).toSet(),
    );
  }

  void clearSelection() => state = state.copyWith(selectedIds: {});

  Future<String?> addNote(int id, String note) async {
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _api.updateServiceRequest(id, note: note);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return e.toString();
    }
  }

  Future<String?> updateServiceStatus(int id, String serviceStatus) async {
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _api.updateServiceRequest(id, serviceStatus: serviceStatus);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return e.toString();
    }
  }

  Future<String?> updateAssignee(int id, int userId) async {
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _api.updateServiceRequest(id, assignedUserId: userId);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return e.toString();
    }
  }

  Future<String?> notifyCustomer(int id) async {
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _api.notifyServiceRequest(id);
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return null;
    } catch (e) {
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return e.toString();
    }
  }

  Future<String?> applyQuickAction(int id, String action) async {
    state = state.copyWith(busyIds: {...state.busyIds, id});
    try {
      await _api.applyServiceRequestQuickAction(id, action);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(busyIds: {...state.busyIds}..remove(id));
      return e.toString();
    }
  }

  Future<String?> bulkApply({
    String? serviceStatus,
    int? assignedUserId,
  }) async {
    final ids = state.selectedIds.toList();
    if (ids.isEmpty) return 'No requests selected.';
    try {
      await _api.bulkUpdateServiceRequests(
        ids,
        serviceStatus: serviceStatus,
        assignedUserId: assignedUserId,
      );
      state = state.copyWith(selectedIds: {});
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

final serviceRequestsProvider =
    StateNotifierProvider.autoDispose<
      ServiceRequestsNotifier,
      ServiceRequestsState
    >((ref) => ServiceRequestsNotifier());
