import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/ops_api.dart';
import '../../dashboard/providers/dashboard_provider.dart';

/// "Sync all" row for More: runs AJCore's full sync and polls until it finishes (same cadence as AJOps web).
class SyncAllTile extends ConsumerStatefulWidget {
  const SyncAllTile({super.key});

  @override
  ConsumerState<SyncAllTile> createState() => _SyncAllTileState();
}

class _SyncAllTileState extends ConsumerState<SyncAllTile> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final runKey = await OpsApi.instance.triggerSync();
      Map<String, dynamic> status = {'done': false};
      for (var i = 0; i < 60 && !(status['done'] == true); i++) {
        await Future.delayed(const Duration(milliseconds: 1500));
        status = await OpsApi.instance.getSyncRunStatus(runKey);
      }
      if (!mounted) return;
      final synced = status['records_synced'];
      final errors = (status['errors'] as List<dynamic>?) ?? const [];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          status['done'] == true
              ? (errors.isEmpty ? 'Sync complete${synced != null ? ' — $synced records' : ''}.' : 'Sync finished with ${errors.length} error(s).')
              : 'Sync is still running in the background.',
        ),
      ));
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.sync_rounded),
      title: Text(_running ? 'Syncing…' : 'Sync all'),
      trailing: _running ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
      onTap: _running ? null : _run,
    );
  }
}
