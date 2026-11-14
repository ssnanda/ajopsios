import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// An email's HTML shown like a mail client does: no JavaScript, remote images allowed, links open in the browser.
class EmailHtmlView extends StatefulWidget {
  final String html;
  final double height;
  const EmailHtmlView({super.key, required this.html, this.height = 420});

  @override
  State<EmailHtmlView> createState() => _EmailHtmlViewState();
}

class _EmailHtmlViewState extends State<EmailHtmlView> {
  late final WebViewController _controller;

  static String _doc(String body) =>
      '<html><head><meta name="viewport" content="width=device-width, initial-scale=1">'
      '<meta http-equiv="Content-Security-Policy" content="default-src \'none\'; img-src https: data:; style-src \'unsafe-inline\'; font-src https: data:">'
      '<style>body{margin:10px;font:15px/1.45 -apple-system,Helvetica,Arial,sans-serif;color:#111;background:#fff;word-wrap:break-word}img{max-width:100%;height:auto}</style>'
      '</head><body>$body</body></html>';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (req) {
          if (req.url.startsWith('about:') || req.url.startsWith('data:')) return NavigationDecision.navigate;
          launchUrl(Uri.parse(req.url), mode: LaunchMode.externalApplication);
          return NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(_doc(widget.html));
  }

  @override
  void didUpdateWidget(covariant EmailHtmlView old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html) _controller.loadHtmlString(_doc(widget.html));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(height: widget.height, width: double.infinity, child: WebViewWidget(controller: _controller)),
    );
  }
}
