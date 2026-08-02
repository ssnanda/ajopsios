import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Reads the actual bundled version/build from the native app package
/// (Info.plist on iOS) rather than a hand-maintained constant, so it can
/// never drift from what's really installed regardless of which build
/// script (build-ipa.sh / device-run.sh / sim-*.sh) produced it.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) return const SizedBox.shrink();
        return Text(
          'v${info.version}+${info.buildNumber}',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
        );
      },
    );
  }
}
