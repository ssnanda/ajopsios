import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/widgets/email_html_view.dart';
import 'pipeline_switch.dart';

/// Pipeline > Marketing: every email labelled marketing from any pipeline, by date; tap to preview, delete (to the Zoho Trash) or restore.
class MarketingScreen extends StatefulWidget {
  const MarketingScreen({super.key});

  @override
  State<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends State<MarketingScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  String _pipeline = '';
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await OpsApi.instance.getMarketing(pipeline: _pipeline, search: _search.text.trim());
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PreviewSheet(item: item),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final pipelines = Map<String, dynamic>.from((d?['pipelines'] as Map?) ?? const {});
    final counts = Map<String, dynamic>.from((d?['counts'] as Map?) ?? const {});
    final items = ((d?['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      final r = '${i['received_at'] ?? ''}';
      byDay.putIfAbsent(r.length >= 10 ? r.substring(0, 10) : '—', () => []).add(i);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    return Scaffold(
      appBar: AppBar(title: const Text('Pipeline')),
      body: Column(
        children: [
          const PipelineSwitch(current: 'marketing'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              for (final k in pipelines.keys.where((k) => (counts[k] ?? 0) != 0 || k == _pipeline))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${pipelines[k]}  ${counts[k] ?? 0}'),
                    selected: _pipeline == k,
                    onSelected: (_) {
                      setState(() => _pipeline = _pipeline == k ? '' : k);
                      _load();
                    },
                  ),
                ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(isDense: true, hintText: 'Search subject, sender', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
            ),
          ),
          Expanded(
            child: _loading && d == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, style: const TextStyle(color: Colors.red))))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: days.isEmpty
                            ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No marketing emails.')))])
                            : ListView(children: [
                                for (final day in days) ...[
                                  Container(
                                    width: double.infinity,
                                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    child: Text('$day · ${byDay[day]!.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  ),
                                  for (final i in byDay[day]!)
                                    InkWell(
                                      onTap: () => _open(i),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                          Text('${i['subject'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                          Text('${i['sender'] ?? ''} · ${pipelines[i['pipeline']] ?? i['pipeline']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        ]),
                                      ),
                                    ),
                                ],
                              ]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _PreviewSheet extends StatefulWidget {
  final Map<String, dynamic> item;
  const _PreviewSheet({required this.item});

  @override
  State<_PreviewSheet> createState() => _PreviewSheetState();
}

class _PreviewSheetState extends State<_PreviewSheet> {
  late Map<String, dynamic> _full = widget.item;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    OpsApi.instance.getMarketingItem(widget.item['id'] as int).then((d) {
      if (mounted) setState(() => _full = d);
    }).catchError((e) {
      if (mounted) setState(() => _error = friendlyError(e));
    });
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await job();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final html = '${_full['body_html'] ?? ''}';
    final id = widget.item['id'] as int;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_full['subject'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          Text('${_full['sender'] ?? ''} · ${_full['received_at'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 10),
          if (html.isNotEmpty)
            EmailHtmlView(html: html, height: 460)
          else
            Text('${_full['body'] ?? ''}'.isNotEmpty ? '${_full['body']}' : '${_full['summary'] ?? ''}', style: const TextStyle(fontSize: 12)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              onPressed: _busy ? null : () => _run(() async => OpsApi.instance.deleteMarketing([id])),
              child: const Text('Delete (to Zoho Trash)'),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _busy ? null : () => _run(() => OpsApi.instance.restoreMarketing([id])), child: const Text('Not marketing')),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
        ],
      ),
    );
  }
}
