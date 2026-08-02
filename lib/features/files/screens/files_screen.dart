import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/customer_file_model.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../providers/files_provider.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.platform.pickFiles();
    final path = result?.files.single.path;
    if (path == null || !mounted) return;
    final err = await ref.read(filesProvider.notifier).uploadFile(filePath: path);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File uploaded.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(filesProvider);
    final notifier = ref.read(filesProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Files')),
      floatingActionButton: FloatingActionButton(
        onPressed: state.uploading ? null : _attachFile,
        child: state.uploading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.attach_file_rounded),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _searchCtrl.clear(); notifier.setSearch(''); }),
              ),
              onSubmitted: notifier.setSearch,
            ),
          ),
          Expanded(
            child: state.loading
                ? const AjLoadingIndicator()
                : state.error != null
                    ? ErrorState(message: state.error!, onRetry: notifier.load)
                    : state.files.isEmpty
                        ? const EmptyState(icon: Icons.folder_outlined, title: 'No files', subtitle: 'Tap the attach button to upload one.')
                        : RefreshIndicator(
                            onRefresh: notifier.load,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
                              itemCount: state.files.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 10),
                              itemBuilder: (context, i) => _FileCard(file: state.files[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _FileCard extends StatelessWidget {
  final CustomerFile file;
  const _FileCard({required this.file});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: file.fileUrl.isEmpty ? null : () => launchUrl(Uri.parse(file.fileUrl), mode: LaunchMode.externalApplication),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(file.displayTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    if (file.category.isNotEmpty)
                      Text(file.category, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (file.fileUrl.isNotEmpty) const Icon(Icons.open_in_new_rounded, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
