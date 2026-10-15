import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';

/// Quick volume slider plus channel up/down buttons.
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
                '${(tv.volume * 100).round()}%',
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
                  onPressed: connected ? () => tv.setVolume(tv.volume - 0.05) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.volume_up,
                  label: 'Vol +',
                  onPressed: connected ? () => tv.setVolume(tv.volume + 0.05) : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.expand_more,
                  label: 'CH +',
                  accent: const Color(0xFF7C4DFF),
                  onPressed: connected ? tv.channelUp : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionIcon(
                  icon: Icons.expand_less,
                  label: 'CH -',
                  accent: const Color(0xFF7C4DFF),
                  onPressed: connected ? tv.channelDown : null,
                ),
              ),
            ],
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
    required this.onPressed,
    this.accent = const Color(0xFF00E5FF),
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
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
        ),
      ),
    );
  }
}