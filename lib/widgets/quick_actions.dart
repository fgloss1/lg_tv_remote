import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import 'device_picker.dart';
import 'tactile.dart';
import 'tv_feedback.dart';

/// Quick volume slider plus channel up/down buttons.
///
/// The rockers fire on touch down and repeat while held, matching the feel of a
/// physical remote.
class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    final bool connected = tv.isConnected;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'VOLUME',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                tv.muted ? 'MUTED' : '${(tv.volume * 100).round()}%',
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: const Color(0xFF00E5FF),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF00E5FF),
              overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            ),
            child: Slider(
              value: tv.volume,
              onChanged: connected ? tv.setVolume : null,
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: _ActionIcon(
                  icon: Icons.volume_down,
                  label: 'Vol -',
                  connected: connected,
                  // Reads tv.volume at call time, so holding the rocker ramps
                  // smoothly instead of replaying a stale step.
                  onPressed: () => dispatchToTv(
                    context,
                    tv,
                    (TVService t) => t.nudgeVolume(-0.05),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.volume_up,
                  label: 'Vol +',
                  connected: connected,
                  onPressed: () => dispatchToTv(
                    context,
                    tv,
                    (TVService t) => t.nudgeVolume(0.05),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.expand_more,
                  label: 'CH +',
                  accent: const Color(0xFF7C4DFF),
                  connected: connected,
                  onPressed: () =>
                      dispatchToTv(context, tv, (TVService t) => t.channelUp()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.expand_less,
                  label: 'CH -',
                  accent: const Color(0xFF7C4DFF),
                  connected: connected,
                  onPressed: () => dispatchToTv(
                    context,
                    tv,
                    (TVService t) => t.channelDown(),
                  ),
                ),
              ),
            ],
          ),
          if (!connected)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TactileButton(
                semanticLabel: 'Choose a TV',
                onPressed: () => showDevicePicker(context),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white.withValues(alpha: 0.06),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(Icons.link_off, color: Color(0xFF00E5FF), size: 15),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tap to pair a TV — keys send once connected',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.connected,
    required this.onPressed,
    this.accent = const Color(0xFF00E5FF),
  });

  final IconData icon;
  final String label;

  /// Only drives the dimmed styling, the tap target is always live.
  final bool connected;

  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: connected ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: label,
        repeatable: connected,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: <Widget>[
            Icon(icon, color: accent, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
