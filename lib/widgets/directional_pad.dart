import 'package:flutter/material.dart';

/// A single tactile D-pad key button.
class DirectionalPad extends StatelessWidget {
  const DirectionalPad({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 56,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  static const Color accent = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1A1A20),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}