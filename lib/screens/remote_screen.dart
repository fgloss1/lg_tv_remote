import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import '../widgets/device_picker.dart';
import '../widgets/directional_pad.dart';
import '../widgets/on_screen_keyboard.dart';
import '../widgets/quick_actions.dart';
import '../widgets/tactile.dart';
import '../widgets/touchpad_area.dart';
import '../widgets/tv_feedback.dart';

/// Remote Control Screen - full featured LG webOS TV remote.
///
/// Every control is wired through [TactileButton] and [dispatchToTv], so a tap
/// always produces feedback. Buttons never hand `null` to `onTap`: when no TV
/// is attached they explain how to connect instead of silently ignoring you.
class RemoteControlScreen extends StatelessWidget {
  const RemoteControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();

    return CustomScrollView(
      slivers: <Widget>[
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF0F0F12),
          foregroundColor: Colors.white,
          title: const Text('LG TV Remote'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Choose a TV',
              onPressed: () => showDevicePicker(context),
              icon: const Icon(Icons.tv_outlined),
            ),
            IconButton(
              tooltip: 'Scan for TVs',
              onPressed: tv.isScanning ? null : tv.startDiscovery,
              icon: tv.isScanning
                  ? const SpinKitHourGlass(color: Color(0xFF00E5FF), size: 18)
                  : const Icon(Icons.wifi_find),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              const _DeviceStatusCard(),
              const SizedBox(height: 16),
              _PowerRow(tv: tv),
              const SizedBox(height: 16),
              const TouchpadArea(),
              const SizedBox(height: 20),
              const _DpadCluster(),
              const SizedBox(height: 20),
              const QuickActions(),
              const SizedBox(height: 20),
              const _MediaTransportRow(),
              const SizedBox(height: 16),
              const _SystemKeysRow(),
              const SizedBox(height: 20),
              const _AppLauncherGrid(),
              const SizedBox(height: 20),
              const OnScreenKeyboardButton(),
            ]),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- status card

class _DeviceStatusCard extends StatelessWidget {
  const _DeviceStatusCard();

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();

    final Color color;
    final String title;
    final String subtitle;

    switch (tv.state) {
      case TvConnectionState.connected:
        color = const Color(0xFF00E5FF);
        title = 'Connected to ${tv.device?.name ?? 'LG TV'}';
        subtitle = tv.device?.ip ?? '';
      case TvConnectionState.scanning:
        color = Colors.amberAccent;
        title = 'Searching for LG TVs...';
        subtitle = tv.devices.isEmpty
            ? 'Make sure the TV is on the same Wi-Fi network'
            : '${tv.devices.length} device(s) found';
      case TvConnectionState.pairing:
        color = Colors.amberAccent;
        title = 'Pairing with TV...';
        subtitle = 'Accept the request on the TV screen';
      case TvConnectionState.error:
        color = Colors.redAccent;
        title = 'Connection problem';
        subtitle = tv.error ?? 'Unknown error';
      case TvConnectionState.disconnected:
        color = Colors.redAccent;
        title = 'No LG TV connected';
        subtitle = tv.devices.isEmpty
            ? 'Tap scan to search the network'
            : '${tv.devices.length} TV(s) found — tap to choose one';
    }

