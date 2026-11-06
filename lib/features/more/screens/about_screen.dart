import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static final _site = Uri.parse('https://itspector.com');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          return ListView(
            children: [
              const SizedBox(height: 24),
              const Center(child: Icon(Icons.business_center_rounded, size: 56)),
              const SizedBox(height: 12),
              Center(child: Text('AJ Ops', style: Theme.of(context).textTheme.headlineSmall)),
              const SizedBox(height: 4),
              Center(child: Text('by IT Spector LLC', style: TextStyle(color: Colors.grey.shade600))),
              const SizedBox(height: 24),
              const Divider(height: 1),
              ListTile(title: const Text('Version'), trailing: Text(info?.version ?? '…')),
              ListTile(title: const Text('Build'), trailing: Text(info?.buildNumber ?? '…')),
              ListTile(title: const Text('App ID'), trailing: Text(info?.packageName ?? '…')),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('itspector.com'),
                onTap: () => launchUrl(_site, mode: LaunchMode.externalApplication),
              ),
            ],
          );
        },
      ),
    );
  }
}
