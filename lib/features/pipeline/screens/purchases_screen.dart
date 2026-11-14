import 'package:flutter/material.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/widgets/email_html_view.dart';
import 'pipeline_switch.dart';

const _stages = ['new', 'verified', 'charged', 'posted', 'ignored'];
const _stageLabel = {'new': 'New', 'verified': 'Verified', 'charged': 'Charged', 'posted': 'Posted', 'ignored': 'Ignored'};

String _money(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
  if (n == null) return '—';
  final s = n.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\.)'), (m) => '${m[1]},');
  return '\$$s';
}

/// Pipeline > Purchases: orders grouped by date, each order with its emails nested under it (same layout as AJCore / AJOps web).
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;
  String _stage = '';
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
      final d = await OpsApi.instance.getPurchases(stage: _stage, search: _search.text.trim());
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
      _toast('Set the mailbox in AJCore first (Pipeline > Purchases).');
      return;
    }
    _toast('Reading the mailbox…');
    try {
      final r = await OpsApi.instance.processPurchases();
      _toast('${r['new'] ?? 0} new, ${r['scanned'] ?? 0} scanned');
      await _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Map<String, List<Map<String, dynamic>>> _byDay(List orders) {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      final row = Map<String, dynamic>.from(o as Map);
      final d = ((row['order_date'] ?? '') as String);
      m.putIfAbsent(d.length >= 10 ? d.substring(0, 10) : '—', () => []).add(row);
    }
    return m;
  }

  Future<void> _open(Map<String, dynamic> o) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _OrderSheet(order: o),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final stats = (d?['stats'] as Map?) ?? const {};
    final stages = (stats['stages'] as Map?) ?? const {};
    final byDay = _byDay((d?['orders'] as List?) ?? const []);
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

    Widget chip(String key, String label, int n, {Color? color}) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilterChip(
            label: Text('$label  $n'),
            selected: _stage == key,
            selectedColor: color?.withValues(alpha: .25),
            onSelected: (_) {
              setState(() => _stage = _stage == key ? '' : key);
              _load();
            },
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), tooltip: 'Read mailbox', onPressed: _read),
        ],
      ),
      body: Column(
        children: [
          const PipelineSwitch(current: 'purchases'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              chip('verify', 'Needs verification', (stats['needs_verification'] ?? 0) as int, color: Colors.orange),
              chip('new', 'New', (stages['new'] ?? 0) as int),
              chip('verified', 'Verified', (stages['verified'] ?? 0) as int, color: Colors.green),
              chip('charged', 'Charged', (stages['charged'] ?? 0) as int, color: Colors.green),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Row(children: [
              Text('Total ${_money(stats['total_spent'])}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 14),
              Text('This month ${_money(stats['this_month'])}'),
              const SizedBox(width: 14),
              Text('No property ${stats['unassigned'] ?? 0}'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(isDense: true, hintText: 'Search order, invoice, property, vendor', prefixIcon: Icon(Icons.search_rounded), border: OutlineInputBorder()),
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
                            ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No orders match.')))])
                            : ListView(
                                children: [
                                  for (final day in days) ...[
                                    Container(
                                      width: double.infinity,
                                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                      child: Text(
                                        '$day · ${byDay[day]!.length} ${byDay[day]!.length == 1 ? 'order' : 'orders'} · ${_money(byDay[day]!.fold<double>(0, (a, o) => a + (double.tryParse('${o['total'] ?? 0}') ?? 0)))}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                    for (final o in byDay[day]!) _OrderTile(order: o, onTap: () => _open(o)),
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

class _OrderTile extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  const _OrderTile({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emails = (order['emails'] as List?) ?? const [];
    final prop = ((order['property_name'] ?? '') as String).isNotEmpty ? order['property_name'] : (order['property_tag'] ?? '');
    final no = ((order['order_no'] ?? '') as String).isNotEmpty ? order['order_no'] : order['invoice_no'];
    final grey = TextStyle(fontSize: 12, color: Colors.grey.shade500);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text('${order['vendor'] ?? ''} · ${no ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text(_money(order['total']), style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(((prop ?? '') as String).isEmpty ? 'No property' : prop as String, style: TextStyle(fontSize: 13, color: ((prop ?? '') as String).isEmpty ? Colors.orange : null))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade600)),
                child: Text(_stageLabel[order['stage']] ?? '${order['stage']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            for (final e in emails)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 3),
                child: Text(
                  '${((e['received_at'] ?? '') as String).length >= 16 ? (e['received_at'] as String).substring(11, 16) : ''}  ${e['kind'] ?? ''}  ${e['subject'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: grey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  const _OrderSheet({required this.order});

  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  late final _tag = TextEditingController(text: '${widget.order['property_tag'] ?? ''}');
  late final _name = TextEditingController(text: '${widget.order['property_name'] ?? ''}');
  late final _total = TextEditingController(text: widget.order['total'] == null ? '' : '${widget.order['total']}');
  late final _notes = TextEditingController(text: '${widget.order['notes'] ?? ''}');
  String? _error;
  bool _busy = false;
  List<Map<String, dynamic>> _emails = [];

  @override
  void initState() {
    super.initState();
    // Opening an order shows its emails in full (the server fetches any text it does not have yet).
    OpsApi.instance.getPurchaseEmails(widget.order['id'] as int).then((e) {
      if (mounted) setState(() => _emails = e);
    }).catchError((e) {
      if (mounted) setState(() => _error = friendlyError(e));
    });
  }

  @override
  void dispose() {
    _tag.dispose();
    _name.dispose();
    _total.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save([String? stage]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OpsApi.instance.updatePurchase(widget.order['id'] as int, {
        'property_tag': _tag.text.trim(),
        'property_name': _name.text.trim(),
        'total': _total.text.trim(),
        'notes': _notes.text.trim(),
        if (stage != null) 'stage': stage,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final cur = '${o['stage']}';
    InputDecoration dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder(), isDense: true);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${o['vendor'] ?? ''} · ${(o['order_no'] ?? '') != '' ? o['order_no'] : o['invoice_no']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          TextField(controller: _tag, decoration: dec('Property (delivery address, else PO# tag)')),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: dec('Property name')),
          const SizedBox(height: 8),
          TextField(controller: _total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: dec('Total')),
          const SizedBox(height: 8),
          TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: dec('Notes')),
          for (final m in _emails) ...[
            const SizedBox(height: 12),
            Text('${m['received_at'] ?? ''} · ${m['kind'] ?? ''} · ${m['subject'] ?? ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            if ('${(m['parsed'] as Map?)?['body_debug'] ?? ''}'.isNotEmpty) Text('Only the preview could be read: ${(m['parsed'] as Map)['body_debug']}', style: const TextStyle(fontSize: 11, color: Colors.orange)),
            const SizedBox(height: 6),
            if ('${(m['parsed'] as Map?)?['html'] ?? ''}'.isNotEmpty)
              EmailHtmlView(html: '${(m['parsed'] as Map)['html']}', height: 420)
            else
              Text('${(m['parsed'] as Map?)?['body'] ?? ''}', style: const TextStyle(fontSize: 12)),
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : () => _save(), child: const Text('Save'))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final s in _stages.where((s) => s != cur))
              OutlinedButton(onPressed: _busy ? null : () => _save(s), child: Text('Mark ${_stageLabel[s]!.toLowerCase()}')),
          ]),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
        ],
      ),
    );
  }
}
