/// Native backend for the Web Caster tab, backed by webview_flutter.
library;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

bool get webviewSupported => true;

/// Wraps the platform webview behind the shared [BrowserHandle] API.
class BrowserHandle {
  BrowserHandle({required String initialUrl}) : url = initialUrl {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F0F12))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int value) => _progress(value / 100),
          onPageStarted: (String value) {
            url = value;
            _started(value);
          },
          onPageFinished: (String value) {
            url = value;
            _finished(value);
          },
        ),
      )
      ..loadRequest(Uri.parse(initialUrl));
  }

  String url;
  late final WebViewController _controller;

  ValueChanged<double> _progress = _noop;
  ValueChanged<String> _started = _noopString;
  ValueChanged<String> _finished = _noopString;

  static void _noop(double _) {}
  static void _noopString(String _) {}

  /// Counts embedded `<video>` elements so the cast button can be offered.
  Future<int> videoCount() async {
    try {
      final Object raw = await _controller.runJavaScriptReturningResult(
        'document.querySelectorAll("video").length',
      );
      return int.tryParse('$raw') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  void load(String next) {
    final String trimmed = next.trim();
    if (trimmed.isEmpty) return;
    final Uri? parsed = trimmed.startsWith('http')
        ? Uri.tryParse(trimmed)
        : Uri.tryParse('https://$trimmed');
    if (parsed == null) return;
    url = trimmed;
    _controller.loadRequest(parsed);
  }

  void reload() => _controller.reload();

  Widget build({
    required ValueChanged<double> onProgress,
    required ValueChanged<String> onPageStarted,
    required ValueChanged<String> onPageFinished,
  }) {
    _progress = onProgress;
    _started = onPageStarted;
    _finished = onPageFinished;
    return WebViewWidget(controller: _controller);
  }

  Future<void> dispose() async {
    // The platform view is released when the widget is detached.
  }
}