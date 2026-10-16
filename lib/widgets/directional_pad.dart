import 'package:flutter/material.dart';

import 'tactile.dart';

/// A single tactile D-pad key button.
///
/// [onPressed] is required: the key stays tappable when no TV is attached and
/// the caller decides how to surface that, instead of becoming a dead target.
class DirectionalPad extends StatelessWidget {
  const DirectionalPad({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.enabled = true,
    this.size = 56,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Only affects the dimmed styling, never the tap target.
  final bool enabled;

  final double size;

  static const Color accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: label,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: const Color(0xFF1A1A20),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, color: accent, size: 28),
        ),
      ),
    );
  }
}
