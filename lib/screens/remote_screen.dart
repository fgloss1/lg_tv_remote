import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import '../widgets/touchpad_area.dart';
import '../widgets/directional_pad.dart';
import '../widgets/quick_actions.dart';
import '../widgets/on_screen_keyboard.dart';

/// Remote Control Screen - full featured LG webOS TV remote.
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
        subtitle = 'Tap scan to search the network';
    }

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: <Widget>[
          _PulsingDot(color: color, animate: tv.state == TvConnectionState.scanning),
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
                Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
          if (!tv.isConnected)
            _GlassPill(
              label: tv.isScanning ? 'Scanning' : 'Scan',
              icon: Icons.radar,
              onTap: tv.isScanning ? null : tv.startDiscovery,
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
    return Row(
      children: <Widget>[
        Expanded(
          child: _GlassActionButton(
            icon: Icons.power_settings_new,
            label: 'Power',
            accent: const Color(0xFF7C4DFF),
            onTap: tv.isConnected ? tv.togglePower : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassActionButton(
            icon: tv.muted ? Icons.volume_off : Icons.volume_up,
            label: tv.muted ? 'Unmute' : 'Mute',
            accent: const Color(0xFF00E5FF),
            onTap: tv.isConnected ? tv.toggleMute : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _GlassActionButton(
            icon: Icons.arrow_back,
            label: 'Back',
            accent: const Color(0xFF00E5FF),
            onTap: tv.isConnected ? tv.pressBack : null,
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
    final TVService tv = context.read<TVService>();

    Widget key(IconData icon, String label, VoidCallback? onTap) {
      return DirectionalPad(
        icon: icon,
        label: label,
        onPressed: onTap,
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
            key(Icons.keyboard_arrow_up, 'Up', tv.isConnected ? tv.pressUp : null),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                key(Icons.keyboard_arrow_left, 'Left',
                    tv.isConnected ? tv.pressLeft : null),
                const SizedBox(width: 10),
                _OkButton(onTap: tv.isConnected ? tv.pressEnter : null),
                const SizedBox(width: 10),
                key(Icons.keyboard_arrow_right, 'Right',
                    tv.isConnected ? tv.pressRight : null),
              ],
            ),
            const SizedBox(height: 10),
            key(Icons.keyboard_arrow_down, 'Down',
                tv.isConnected ? tv.pressDown : null),
          ],
        ),
      ),
    );
  }
}

class _OkButton extends StatelessWidget {
  const _OkButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const Color violet = Color(0xFF7C4DFF);
    final bool enabled = onTap != null;

    return Semantics(
      button: true,
      label: 'OK button',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 72,
            height: 72,
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
            child: const Center(
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
                onTap: tv.isConnected ? () => tv.launchApp(name) : null,
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
    required this.onTap,
  });

  final String name;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            width: 96,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
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
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: accent.withValues(alpha: 0.14),
              border: Border.all(color: accent.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: <Widget>[
                Icon(icon, color: accent, size: 24),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
        ),
      ),
    );
  }
}
