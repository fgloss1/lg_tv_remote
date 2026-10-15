import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import '../widgets/browser/browser.dart';

/// Built-in browser with a "Cast to TV" action.
///
/// On web the native webview is unavailable, so the tab degrades to a URL bar
/// plus an explanatory placeholder instead of instantiating a
/// `WebViewController` (which has no web implementation and crashed at runtime).
class WebCasterScreen extends StatefulWidget {
  const WebCasterScreen({super.key});

  @override
  State<WebCasterScreen> createState() => _WebCasterScreenState();
}

class _WebCasterScreenState extends State<WebCasterScreen> {
  static const String _defaultUrl = 'https://m.youtube.com';

  BrowserHandle? _browser;
  final TextEditingController _urlField = TextEditingController(text: _defaultUrl);

  bool _casting = false;
  bool _hasEmbeddedVideo = false;
  double _progress = 0;

  static const List<_SiteShortcut> _sites = <_SiteShortcut>[
    _SiteShortcut('YouTube', 'https://m.youtube.com', Icons.play_circle_fill),
    _SiteShortcut('Netflix', 'https://www.netflix.com', Icons.flash_on),
    _SiteShortcut('Prime Video', 'https://www.primevideo.com', Icons.movie),
    _SiteShortcut('Disney+', 'https://www.disneyplus.com', Icons.auto_awesome),
    _SiteShortcut('Twitch', 'https://m.twitch.tv', Icons.live_tv),
  ];

  @override
  void initState() {
    super.initState();
    // Safe on web: the placeholder handle implements the same surface.
    _browser = BrowserHandle(initialUrl: _defaultUrl);
  }

  @override
  void dispose() {
    _urlField.dispose();
    super.dispose();
  }

  Future<void> _detectVideo() async {
    final BrowserHandle? browser = _browser;
    if (browser == null) return;
    final int count = await browser.videoCount();
    if (mounted) setState(() => _hasEmbeddedVideo = count > 0);
  }

  void _navigate() {
    final String raw = _urlField.text.trim();
    if (raw.isEmpty) return;
    _browser?.load(raw);
  }

  void _reload() {
    setState(() => _progress = 0);
    _browser?.reload();
  }

  Future<void> _toggleCast() async {
    if (_casting) {
      setState(() => _casting = false);
      _toast('Stopped casting');
      return;
    }

    final TVService tv = context.read<TVService>();
    if (!tv.isConnected) {
      _toast('Connect to your LG TV from the Remote tab first', error: true);
      return;
    }

    final String url = _urlField.text.trim();
    if (url.isEmpty) return;

    try {
      await tv.playMedia(url, 'video');
      setState(() => _casting = true);
      _toast('Casting to TV — open the app on the television');
    } catch (e) {
      _toast('Cast failed: $e', error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? const Color(0xFF7F1D1D) : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final bool connected =
        context.select<TVService, bool>((TVService t) => t.isConnected);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F12),
      // A Column directly under a Stack receives unbounded height, which
      // triggers the RenderFlex assertion. Positioned.fill gives it bounded
      // constraints so the nested Expanded widgets resolve.
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Column(
              children: <Widget>[
                _browserArea(connected),
                _castBar(connected),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 108,
            child: _FloatingCastButton(
              casting: _casting,
              enabled: connected,
              detected: _hasEmbeddedVideo,
              onTap: _toggleCast,
            ),
          ),
        ],
      ),
    );
  }

  Widget _browserArea(bool connected) {
    return Expanded(
      child: Column(
        children: <Widget>[
          _urlBar(),
          const SizedBox(height: 8),
          _siteChips(),
          const SizedBox(height: 8),
          if (_progress < 1)
            const LinearProgressIndicator(
              backgroundColor: Colors.white10,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              minHeight: 2,
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: _browserSurface(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _urlBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 56, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _urlField,
              keyboardType: TextInputType.url,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search or type a URL',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF00E5FF), size: 20),
                filled: true,
                fillColor: const Color(0xFF1A1A20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
              onSubmitted: (_) => _navigate(),
            ),
          ),
          const SizedBox(width: 8),
          _RoundAction(
            icon: Icons.arrow_forward,
            accent: const Color(0xFF7C4DFF),
            onTap: _navigate,
          ),
          const SizedBox(width: 6),
          _RoundAction(
            icon: Icons.refresh,
            accent: const Color(0xFF00E5FF),
            onTap: _reload,
          ),
        ],
      ),
    );
  }

  Widget _siteChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _sites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final _SiteShortcut site = _sites[i];
          return _SiteChip(
            site: site,
            onTap: () {
              _urlField.text = site.url;
              _browser?.load(site.url);
            },
          );
        },
      ),
    );
  }

  Widget _browserSurface() {
    final BrowserHandle? browser = _browser;
    if (browser == null) return const SizedBox.shrink();

    if (kIsWeb) {
      // Explicit web branch: never touch the native webview controller.
      return browser.build(
        onProgress: (double _) {},
        onPageStarted: (String _) {},
        onPageFinished: (String _) {},
      );
    }

    return browser.build(
      onProgress: (double value) => setState(() => _progress = value),
      onPageStarted: (String url) => setState(() => _urlField.text = url),
      onPageFinished: (String _) => _detectVideo(),
    );
  }

  Widget _castBar(bool connected) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.cast_connected : Icons.cast,
            color: connected ? const Color(0xFF00E5FF) : Colors.white24,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              kIsWeb
                  ? 'Web preview — cast controls are disabled'
                  : _hasEmbeddedVideo
                      ? 'Video detected on this page'
                      : connected
                          ? 'No video detected yet — open a stream'
                          : 'TV not connected',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: _toggleCast,
            child: Text(
              _casting ? 'Stop' : 'Cast to TV',
              style: TextStyle(
                color: _casting ? Colors.redAccent : const Color(0xFF00E5FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- sub widgets

class _FloatingCastButton extends StatelessWidget {
  const _FloatingCastButton({
    required this.casting,
    required this.enabled,
    required this.detected,
    required this.onTap,
  });

  final bool casting;
  final bool enabled;
  final bool detected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = casting
        ? Colors.redAccent
        : detected
            ? const Color(0xFF00E5FF)
            : const Color(0xFF7C4DFF);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        elevation: 10,
        shadowColor: accent.withValues(alpha: 0.6),
        child: Ink(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[accent.withValues(alpha: 0.9), accent],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.55),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            customBorder: const CircleBorder(),
            child: Icon(
              casting ? Icons.stop_rounded : Icons.cast,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: accent.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
      ),
    );
  }
}

class _SiteChip extends StatelessWidget {
  const _SiteChip({required this.site, required this.onTap});

  final _SiteShortcut site;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const Color cyan = Color(0xFF00E5FF);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A20),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cyan.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: <Widget>[
              Icon(site.icon, color: cyan, size: 15),
              const SizedBox(width: 7),
              Text(
                site.label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteShortcut {
  const _SiteShortcut(this.label, this.url, this.icon);

  final String label;
  final String url;
  final IconData icon;
}