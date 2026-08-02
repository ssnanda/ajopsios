import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/utils/error_utils.dart';

class CustomerDetailState {
  final CustomerDetail? detail;
  final bool loading;
  final String? error;
  final bool actionBusy;

  const CustomerDetailState({this.detail, this.loading = true, this.error, this.actionBusy = false});

  CustomerDetailState copyWith({CustomerDetail? detail, bool? loading, String? error, bool clearError = false, bool? actionBusy}) {
    return CustomerDetailState(
      detail: detail ?? this.detail,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      actionBusy: actionBusy ?? this.actionBusy,
    );
  }
}

class CustomerDetailNotifier extends StateNotifier<CustomerDetailState> {
  CustomerDetailNotifier(this.stripeCustomerId) : super(const CustomerDetailState()) {
    load();
  }

  final String stripeCustomerId;
  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final detail = await _api.getCustomerDetail(stripeCustomerId);
      state = state.copyWith(detail: detail, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  Future<String?> runAction(String action) async {
    state = state.copyWith(actionBusy: true);
    try {
      await _api.runCustomerAction(stripeCustomerId, action);
      await load();
      state = state.copyWith(actionBusy: false);
      return null;
    } catch (e) {
      state = state.copyWith(actionBusy: false);
      return friendlyError(e);
    }
  }
}

final customerDetailProvider = StateNotifierProvider.autoDispose.family<CustomerDetailNotifier, CustomerDetailState, String>(
  (ref, stripeCustomerId) => CustomerDetailNotifier(stripeCustomerId),
);
