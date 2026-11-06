import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/site_url.dart';
import '../../../core/providers/modules_provider.dart';
import '../../../core/storage/secure_storage.dart';
import '../../auth/providers/auth_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  // module = the route key the site must offer (null = always shown).
  static const _items = [
    (label: 'Customers', icon: Icons.people_alt_rounded, path: '/customers', module: 'customers'),
    (label: 'Leads', icon: Icons.person_search_rounded, path: '/leads', module: 'leads'),
    (label: 'Mail', icon: Icons.mail_outline_rounded, path: '/mail', module: 'mail'),
    (label: 'Files', icon: Icons.folder_outlined, path: '/files', module: 'files'),
    (label: 'Gmail Intake', icon: Icons.move_to_inbox_rounded, path: '/gmail-intake', module: 'gmail-intake'),
    (label: 'AJPhone', icon: Icons.phone_in_talk_rounded, path: '/ajphone', module: 'ajphone'),
    (label: 'About', icon: Icons.info_outline_rounded, path: '/about', module: null),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(modulesProvider).value;
    final items = _items.where((i) => i.module == null || modules == null || modules.contains(i.module)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          const _SitesSection(),
          const Divider(height: 1),
          for (final item in items) ...[
            ListTile(
              leading: Icon(item.icon),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(item.path),
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

/// Saved site logins: tap to switch, or sign in to another site.
class _SitesSection extends ConsumerWidget {
  const _SitesSection();

  Future<(List<SavedAccount>, String?)> _load() async =>
      (await SecureStorage.instance.getSavedAccounts(), await SecureStorage.instance.getSiteUrl());

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<(List<SavedAccount>, String?)>(
      future: _load(),
      builder: (context, snap) {
        final accounts = snap.data?.$1 ?? const <SavedAccount>[];
        final active = snap.data?.$2;
        final sites = accounts.where((a) => a.siteUrl.isNotEmpty).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('Sites', style: Theme.of(context).textTheme.labelLarge),
            ),
            for (final a in sites)
              ListTile(
                leading: Icon(a.siteUrl == active ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded),
                title: Text(siteHost(a.siteUrl)),
                subtitle: Text(a.displayName.isNotEmpty ? a.displayName : a.username),
                onTap: a.siteUrl == active
                    ? null
                    : () async {
                        final ok = await ref.read(authProvider.notifier).switchToAccount(a.id);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Session expired. Sign in again.')),
                          );
                        }
                      },
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: const Text('Add another site'),
              subtitle: const Text('Signs out of this one; it stays in the list'),
              onTap: () => ref.read(authProvider.notifier).logout(),
            ),
          ],
        );
      },
    );
  }
}
