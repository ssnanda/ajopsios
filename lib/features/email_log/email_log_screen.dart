import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/site_chip.dart';

class _Email {
  final int id;
  final String from, to, subject, status, error, createdAt;
  final int opens;
  const _Email({required this.id, required this.from, required this.to, required this.subject, required this.status, required this.error, required this.createdAt, required this.opens});

  factory _Email.fromJson(Map<String, dynamic> j) => _Email(
    id: int.tryParse('${j['id']}') ?? 0,
    from: '${j['from_email'] ?? ''}',
    to: '${j['to_email'] ?? ''}',
    subject: '${j['subject'] ?? ''}',
    status: '${j['status'] ?? ''}',
    error: '${j['error_message'] ?? ''}',
    createdAt: '${j['created_at'] ?? ''}',
    opens: int.tryParse('${j['open_count'] ?? 0}') ?? 0,
  );
}

/// Sent-email log (same data as AJOps > Email Log): search, filter by status, tap one to read it.
class EmailLogScreen extends StatefulWidget {
  const EmailLogScreen({super.key});

  @override
  State<EmailLogScreen> createState() => _EmailLogScreenState();
}

class _EmailLogScreenState extends State<EmailLogScreen> {
  final _search = TextEditingController();
  List<_Email> _emails = const [];
  bool _loading = true;
  String? _error;
  String _status = 'all'; // all | sent | failed

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
      final resp = await ApiClient.instance.dio.get(ApiEndpoints.emailLog, queryParameters: {
        'per_page': '300',
        if (_search.text.trim().isNotEmpty) 'search': _search.text.trim(),
      });
      final rows = ((resp.data as Map<String, dynamic>)['emails'] as List<dynamic>? ?? const []);
      setState(() { _emails = rows.map((e) => _Email.fromJson(e as Map<String, dynamic>)).toList(); _loading = false; });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  bool _isFailed(_Email e) => e.status.toLowerCase() == 'failed' || e.error.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final shown = _emails.where((e) => _status == 'all' || (_status == 'failed') == _isFailed(e)).toList();
    return Scaffold(
      appBar: AppBar(title: const AjAppBarTitle('Email Log')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search sender, recipient or subject…',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () { _search.clear(); _load(); }),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in const [('all', 'All'), ('sent', 'Sent'), ('failed', 'Failed')])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(f.$2, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      selected: _status == f.$1,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _status = f.$1),
                      visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const AjLoadingIndicator()
                : _error != null
                    ? ErrorState(message: _error!, onRetry: _load)
                    : shown.isEmpty
                        ? const EmptyState(icon: Icons.mark_email_read_outlined, title: 'No emails', subtitle: 'Nothing matches.')
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(12),
                              itemCount: shown.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final e = shown[i];
                                return Card(
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                                  child: ListTile(
                                    title: Text(e.subject.isEmpty ? '(no subject)' : e.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    subtitle: Text('To ${e.to}\n${e.createdAt}${e.opens > 0 ? ' · opened ${e.opens}×' : ''}', style: const TextStyle(fontSize: 12)),
                                    isThreeLine: true,
                                    trailing: Icon(_isFailed(e) ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded, color: _isFailed(e) ? Colors.red : Colors.green, size: 20),
                                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _EmailDetailScreen(email: e))),
                                  ),
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

class _EmailDetailScreen extends StatefulWidget {
  final _Email email;
  const _EmailDetailScreen({required this.email});

  @override
  State<_EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<_EmailDetailScreen> {
  String? _body;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await ApiClient.instance.dio.get(ApiEndpoints.emailLogEntry(widget.email.id));
      final row = ((resp.data as Map<String, dynamic>)['email'] as Map<String, dynamic>? ?? const {});
      setState(() => _body = _plain('${row['message'] ?? ''}'));
    } catch (e) {
      setState(() => _error = friendlyError(e));
    }
  }

  /// The log stores the HTML that was sent; show it as readable text.
  String _plain(String html) {
    var t = html
        .replaceAll(RegExp(r'<(style|script)[^>]*>.*?</\1>', dotAll: true, caseSensitive: false), '')
        .replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</tr>|</h\d>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&#039;', "'").replaceAll('&quot;', '"');
    t = t.replaceAll(RegExp(r'[ \t]+\n'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return t.trim();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Email')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(e.subject.isEmpty ? '(no subject)' : e.subject, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('From: ${e.from}', style: const TextStyle(fontSize: 13)),
          Text('To: ${e.to}', style: const TextStyle(fontSize: 13)),
          Text('Sent: ${e.createdAt}${e.opens > 0 ? ' · opened ${e.opens}×' : ''}', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
          if (e.error.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Error: ${e.error}', style: const TextStyle(color: Colors.red, fontSize: 13))),
          const Divider(height: 28),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red))
          else if (_body == null) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else SelectableText(_body!.isEmpty ? '(empty)' : _body!, style: const TextStyle(fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}
