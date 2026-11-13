import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/pipeline_item_model.dart';
import '../../../core/utils/error_utils.dart';

const kPipelinePending = {'needs_review', 'matched_pending_file', 'skipped_no_attachment'};
const kPipelineFiled = {'filed', 'resolved', 'duplicate'};

class PipelineState {
  final List<PipelineItem> all;
  final Map<String, Map<String, bool>> sources; // gmail|zoho -> {connected, enabled}
  final bool loading;
  final String? error;
  final String status; // pending | filed
  final String source; // '' = all mailboxes, gmail | zoho
  final String search;

  const PipelineState({
    this.all = const [],
    this.sources = const {},
    this.loading = true,
    this.error,
    this.status = 'pending',
    this.source = '',
    this.search = '',
  });

  /// Count for the tiles: entries in [statuses] for one mailbox ('' = all).
  int countOf(String source, Set<String> statuses) =>
      all.where((i) => (source.isEmpty || i.source == source) && statuses.contains(i.status)).length;

  /// The list shown: selected status group and mailbox, narrowed by the search text.
  List<PipelineItem> get items {
    final group = status == 'filed' ? kPipelineFiled : kPipelinePending;
    final q = search.trim().toLowerCase();
    return all.where((i) {
      if (!group.contains(i.status)) return false;
      if (source.isNotEmpty && i.source != source) return false;
      if (q.isEmpty) return true;
      return i.subject.toLowerCase().contains(q) ||
          i.sender.toLowerCase().contains(q) ||
          i.companyNameExtracted.toLowerCase().contains(q) ||
          i.customerName.toLowerCase().contains(q);
    }).toList();
  }

  PipelineState copyWith({
    List<PipelineItem>? all,
    Map<String, Map<String, bool>>? sources,
    bool? loading,
    String? error,
    bool clearError = false,
    String? status,
    String? source,
    String? search,
  }) {
    return PipelineState(
      all: all ?? this.all,
      sources: sources ?? this.sources,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      status: status ?? this.status,
      source: source ?? this.source,
      search: search ?? this.search,
    );
  }
}

class PipelineNotifier extends StateNotifier<PipelineState> {
  PipelineNotifier() : super(const PipelineState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final (items, _, sources) = await _api.getPipelineItems();
      state = state.copyWith(all: items, sources: sources, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  // Everything below filters the loaded list immediately; nothing waits on a Filter button.
  void setStatus(String value) => state = state.copyWith(status: value);
  void setSource(String value) => state = state.copyWith(source: value);
  void setSearch(String value) => state = state.copyWith(search: value);
  void clearFilters() => state = state.copyWith(status: 'pending', source: '', search: '');

  /// Reads every connected mailbox now, then reloads. Returns an error message or null.
  Future<String?> processNow() async {
    try {
      await _api.processPipelineNow();
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Clears pending entries (filed ones stay). Returns an error message or null.
  Future<String?> resetLog() async {
    try {
      await _api.resetPipelineLog();
      await load();
      return null;
    } catch (e) {
      return friendlyError(e);
    }
  }
}

final pipelineProvider = StateNotifierProvider.autoDispose<PipelineNotifier, PipelineState>(
  (ref) => PipelineNotifier(),
);