    return TactileButton(
      semanticLabel: 'Connection status. Tap to choose a TV',
      onPressed: () => showDevicePicker(context),
      borderRadius: BorderRadius.circular(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            color.withValues(alpha: 0.16),
            const Color(0xFF1A1A20),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          _PulsingDot(
            color: color,
            animate: tv.state == TvConnectionState.scanning,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          _GlassPill(
            label: tv.isScanning ? 'Scanning' : 'Scan',
            icon: Icons.radar,
            onPressed: tv.isScanning ? null : tv.startDiscovery,
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, required this.animate});

  final Color color;
  final bool animate;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? _) {
        final double scale = 0.72 + (_controller.value * 0.38);
        return Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.28 * scale),
            border: Border.all(color: widget.color, width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55 * scale),
                blurRadius: 12,
                spreadRadius: 2 * scale,
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------- power / mute

class _PowerRow extends StatelessWidget {
  const _PowerRow({required this.tv});

  final TVService tv;

  @override
  Widget build(BuildContext context) {
    final bool connected = tv.isConnected;

    return Row(
      children: <Widget>[
        Expanded(
          child: _GlassActionButton(
            icon: tv.isPowered ? Icons.power_settings_new : Icons.power_off,
            label: tv.isPowered ? 'Power' : 'Standby',
            accent: const Color(0xFF7C4DFF),
            connected: connected,
            strength: HapticStrength.medium,
            onPressed: () =>
                dispatchToTv(context, tv, (TVService t) => t.togglePower()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassActionButton(
            icon: tv.muted ? Icons.volume_off : Icons.volume_up,
            label: tv.muted ? 'Unmute' : 'Mute',
            accent: const Color(0xFF00E5FF),
            connected: connected,
            onPressed: () =>
                dispatchToTv(context, tv, (TVService t) => t.toggleMute()),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassActionButton(
            icon: Icons.arrow_back,
            label: 'Back',
            accent: const Color(0xFF00E5FF),
            connected: connected,
            onPressed: () =>
                dispatchToTv(context, tv, (TVService t) => t.pressBack()),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------- d-pad

class _DpadCluster extends StatelessWidget {
  const _DpadCluster();

  @override
  Widget build(BuildContext context) {
    // `watch` matters here: the cluster is mounted once as a const widget, so a
    // `read` would freeze the disabled state for the lifetime of the screen.
    final TVService tv = context.watch<TVService>();
    final bool connected = tv.isConnected;

    Widget key(IconData icon, String label, void Function(TVService tv) command) {
      return DirectionalPad(
        icon: icon,
        label: label,
        enabled: connected,
        onPressed: () => dispatchToTv(context, tv, command),
      );
    }

    // A hard width cap guarantees the cluster is laid out with bounded
    // constraints, so the centred Row can never be handed an unbounded width.
    return Center(
      child: SizedBox(
        width: 268,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            key(
              Icons.keyboard_arrow_up,
              'Up',
              (TVService t) => t.pressUp(),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                key(
                  Icons.keyboard_arrow_left,
                  'Left',
                  (TVService t) => t.pressLeft(),
                ),
                const SizedBox(width: 10),
                _OkButton(
                  enabled: connected,
                  onPressed: () =>
                      dispatchToTv(context, tv, (TVService t) => t.pressEnter()),
                ),
                const SizedBox(width: 10),
                key(
                  Icons.keyboard_arrow_right,
                  'Right',
                  (TVService t) => t.pressRight(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            key(
              Icons.keyboard_arrow_down,
              'Down',
              (TVService t) => t.pressDown(),
            ),
          ],
        ),
      ),
    );
  }
}

class _OkButton extends StatelessWidget {
  const _OkButton({required this.onPressed, required this.enabled});

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const Color violet = Color(0xFF7C4DFF);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: 'OK button',
        strength: HapticStrength.medium,
        pressScale: 0.9,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(36),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF9B7BFF), violet],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: violet.withValues(alpha: 0.55),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: const SizedBox(
          width: 72,
          height: 72,
          child: Center(
            child: Text(
              'OK',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------- media transport

class _MediaTransportRow extends StatelessWidget {
  const _MediaTransportRow();

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    final bool connected = tv.isConnected;

    Widget key(IconData icon, String label, String command) {
      return Expanded(
        child: _GlassActionButton(
          icon: icon,
          label: label,
          accent: const Color(0xFF00E5FF),
          connected: connected,
          compact: true,
          onPressed: () => dispatchToTv(
            context,
            tv,
            (TVService t) => t.sendKey(command),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionLabel('PLAYBACK'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              key(Icons.fast_rewind, 'Rewind', 'REWIND'),
              const SizedBox(width: 8),
              key(Icons.play_arrow, 'Play', 'PLAY'),
              const SizedBox(width: 8),
              key(Icons.pause, 'Pause', 'PAUSE'),
              const SizedBox(width: 8),
              key(Icons.fast_forward, 'Forward', 'FASTFORWARD'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SystemKeysRow extends StatelessWidget {
  const _SystemKeysRow();

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    final bool connected = tv.isConnected;

    Widget key(IconData icon, String label, String command) {
      return Expanded(
        child: _GlassActionButton(
          icon: icon,
          label: label,
          accent: const Color(0xFF7C4DFF),
          connected: connected,
          compact: true,
          onPressed: () => dispatchToTv(
            context,
            tv,
            (TVService t) => t.sendKey(command),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7C4DFF).withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const _SectionLabel('TV SYSTEM KEYS'),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              key(Icons.live_tv, 'Guide', 'GUIDE'),
              const SizedBox(width: 8),
              key(Icons.info_outline, 'Info', 'INFO'),
              const SizedBox(width: 8),
              key(Icons.home_outlined, 'Home', 'DASHBOARD'),
              const SizedBox(width: 8),
              key(Icons.exit_to_app, 'Exit', 'EXIT'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// --------------------------------------------------------------- app launch

class _AppLauncherGrid extends StatelessWidget {
  const _AppLauncherGrid();

  static const Map<String, IconData> _icons = <String, IconData>{
    'YouTube': Icons.play_circle_fill,
    'Netflix': Icons.flash_on,
    'Prime Video': Icons.local_movies,
    'Disney+': Icons.auto_awesome,
    'Browser': Icons.language,
  };

  static const Map<String, Color> _colors = <String, Color>{
    'YouTube': Color(0xFFFF0000),
    'Netflix': Color(0xFFE50914),
    'Prime Video': Color(0xFF00A8E1),
    'Disney+': Color(0xFF7C4DFF),
    'Browser': Color(0xFF00E5FF),
  };

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    final List<String> names = TVService.appIds.keys.toList();
    final bool connected = tv.isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF7C4DFF).withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'QUICK LAUNCH',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: names.map((String name) {
              final Color color = _colors[name] ?? const Color(0xFF00E5FF);
              return _AppChip(
                name: name,
                icon: _icons[name] ?? Icons.apps,
                color: color,
                connected: connected,
                onPressed: () => dispatchToTv(
                  context,
                  tv,
                  (TVService t) => t.launchApp(name),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _AppChip extends StatelessWidget {
  const _AppChip({
    required this.name,
    required this.icon,
    required this.color,
    required this.connected,
    required this.onPressed,
  });

  final String name;
  final IconData icon;
  final Color color;
  final bool connected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: connected ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: 'Launch $name',
        strength: HapticStrength.medium,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: color, size: 26),
              const SizedBox(height: 8),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- glass pieces

class _GlassActionButton extends StatelessWidget {
  const _GlassActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.connected,
    required this.onPressed,
    this.compact = false,
    this.strength = HapticStrength.light,
  });

  final IconData icon;
  final String label;
  final Color accent;

  /// Only drives the dimmed styling: the tap target is always live.
  final bool connected;

  final VoidCallback onPressed;
  final bool compact;
  final HapticStrength strength;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: connected ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: label,
        strength: strength,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: accent.withValues(alpha: 0.14),
          border: Border.all(color: accent.withValues(alpha: 0.4)),
        ),
        padding: EdgeInsets.symmetric(vertical: compact ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: accent, size: compact ? 20 : 24),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;

  /// `null` only while a scan is already running.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: TactileButton(
        semanticLabel: label,
        onPressed: onPressed ?? () {},
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, color: const Color(0xFF00E5FF), size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
