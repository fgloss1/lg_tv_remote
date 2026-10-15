/// Web backend for the Web Caster tab.
///
/// `webview_flutter` has no web platform implementation, so the browser
/// surface is replaced by an informative placeholder. The URL bar above it
/// still works, which keeps the tab usable for previewing the layout.
library;

import 'package:flutter/material.dart';

bool get webviewSupported => false;

/// No-op handle with the same API as the native implementation.
class BrowserHandle {
  BrowserHandle({required String initialUrl}) : url = initialUrl;

  String url;

  /// The web build cannot evaluate JavaScript, so nothing is detected.
  Future<int> videoCount() async => 0;

  void load(String next) {
    final String trimmed = next.trim();
    if (trimmed.isEmpty) return;
    url = trimmed.startsWith('http') ? trimmed : 'https://$trimmed';
  }

  void reload() {}

  /// Builds the browser surface for this platform.
  Widget build({
    required ValueChanged<double> onProgress,
    required ValueChanged<String> onPageStarted,
    required ValueChanged<String> onPageFinished,
  }) {
    onProgress(1.0);
    onPageStarted(url);

    return Container(
      color: const Color(0xFF0F0F12),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
              border: Border.all(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.language,
              color: Color(0xFF00E5FF),
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Web Caster active on mobile devices',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The embedded browser uses the native webview, which is only '
            'available on Android and iOS. Build for a mobile device to browse '
            'and cast streams.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> dispose() async {}
}