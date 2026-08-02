import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/gmail_intake_item_model.dart';
import '../../../core/utils/error_utils.dart';

class GmailIntakeState {
  final List<GmailIntakeItem> items;
  final Map<String, int> stats;
  final bool loading;
  final String? error;
  final String status; // '' = all, or needs_review|matched_pending_file|filed|resolved|skipped_no_attachment

  const GmailIntakeState({
    this.items = const [],
    this.stats = const {},
    this.loading = true,
    this.error,
    this.status = 'needs_review',
  });

  GmailIntakeState copyWith({
    List<GmailIntakeItem>? items,
    Map<String, int>? stats,
    bool? loading,
    String? error,
    bool clearError = false,
    String? status,
  }) {
    return GmailIntakeState(
      items: items ?? this.items,
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
    );
  }
}

class GmailIntakeNotifier extends StateNotifier<GmailIntakeState> {
  GmailIntakeNotifier() : super(const GmailIntakeState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (items, stats) = await _api.getGmailIntakeItems(status: state.status.isEmpty ? null : state.status);
      state = state.copyWith(items: items, stats: stats, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setStatus(String value) {
    state = state.copyWith(status: value);
    load();
  }

  Future<String?> processNow() async {
    try {
      await _api.processGmailIntakeNow();
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }
}

final gmailIntakeProvider = StateNotifierProvider.autoDispose<GmailIntakeNotifier, GmailIntakeState>(
  (ref) => GmailIntakeNotifier(),
);
