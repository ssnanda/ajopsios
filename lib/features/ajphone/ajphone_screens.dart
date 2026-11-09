import 'package:flutter/material.dart';
import '../../core/api/ajops_api.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/site_chip.dart';

String _dash(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  final n = d.length == 11 && d.startsWith('1') ? d.substring(1) : d;
  return n.length == 10 ? '${n.substring(0, 3)}-${n.substring(3, 6)}-${n.substring(6)}' : raw;
}

DateTime? _when(String raw) => DateTime.tryParse(raw)?.toLocal();

String _short(String raw) {
  final t = _when(raw);
  if (t == null) return '';
  final now = DateTime.now();
  final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
  final hm = '${t.hour % 12 == 0 ? 12 : t.hour % 12}:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  return sameDay ? hm : '${t.month}/${t.day} $hm';
}

class _Convo {
  final String id, accountKey, ownUserId, peer, own, last, lastAt, name;
  final bool unread, human;
  _Convo.fromJson(Map<String, dynamic> j)
      : id = '${j['id'] ?? ''}',
        accountKey = '${j['accountKey'] ?? ''}',
        ownUserId = '${j['ownUserId'] ?? ''}',
        peer = '${j['peerNumber'] ?? ''}',
        own = '${j['ownNumber'] ?? ''}',
        last = '${j['lastMessage'] ?? ''}',
        lastAt = '${j['lastActivityAt'] ?? j['last_activity_at'] ?? j['lastMessageAt'] ?? ''}',
        name = '${j['contactName'] ?? ''}',
        unread = j['isRead'] == false,
        human = j['queue'] == 'human';
}

class _Msg {
  final String body, direction, at;
  _Msg.fromJson(Map<String, dynamic> j)
      : body = '${j['body'] ?? ''}',
        direction = '${j['direction'] ?? ''}',
        at = '${j['sentAt'] ?? ''}';
}

/// AJPhone (texts) on the phone. It reads and sends through AJOps, which holds the Zoom connection.
class AjphoneScreen extends StatefulWidget {
  const AjphoneScreen({super.key});

  @override
  State<AjphoneScreen> createState() => _AjphoneScreenState();
}

class _AjphoneScreenState extends State<AjphoneScreen> {
  final _search = TextEditingController();
  List<_Convo> _all = const [];
  bool _loading = true;
  String? _error;
  bool _unreadOnly = false;

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
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await AjopsApi.instance.get('/api/ajphone/messages', query: {'recent': '1'});
      final rows = ((resp.data as Map<String, dynamic>)['sessions'] as List<dynamic>? ?? const []);
      final list = rows.map((e) => _Convo.fromJson(e as Map<String, dynamic>)).toList()
        ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
      setState(() { _all = list; _loading = false; });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final shown = _all.where((c) => (!_unreadOnly || c.unread) && (q.isEmpty || '${c.name} ${c.peer} ${c.last}'.toLowerCase().contains(q))).toList();
    return Scaffold(
      appBar: AppBar(title: const AjAppBarTitle('AJPhone'), actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load)]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search name, number or message…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => setState(_search.clear)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('Unread${_all.any((c) => c.unread) ? ' (${_all.where((c) => c.unread).length})' : ''}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  selected: _unreadOnly,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _unreadOnly = !_unreadOnly),
                  visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ]),
          ),
          Expanded(
            child: _loading
                ? const AjLoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : shown.isEmpty
                        ? const EmptyState(icon: Icons.sms_outlined, title: 'No conversations', subtitle: 'Nothing matches.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              itemCount: shown.length,
                              separatorBuilder: (_, _) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final c = shown[i];
                                return ListTile(
                                  title: Text(c.name.isNotEmpty ? c.name : _dash(c.peer), style: TextStyle(fontWeight: c.unread ? FontWeight.w800 : FontWeight.w600)),
                                  subtitle: Text(c.last, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: c.unread ? FontWeight.w600 : FontWeight.w400)),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(_short(c.lastAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                      if (c.unread) const Padding(padding: EdgeInsets.only(top: 4), child: Icon(Icons.circle, size: 10, color: Colors.blue)),
                                    ],
                                  ),
                                  onTap: () async {
                                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _ThreadScreen(convo: c)));
                                    if (mounted) _load();
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _ThreadScreen extends StatefulWidget {
  final _Convo convo;
  const _ThreadScreen({required this.convo});

  @override
  State<_ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<_ThreadScreen> {
  final _input = TextEditingController();
  List<_Msg> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    _markRead();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = widget.convo;
    try {
      final resp = await AjopsApi.instance.get('/api/ajphone/messages', query: {
        'session_id': c.id,
        if (c.accountKey.isNotEmpty) 'account_key': c.accountKey,
        if (c.own.isNotEmpty) 'own_number': c.own,
        if (c.ownUserId.isNotEmpty) 'user_id': c.ownUserId,
      });
      final rows = ((resp.data as Map<String, dynamic>)['messages'] as List<dynamic>? ?? const []);
      final list = rows.map((e) => _Msg.fromJson(e as Map<String, dynamic>)).toList()..sort((a, b) => a.at.compareTo(b.at));
      if (mounted) setState(() { _messages = list; _loading = false; _error = null; });
    } catch (e) {
      if (mounted) setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _markRead() async {
    final c = widget.convo;
    try {
      // Same key AJOps uses: "<account>:<own number>|<their number>" with country code 1 stripped.
      String n(String raw) {
        final d = raw.replaceAll(RegExp(r'\D'), '');
        return d.length == 11 && d.startsWith('1') ? d.substring(1) : d;
      }
      final own = n(c.own), peer = n(c.peer);
      final scope = c.accountKey.isEmpty ? 'default' : c.accountKey;
      final key = own.isNotEmpty && peer.isNotEmpty ? '$scope:$own|$peer' : '$scope:${c.id}';
      await AjopsApi.instance.post('/api/ajphone/conversations', {'key': key, 'accountKey': c.accountKey, 'ownNumber': c.own, 'peerNumber': c.peer, 'isRead': true});
    } catch (_) {/* best effort */}
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final c = widget.convo;
    setState(() => _sending = true);
    try {
      await AjopsApi.instance.post('/api/ajphone/send', {'to': c.peer, 'from': c.own, 'message': text, if (c.accountKey.isNotEmpty) 'accountKey': c.accountKey});
      _input.clear();
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.convo;
    return Scaffold(
      appBar: AppBar(title: Text(c.name.isNotEmpty ? c.name : _dash(c.peer))),
      body: Column(
        children: [
          if (c.name.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(_dash(c.peer), style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          Expanded(
            child: _loading
                ? const AjLoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, i) {
                          final m = _messages[i];
                          final mine = m.direction == 'outbound';
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                              decoration: BoxDecoration(
                                color: mine ? Theme.of(context).colorScheme.primary : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.body, style: TextStyle(color: mine ? Colors.white : Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(_short(m.at), style: TextStyle(fontSize: 10, color: mine ? Colors.white70 : Colors.grey.shade600)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: 'Text message', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(20))),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
