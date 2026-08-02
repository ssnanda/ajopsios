import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/models/customer_file_model.dart';
import '../../../core/utils/error_utils.dart';

class FilesState {
  final List<CustomerFile> files;
  final bool loading;
  final String? error;
  final String search;
  final bool uploading;

  const FilesState({
    this.files = const [],
    this.loading = true,
    this.error,
    this.search = '',
    this.uploading = false,
  });

  FilesState copyWith({
    List<CustomerFile>? files,
    bool? loading,
    String? error,
    bool clearError = false,
    String? search,
    bool? uploading,
  }) {
    return FilesState(
      files: files ?? this.files,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      search: search ?? this.search,
      uploading: uploading ?? this.uploading,
    );
  }
}

class FilesNotifier extends StateNotifier<FilesState> {
  FilesNotifier() : super(const FilesState()) {
    load();
  }

  final _api = OpsApi.instance;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final files = await _api.getFiles(search: state.search.isEmpty ? null : state.search);
      state = state.copyWith(files: files, loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: friendlyError(e));
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
    load();
  }

  Future<String?> uploadFile({
    required String filePath,
    String? title,
    String? category,
    String? description,
    String? assignedEmails,
  }) async {
    state = state.copyWith(uploading: true);
    try {
      await _api.createFile(
        filePath: filePath,
        title: title,
        category: category,
        description: description,
        assignedEmails: assignedEmails,
      );
      state = state.copyWith(uploading: false);
      await load();
      return null;
    } catch (e) {
      state = state.copyWith(uploading: false);
      return friendlyError(e);
    }
  }
}

final filesProvider = StateNotifierProvider.autoDispose<FilesNotifier, FilesState>((ref) => FilesNotifier());
