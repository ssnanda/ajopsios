import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/api/ops_api.dart';
import '../../../core/utils/error_utils.dart';
import '../../../core/widgets/email_html_view.dart';
import 'pipeline_switch.dart';

const _stages = ['new', 'verified', 'charged', 'posted', 'ignored'];
const _stageLabel = {'new': 'New', 'verified': 'Verified', 'charged': 'Charged', 'posted': 'Posted', 'ignored': 'Ignored'};

/// Times arrive in UTC ("2026-11-14 13:15:55"); shown in the phone's own time zone.
DateTime? _local(dynamic s) => DateTime.tryParse('${s ?? ''}'.replaceFirst(' ', 'T') + 'Z')?.toLocal();

/// "Nov 14, 8:15 AM" (with the year when it is not this year); noTime for a date-only value (stored as noon UTC).
String _fmt(dynamic s, {bool noTime = false}) {
  final d = _local(s);
  if (d == null) return '—';
  final y = d.year != DateTime.now().year ? ', y' : '';
  return DateFormat('MMM d$y${noTime ? '' : ', h:mm a'}').format(d);
}

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
  String _label = ''; // '' | 'marketing'
  String _issue = ''; // '' | no_property | no_name | no_total | no_order (orders with bad data)
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
      final d = await OpsApi.instance.getPurchases(stage: _stage, search: _search.text.trim(), label: _label, issue: _issue);
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Sync = read new mail, then re-parse what is stored (repeated until nothing is left).
  Future<void> _read() async {
    if (((_data?['mailbox'] ?? '') as String).isEmpty) {
      _toast('Set the mailbox in AJCore first (Pipeline > Purchases).');
      return;
    }
    _toast('Syncing…');
    try {
      final r = await OpsApi.instance.processPurchases();
      var fixed = 0, left = 0;
      for (var i = 0; i < 12; i++) {
        final p = await OpsApi.instance.reparsePurchases();
        fixed += ((p['reparsed'] ?? 0) as num).toInt();
        left = ((p['remaining'] ?? 0) as num).toInt();
        if (left == 0) break;
      }
      _toast('${r['new'] ?? 0} new, ${r['scanned'] ?? 0} scanned · $fixed re-parsed${left != 0 ? ', $left left: sync again' : ''}');
      await _load();
    } catch (e) {
      _toast(friendlyError(e));
    }
  }

  Map<String, List<Map<String, dynamic>>> _byDay(List orders) {
    final m = <String, List<Map<String, dynamic>>>{};
    for (final o in orders) {
      final row = Map<String, dynamic>.from(o as Map);
      // Grouped by the latest email of the order (new mail rises to the top); falls back to the order date.
      final d = _local(row['last_email_at'] ?? row['order_date']);
      m.putIfAbsent(d == null ? '—' : DateFormat('yyyy-MM-dd').format(d), () => []).add(row);
    }
    return m;
  }

  Future<void> _open(Map<String, dynamic> o, [int index = 0]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _OrderSheet(order: o, initialIndex: index, marketingView: _label == 'marketing'),
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
            selected: _stage == key && _label.isEmpty,
            selectedColor: color?.withValues(alpha: .25),
            onSelected: (_) {
              setState(() {
                _label = '';
                _stage = _stage == key ? '' : key;
              });
              _load();
            },
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pipeline'),
        actions: [
          IconButton(icon: const Icon(Icons.sync_rounded), tooltip: 'Sync', onPressed: _read),
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
              // The Marketing label: a filter on these orders.
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
          // Orders with bad data: tap to filter, tap again to clear.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(children: [
              const Text('Needs attention', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(width: 8),
              for (final e in const [('no_property', 'No property'), ('no_name', 'Property not named'), ('no_total', 'No total'), ('no_order', 'No order #')])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('${e.$2}  ${((d?['issues'] as Map?)?[e.$1] ?? 0)}', style: const TextStyle(fontSize: 12)),
                    selected: _issue == e.$1,
                    selectedColor: Colors.amber.withValues(alpha: .35),
                    visualDensity: VisualDensity.compact,
                    onSelected: (((d?['issues'] as Map?)?[e.$1] ?? 0) == 0 && _issue != e.$1)
                        ? null
                        : (_) {
                            setState(() {
                              _label = '';
                              _issue = _issue == e.$1 ? '' : e.$1;
                            });
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
                                    for (final o in byDay[day]!) _OrderTile(order: o, onTap: () => _open(o), onEmail: (i) => _open(o, i)),
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
  final void Function(int index) onEmail;
  const _OrderTile({required this.order, required this.onTap, required this.onEmail});

  @override
  Widget build(BuildContext context) {
    final emails = (order['emails'] as List?) ?? const [];
    final prop = ((order['property_name'] ?? '') as String).isNotEmpty ? order['property_name'] : (order['property_tag'] ?? '');
    final no = ((order['order_no'] ?? '') as String).isNotEmpty ? order['order_no'] : order['invoice_no'];
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
            Text(
              'Updated ${_fmt(order['last_email_at'] ?? order['order_date'])}  ·  Ordered ${_fmt(order['order_date'], noTime: '${order['order_date'] ?? ''}'.endsWith('12:00:00'))}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Row(children: [
              Expanded(child: Text(((prop ?? '') as String).isEmpty ? 'No property' : prop as String, style: TextStyle(fontSize: 13, color: ((prop ?? '') as String).isEmpty ? Colors.orange : null))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade600)),
                child: Text(_stageLabel[order['stage']] ?? '${order['stage']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ]),
            if (emails.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, children: [
                  for (var i = 0; i < emails.length; i++)
                    InkWell(
                      onTap: () => onEmail(i),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.indigoAccent)),
                        child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      ),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  final Map<String, dynamic> order;
  final int initialIndex;
  final bool marketingView;
  const _OrderSheet({required this.order, this.initialIndex = 0, this.marketingView = false});

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
  late int _pick = widget.initialIndex;

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

  Future<void> _marketing() async {
    final rule = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(title: const Text('Label as marketing'), children: [
        SimpleDialogOption(onPressed: () => Navigator.pop(c, ''), child: const Text('Only this order')),
        SimpleDialogOption(onPressed: () => Navigator.pop(c, 'address'), child: const Text('This and future mail from this sender')),
      ]),
    );
    if (rule == null) return;
    setState(() => _busy = true);
    try {
      await OpsApi.instance.labelMarketing('purchases', [widget.order['id'] as int], 'marketing', rule);
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
      await OpsApi.instance.labelMarketing('purchases', [widget.order['id'] as int], '');
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
        title: const Text('Delete this order\'s emails?'),
        content: const Text('They are moved to the Zoho Trash and stay recoverable there.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await OpsApi.instance.deleteMarketing('purchases', [widget.order['id'] as int]);
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
          if (_emails.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('Emails (${_emails.length})', style: const TextStyle(fontWeight: FontWeight.w800)),
              for (var i = 0; i < _emails.length; i++)
                ChoiceChip(label: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)), selected: i == _pick.clamp(0, _emails.length - 1), showCheckmark: false, onSelected: (_) => setState(() => _pick = i)),
            ]),
          ],
          for (final m in (_emails.isEmpty ? <Map<String, dynamic>>[] : [_emails[_pick.clamp(0, _emails.length - 1)]])) ...[
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
            if (widget.marketingView) ...[
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700), onPressed: _busy ? null : _deleteMarketing, child: const Text('Delete (to Zoho Trash)')),
              OutlinedButton(onPressed: _busy ? null : _notMarketing, child: const Text('Not marketing')),
            ] else
              OutlinedButton(onPressed: _busy ? null : _marketing, child: const Text('Marketing')),
            for (final s in _stages.where((s) => s != cur))
              OutlinedButton(onPressed: _busy ? null : () => _save(s), child: Text('Mark ${_stageLabel[s]!.toLowerCase()}')),
          ]),
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Close')),
        ],
      ),
    );
  }
}
