import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/api/ajops_api.dart';
import '../../core/api/api_client.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/api/api_endpoints.dart';
import '../../core/utils/error_utils.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../core/widgets/site_chip.dart';

/// Settings hub: the pieces of AJOps > Settings that make sense on a phone.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AjAppBarTitle('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('Staff'),
            subtitle: const Text('Names, emails, access and sections'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StaffSettingsScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.tablet_mac_rounded),
            title: const Text('Reception'),
            subtitle: const Text('Front desk iPad keys'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceptionSettingsScreen())),
          ),
          const Divider(height: 1),
          const _OpsAddressTile(),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Portal, Products & Services, Recurring Transactions and the AJPhone settings are on AJOps (web) for now.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where AJPhone (and other AJOps-only features) are reached. Defaults to ops.<your site>.
class _OpsAddressTile extends StatefulWidget {
  const _OpsAddressTile();

  @override
  State<_OpsAddressTile> createState() => _OpsAddressTileState();
}

class _OpsAddressTileState extends State<_OpsAddressTile> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final url = await AjopsApi.instance.baseUrl();
    if (mounted) setState(() => _url = url);
  }

  Future<void> _edit() async {
    final c = TextEditingController(text: _url ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AJOps address'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: c, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(hintText: 'https://ops.example.com')),
          const SizedBox(height: 8),
          const Text('Used for AJPhone. Leave empty to use ops.<your site>.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    if (result.isEmpty) {
      await SecureStorage.instance.clearOpsUrl();
    } else {
      await SecureStorage.instance.saveOpsUrl(result.startsWith('http') ? result : 'https://$result');
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.link_rounded),
      title: const Text('AJOps address'),
      subtitle: Text(_url ?? 'Not set'),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: _edit,
    );
  }
}

// ── Staff ──────────────────────────────────────────────────────────────────

class _Staff {
  final int id;
  String name, email;
  final String role;
  final bool isAdmin;
  bool opsAccess;
  Map<String, String>? permissions; // null = full access
  _Staff.fromJson(Map<String, dynamic> j)
      : id = int.tryParse('${j['id']}') ?? 0,
        name = '${j['display_name'] ?? j['username'] ?? ''}',
        email = '${j['email'] ?? ''}',
        role = ((j['roles'] as List?)?.isNotEmpty ?? false) ? '${(j['roles'] as List).first}' : '',
        isAdmin = j['is_admin'] == true,
        opsAccess = j['ops_access'] == true,
        permissions = j['permissions'] is Map
            ? (j['permissions'] as Map).map((k, v) => MapEntry('$k', '$v'))
            : null;
}

class StaffSettingsScreen extends StatefulWidget {
  const StaffSettingsScreen({super.key});

  @override
  State<StaffSettingsScreen> createState() => _StaffSettingsScreenState();
}

