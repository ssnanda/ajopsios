import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/mail_item_model.dart';
import '../../../core/utils/error_utils.dart';

class MailState {
  final List<MailItem> items;
  final Map<String, int> stats;
  final bool loading;
  final String? error;
  final String status; // '' = all, or received|scanned|notified|closed
  final bool creating;

  const MailState({
    this.items = const [],
    this.stats = const {},
    this.loading = true,
    this.error,
    this.status = '',
    this.creating = false,
  });

  MailState copyWith({
    List<MailItem>? items,
    Map<String, int>? stats,
    bool? loading,
    String? error,
    bool clearError = false,
    String? status,
    bool? creating,
  }) {
    return MailState(
      items: items ?? this.items,
      stats: stats ?? this.stats,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      creating: creating ?? this.creating,
    );
  }
}

class MailNotifier extends StateNotifier<MailState> {
  MailNotifier() : super(const MailState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (items, stats) = await _api.getMailItems(status: state.status.isEmpty ? null : state.status);
      state = state.copyWith(items: items, stats: stats, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setStatus(String value) {
    state = state.copyWith(status: value);
    load();
  }

  Future<String?> createMailItem({
    required String recipientName,
    required String mailType,
    String? senderName,
    String? trackingNumber,
    String? description,
    String? scanFilePath,
  }) async {
    state = state.copyWith(creating: true);
    try {
      await _api.createMailItem(
        recipientName: recipientName,
        mailType: mailType,
        senderName: senderName,
        trackingNumber: trackingNumber,
        description: description,
        scanFilePath: scanFilePath,
      );
      state = state.copyWith(creating: false);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(creating: false);
      return friendlyError(e);
    }
  }
}

final mailProvider = StateNotifierProvider.autoDispose<MailNotifier, MailState>((ref) => MailNotifier());
