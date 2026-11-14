import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/widgets/email_html_view.dart';
import 'pipeline_switch.dart';

/// Pipeline > Invoices / Insurance & HOA: the mailbox's emails by date, stage chips, email text and note on tap.
class MailPipelineScreen extends StatefulWidget {
  final String pipe;
  final String label;
  const MailPipelineScreen({super.key, required this.pipe, required this.label});

  @override
  State<MailPipelineScreen> createState() => _MailPipelineScreenState();
}

class _MailPipelineScreenState extends State<MailPipelineScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  String _stage = '';
  String _label = ''; // '' | 'marketing'
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
      final d = await OpsApi.instance.getMailPipeline(widget.pipe, stage: _stage, search: _search.text.trim(), label: _label);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _read() async {
    if (((_data?['mailbox'] ?? '') as String).isEmpty) {
      _toast('Set the mailbox in AJCore or AJOps first (Pipeline > ${widget.label}).');
      return;
    }
    _toast('Reading the mailbox…');
    try {
      final r = await OpsApi.instance.processMailPipeline(widget.pipe);
      _toast('${r['new'] ?? 0} new, ${r['scanned'] ?? 0} scanned');
      await _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    final stages = Map<String, dynamic>.from((_data?['stages'] as Map?) ?? const {});
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _ItemSheet(pipe: widget.pipe, item: item, stages: stages, marketingView: _label == 'marketing'),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final stages = Map<String, dynamic>.from((d?['stages'] as Map?) ?? const {});
    final counts = Map<String, dynamic>.from((d?['counts'] as Map?) ?? const {});
    final items = ((d?['items'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final byDay = <String, List<Map<String, dynamic>>>{};
    for (final i in items) {
      final r = '${i['received_at'] ?? ''}';
      byDay.putIfAbsent(r.length >= 10 ? r.substring(0, 10) : '—', () => []).add(i);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [IconButton(icon: const Icon(Icons.sync_rounded), tooltip: 'Read mailbox', onPressed: _read)],
      ),
      body: Column(
        children: [
          PipelineSwitch(current: widget.pipe),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              for (final k in stages.keys.where((k) => k != 'ignored'))
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${stages[k]}  ${counts[k] ?? 0}'),
                    selected: _stage == k && _label.isEmpty,
                    onSelected: (_) {
                      setState(() {
                        _label = '';
                        _stage = _stage == k ? '' : k;
                      });
                      _load();
                    },
                  ),
                ),
              // The Marketing label: a filter on this pipeline's own mail.
              FilterChip(
                label: Text('Marketing  ${d?['marketing'] ?? 0}'),
                selected: _label == 'marketing',
                selectedColor: Colors.amber.withValues(alpha: .3),
                onSelected: (_) {
                  setState(() {
                    _stage = '';
                    _label = _label == 'marketing' ? '' : 'marketing';
                  });
                  _load();
                },
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(isDense: true, hintText: 'Search subject, sender, note', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
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
                            ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No emails.')))])
                            : ListView(
                                children: [
                                  for (final day in days) ...[
                                    Container(
                                      width: double.infinity,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      child: Text('$day · ${byDay[day]!.length} ${byDay[day]!.length == 1 ? 'email' : 'emails'}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                    ),
                                    for (final i in byDay[day]!)
                                      InkWell(
                                        onTap: () => _open(i),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            SizedBox(width: 46, child: Text('${i['received_at'] ?? ''}'.length >= 16 ? '${i['received_at']}'.substring(11, 16) : '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500))),
                                            Expanded(
                                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                                Text('${i['subject'] ?? ''}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                                Text('${i['sender'] ?? ''}${(i['notes'] ?? '') != '' ? ' · ${i['notes']}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                              ]),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade600)),
                                              child: Text('${stages[i['stage']] ?? i['stage']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                          ]),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ItemSheet extends StatefulWidget {
  final String pipe;
  final Map<String, dynamic> item;
  final Map<String, dynamic> stages;
  final bool marketingView;
  const _ItemSheet({required this.pipe, required this.item, required this.stages, this.marketingView = false});

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late Map<String, dynamic> _full = widget.item;
  late final _notes = TextEditingController(text: '${widget.item['notes'] ?? ''}');
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    OpsApi.instance.getMailPipelineItem(widget.pipe, widget.item['id'] as int).then((d) {
      if (mounted) setState(() => _full = d);
    }).catchError((e) {
      if (mounted) setState(() => _error = friendlyError(e));
    });
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _marketing() async {
    final rule = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Label as marketing'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, ''), child: const Text('Only this email')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'address'), child: const Text('This and future mail from this sender')),
      ]),
    );
    if (rule == null) return;
    setState(() => _busy = true);
    try {
      await OpsApi.instance.labelMarketing(widget.pipe, [widget.item['id'] as int], 'marketing', rule);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notMarketing() async {
    setState(() => _busy = true);
    try {
      await OpsApi.instance.labelMarketing(widget.pipe, [widget.item['id'] as int], '');
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteMarketing() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete this email?'),
        content: const Text('It is moved to the Zoho Trash and stays recoverable there.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await OpsApi.instance.deleteMarketing(widget.pipe, [widget.item['id'] as int]);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save([String? stage]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OpsApi.instance.updateMailPipelineItem(widget.pipe, widget.item['id'] as int, {'notes': _notes.text.trim(), if (stage != null) 'stage': stage});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = '${_full['body'] ?? ''}'.isNotEmpty ? '${_full['body']}' : '${_full['summary'] ?? ''}';
    final cur = '${widget.item['stage']}';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${_full['subject'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text('${_full['sender'] ?? ''} · ${_full['received_at'] ?? ''}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          if ('${_full['body_debug'] ?? ''}'.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Only the preview could be read: ${_full['body_debug']}', style: const TextStyle(fontSize: 11, color: Colors.orange))),
          const SizedBox(height: 10),
          if ('${_full['body_html'] ?? ''}'.isNotEmpty)
            EmailHtmlView(html: '${_full['body_html']}', height: 460)
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 320),
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: SingleChildScrollView(child: Text(body, style: const TextStyle(fontSize: 12))),
            ),
          const SizedBox(height: 10),
          TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder(), isDense: true)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : () => _save(), child: const Text('Save note'))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (widget.marketingView) ...[
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: _busy ? null : _deleteMarketing, child: const Text('Delete (to Zoho Trash)')),
              OutlinedButton(onPressed: _busy ? null : _notMarketing, child: const Text('Not marketing')),
            ] else
              OutlinedButton(onPressed: _busy ? null : _marketing, child: const Text('Marketing')),
            for (final k in widget.stages.keys.where((k) => k != cur))
              OutlinedButton(onPressed: _busy ? null : () => _save(k), child: Text('Mark ${'${widget.stages[k]}'.toLowerCase()}')),
          ]),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
        ],
      ),
    );
  }
}
