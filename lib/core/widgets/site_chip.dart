import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/site_url.dart';
import '../storage/secure_storage.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Page title with "username @ site" beside it. Tap: pick a site. Double-tap: jump to the other site.
class AjAppBarTitle extends StatelessWidget {
  final String title;
  const AjAppBarTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Flexible(flex: 3, child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
      const SizedBox(width: 10),
      const Flexible(flex: 4, child: SiteChip()),
    ]);
  }
}

class SiteChip extends ConsumerStatefulWidget {
  const SiteChip({super.key});

  @override
  ConsumerState<SiteChip> createState() => _SiteChipState();
}

class _SiteChipState extends ConsumerState<SiteChip> {
  String _site = '';

  @override
  void initState() {
    super.initState();
    SecureStorage.instance.getSiteUrl().then((v) {
      if (mounted && v != null) setState(() => _site = v);
    });
  }

  Future<List<SavedAccount>> _sites() async => (await SecureStorage.instance.getSavedAccounts()).where((a) => a.siteUrl.isNotEmpty).toList();

  /// Double-tap: next saved site after the active one (wraps around). With only one site, says so.
  Future<void> _switchToOther() async {
    final sites = await _sites();
    if (!mounted) return;
    if (sites.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only one site is signed in. Use More > Add another site.')));
      return;
    }
    final i = sites.indexWhere((a) => a.siteUrl == _site);
    final next = sites[(i + 1) % sites.length];
    await ref.read(authProvider.notifier).switchToAccount(next.id);
  }

  Future<void> _openPicker() async {
    final sites = await _sites();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.all(14), child: Text('Switch site', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
          for (final a in sites)
            ListTile(
              leading: Icon(a.siteUrl == _site ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
              title: Text(siteHost(a.siteUrl)),
              subtitle: Text(a.displayName.isNotEmpty ? a.displayName : a.username),
              onTap: a.siteUrl == _site
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await ref.read(authProvider.notifier).switchToAccount(a.id);
                    },
            ),
          ListTile(
            leading: const Icon(Icons.add_rounded),
            title: const Text('Add another site'),
            onTap: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final who = user == null ? '' : (user.username.isNotEmpty ? user.username : user.displayName);
    final host = _site.isEmpty ? '' : siteHost(_site);
    if (who.isEmpty && host.isEmpty) return const SizedBox.shrink();
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPicker,
      onDoubleTap: _switchToOther,
      child: Text(
        '$who @ $host',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color, decoration: TextDecoration.underline, decorationColor: color.withValues(alpha: 0.5)),
      ),
    );
  }
}
