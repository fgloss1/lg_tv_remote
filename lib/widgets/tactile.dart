import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Strength of the haptic pulse played when a control is activated.
enum HapticStrength {
  /// Subtle tick, used for lists, chips and small keys.
  selection,

  /// Default press feedback for regular buttons.
  light,

  /// Used for primary actions such as power, OK or launching an app.
  medium,

  /// Reserved for destructive or high impact confirmations.
  heavy,
}

/// Fires a haptic pulse. Safe on every platform, including web where the
/// platform channel is a no-op.
void triggerHaptic([HapticStrength strength = HapticStrength.light]) {
  switch (strength) {
    case HapticStrength.selection:
      unawaited(HapticFeedback.selectionClick());
      break;
    case HapticStrength.light:
      unawaited(HapticFeedback.lightImpact());
      break;
    case HapticStrength.medium:
      unawaited(HapticFeedback.mediumImpact());
      break;
    case HapticStrength.heavy:
      unawaited(HapticFeedback.heavyImpact());
      break;
  }
}

/// A button that always reacts to taps.
///
/// Every control in the app is built on top of this widget so a press gives
/// three pieces of feedback at once: a scale down animation, a ripple and a
/// haptic pulse. [onPressed] is required and never nullable on purpose —
/// controls that need a TV connection decide inside their callback how to
/// report the missing connection, instead of silently swallowing the tap.
class TactileButton extends StatefulWidget {
  const TactileButton({
    required this.onPressed,
    required this.child,
    this.padding,
    this.decoration,
    this.color,
    this.borderRadius = BorderRadius.zero,
    this.onLongPress,
    this.semanticLabel,
    this.strength = HapticStrength.light,
    this.pressScale = 0.94,
    this.haptics = true,
    this.repeatable = false,
    super.key,
  });

  final VoidCallback onPressed;
  final VoidCallback? onLongPress;

  /// Visual content of the button.
  final Widget child;

  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final Color? color;
  final BorderRadius borderRadius;
  final String? semanticLabel;

  /// Haptic strength used when the button fires.
  final HapticStrength strength;

  /// Disable only to opt out of the vibration motor.
  final bool haptics;

  /// Hold to repeat, used by volume and channel keys.
  ///
  /// The command fires on touch down and then repeats until release, which is
  /// how a real remote behaves when you hold a rocker key.
  final bool repeatable;

  /// Delay before the held key starts repeating.
  static const Duration repeatDelay = Duration(milliseconds: 320);

  /// Interval between repeats once the key is held.
  static const Duration repeatInterval = Duration(milliseconds: 110);

  /// How far the button shrinks while held.
  final double pressScale;

  @override
  State<TactileButton> createState() => _TactileButtonState();
}

class _TactileButtonState extends State<TactileButton> {
  bool _pressed = false;
  bool _firedEarly = false;
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  void _activate() {
    if (widget.haptics) triggerHaptic(widget.strength);
    widget.onPressed();
  }

  void _activateRepeat() {
    // Repeats stay silent so the vibration motor is not hammered 9x a second.
    widget.onPressed();
  }

  void _onTapDown(TapDownDetails _) {
    _setPressed(true);
    if (!widget.repeatable) return;

    _firedEarly = true;
    _activate();
    _repeatTimer?.cancel();
    _repeatTimer = Timer(TactileButton.repeatDelay, () {
      _repeatTimer = Timer.periodic(
        TactileButton.repeatInterval,
        (_) => _activateRepeat(),
      );
    });
  }

  void _onTapUp(TapUpDetails _) {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _setPressed(false);
  }

  void _onTapCancel() {
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _firedEarly = false;
    _setPressed(false);
  }

  void _onTap() {
    final bool alreadyFired = _firedEarly;
    _firedEarly = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    if (alreadyFired) return;
    _activate();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: true,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? widget.pressScale : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          type: MaterialType.transparency,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onTap: _onTap,
            onLongPress: widget.onLongPress,
            borderRadius: widget.borderRadius,
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Ink(
              decoration: widget.decoration,
              color: widget.color,
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