class _StaffSettingsScreenState extends State<StaffSettingsScreen> {
  List<_Staff> _staff = const [];
  Map<String, String> _sections = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final dio = ApiClient.instance.dio;
      final results = await Future.wait([dio.get(ApiEndpoints.staff), dio.get(ApiEndpoints.me)]);
      final staff = ((results[0].data as Map<String, dynamic>)['staff'] as List<dynamic>? ?? const []);
      final sections = ((results[1].data as Map<String, dynamic>)['sections'] as Map?) ?? const {};
      setState(() {
        _staff = staff.map((e) => _Staff.fromJson(e as Map<String, dynamic>)).toList();
        _sections = sections.map((k, v) => MapEntry('$k', '$v'));
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _call(Future<void> Function() fn, String done) async {
    try {
      await fn();
      if (mounted) _snack(done);
      await _load();
    } catch (e) {
      if (mounted) _snack(friendlyError(e));
    }
  }

  Future<void> _edit(_Staff s) async {
    final name = TextEditingController(text: s.name);
    final email = TextEditingController(text: s.email);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit staff'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 8),
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    await _call(() => ApiClient.instance.dio.post(ApiEndpoints.staffProfile(s.id), data: {'display_name': name.text.trim(), 'email': email.text.trim()}), 'Saved.');
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add staff member'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email *')),
          const SizedBox(height: 8),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 8),
          const Text('They get the AJ Ops User role and an email to set a password.', style: TextStyle(fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create & invite')),
        ],
      ),
    );
    if (ok != true || email.text.trim().isEmpty) return;
    await _call(() => ApiClient.instance.dio.post(ApiEndpoints.staff, data: {'email': email.text.trim(), 'display_name': name.text.trim()}), 'Invite sent.');
  }

  Future<void> _sections_(_Staff s) async {
    final levels = <String, String>{for (final k in _sections.keys) k: s.permissions == null ? 'edit' : (s.permissions![k] ?? 'none')};
    var full = s.permissions == null;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.85,
            child: Column(
              children: [
                SwitchListTile(
                  title: Text('${s.name}: full access'),
                  subtitle: const Text('Everything, can edit'),
                  value: full,
                  onChanged: (v) => setSheet(() => full = v),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    children: [
                      for (final key in _sections.keys)
                        ListTile(
                          dense: true,
                          title: Text(_sections[key]!),
                          trailing: SegmentedButton<String>(
                            showSelectedIcon: false,
                            style: const ButtonStyle(visualDensity: VisualDensity(horizontal: -3, vertical: -3)),
                            segments: const [
                              ButtonSegment(value: 'none', label: Text('None', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'view', label: Text('View', style: TextStyle(fontSize: 11))),
                              ButtonSegment(value: 'edit', label: Text('Edit', style: TextStyle(fontSize: 11))),
                            ],
                            selected: {levels[key] ?? 'none'},
                            onSelectionChanged: full ? null : (v) => setSheet(() => levels[key] = v.first),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel'))),
                    const SizedBox(width: 12),
                    Expanded(child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save access'))),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved != true) return;
    await _call(() => ApiClient.instance.dio.post(ApiEndpoints.staffPermissions(s.id), data: full ? {'full': true} : {'permissions': levels}), 'Access saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AjAppBarTitle('Staff')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.person_add_alt_1_rounded)),
      body: _loading
          ? const AjLoadingIndicator()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                    itemCount: _staff.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final s = _staff[i];
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                                Text(s.isAdmin ? 'Administrator' : 'AJ Ops User', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.indigo.shade400)),
                              ]),
                              Text(s.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                              const SizedBox(height: 8),
                              Wrap(spacing: 8, runSpacing: 4, children: [
                                OutlinedButton(onPressed: () => _edit(s), child: const Text('Edit')),
                                if (!s.isAdmin) OutlinedButton(onPressed: () => _sections_(s), child: Text(s.permissions == null ? 'Sections · all' : 'Sections')),
                                if (!s.isAdmin)
                                  OutlinedButton(
                                    onPressed: () => _call(() => ApiClient.instance.dio.patch(ApiEndpoints.staffMember(s.id), data: {'ops_access': !s.opsAccess}), s.opsAccess ? 'Access revoked.' : 'Access granted.'),
                                    child: Text(s.opsAccess ? 'Revoke access' : 'Grant access', style: TextStyle(color: s.opsAccess ? Colors.red : Colors.green.shade700)),
                                  ),
                              ]),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ── Reception (front desk iPad keys) ───────────────────────────────────────

class ReceptionSettingsScreen extends StatefulWidget {
  const ReceptionSettingsScreen({super.key});

  @override
  State<ReceptionSettingsScreen> createState() => _ReceptionSettingsScreenState();
}

class _ReceptionSettingsScreenState extends State<ReceptionSettingsScreen> {
  List<Map<String, dynamic>> _devices = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final resp = await ApiClient.instance.dio.get(ApiEndpoints.receptionDevices);
      final list = ((resp.data as Map<String, dynamic>)['devices'] as List<dynamic>? ?? const []);
      setState(() { _devices = list.map((e) => e as Map<String, dynamic>).toList(); _loading = false; });
    } catch (e) {
      setState(() { _error = friendlyError(e); _loading = false; });
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New front desk iPad'),
        content: TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Name (e.g. Lobby iPad)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create key')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final resp = await ApiClient.instance.dio.post(ApiEndpoints.receptionDevices, data: {'name': name.text.trim()});
      final key = '${(resp.data as Map<String, dynamic>)['key'] ?? ''}';
      await _load();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Device key'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Shown once. Enter it on the iPad.', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            SelectableText(key, style: const TextStyle(fontFamily: 'Courier', fontSize: 15, fontWeight: FontWeight.w700)),
          ]),
          actions: [
            TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: key)); }, child: const Text('Copy')),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  Future<void> _revoke(Map<String, dynamic> d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Revoke ${d['name']}?'),
        content: const Text('That iPad stops working until it gets a new key.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Revoke')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiClient.instance.dio.post(ApiEndpoints.receptionDeviceRevoke('${d['id']}'), data: {});
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AjAppBarTitle('Reception')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add_rounded)),
      body: _loading
          ? const AjLoadingIndicator()
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _devices.isEmpty
                  ? const Center(child: Text('No front desk iPads yet. Tap + to create a key.'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                      itemCount: _devices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final d = _devices[i];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Colors.grey.shade200)),
                          child: ListTile(
                            title: Text('${d['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('Created ${d['created'] ?? ''}\nLast seen ${(d['last_seen'] ?? '').toString().isEmpty ? 'never' : d['last_seen']}', style: const TextStyle(fontSize: 12)),
                            isThreeLine: true,
                            trailing: TextButton(onPressed: () => _revoke(d), child: const Text('Revoke', style: TextStyle(color: Colors.red))),
                          ),
                        );
                      },
                    ),
    );
  }
}
