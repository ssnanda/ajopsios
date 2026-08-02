import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _items = [
    (label: 'Customers', icon: Icons.people_alt_rounded, path: '/customers'),
    (label: 'Leads', icon: Icons.person_search_rounded, path: '/leads'),
    (label: 'UPOS Temps', icon: Icons.thermostat_rounded, path: '/upos-temps'),
    (label: 'Mail', icon: Icons.mail_outline_rounded, path: '/mail'),
    (label: 'Files', icon: Icons.folder_outlined, path: '/files'),
    (label: 'Gmail Intake', icon: Icons.move_to_inbox_rounded, path: '/gmail-intake'),
    (label: 'AJPhone', icon: Icons.phone_in_talk_rounded, path: '/ajphone'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView.separated(
        itemCount: _items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final item = _items[i];
          return ListTile(
            leading: Icon(item.icon),
            title: Text(item.label),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(item.path),
          );
        },
      ),
    );
  }
}
