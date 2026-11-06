import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// "wozig.com", "https://wozig.com/" or a full API URL -> "https://wozig.com/wp-json/ajcore/v1".
String normalizeSiteUrl(String input) {
  var v = input.trim();
  if (v.isEmpty) throw const FormatException('Enter the site URL.');
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) v = 'https://$v';
  final uri = Uri.tryParse(v);
  if (uri == null || uri.host.isEmpty || (!uri.host.contains('.') && uri.host != 'localhost')) {
    throw const FormatException('That site URL is not valid.');
  }
  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (!path.endsWith('/wp-json/ajcore/v1')) path = '$path/wp-json/ajcore/v1';
  return '${uri.scheme}://${uri.authority}$path';
}

/// Host part of a stored API URL, for display ("wozig.com").
String siteHost(String apiUrl) {
  final host = Uri.tryParse(apiUrl)?.host ?? apiUrl;
  return host.replaceFirst(RegExp(r'^www\.'), '');
}

/// Bumping this rebuilds the whole provider tree, so nothing cached from one site is shown on another
/// (site switch, sign-out). Auth is restored from secure storage afterwards.
class SiteEpoch {
  SiteEpoch._();
  static final ValueNotifier<int> value = ValueNotifier<int>(0);
  static void bump() => value.value++;
}

class SiteScope extends StatelessWidget {
  final Widget child;
  const SiteScope({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SiteEpoch.value,
      builder: (_, epoch, _) => ProviderScope(key: ValueKey(epoch), child: child),
    );
  }
}
