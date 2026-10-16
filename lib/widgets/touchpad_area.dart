import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import 'device_picker.dart';
import 'tactile.dart';

/// Air-mouse / touchpad surface.
///
/// Swipes move the on-screen pointer, a tap sends a click, and a long press
/// behaves like a right click.
///
/// A tap is only forwarded when the finger barely moved, so dragging the
/// pointer no longer fires a stray click on the television.
class TouchpadArea extends StatefulWidget {
  const TouchpadArea({super.key});

  @override
  State<TouchpadArea> createState() => _TouchpadAreaState();
}

class _TouchpadAreaState extends State<TouchpadArea> {
  /// Movement below this many pixels still counts as a tap.
  static const double _tapSlop = 14;

  Offset? _lastPointer;
  Offset _cursor = Offset.zero;
  double _travel = 0;
  bool _pointerDown = false;
  bool _engaged = false;

  void _onPointerDown(PointerDownEvent event) {
    setState(() {
      _lastPointer = event.position;
      _pointerDown = true;
      _engaged = true;
      _travel = 0;
    });
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_lastPointer == null) return;

    final Offset delta = event.position - _lastPointer!;
    _lastPointer = event.position;
    _travel += delta.distance;

    // Scale to a sensible remote-control speed.
    final Offset scaled = delta * 1.6;

    setState(() {
      _cursor = _cursor + scaled;
    });

    context.read<TVService>().pointerMove(scaled.dx, scaled.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    final bool wasTap = _travel <= _tapSlop;
    setState(() {
      _lastPointer = null;
      _pointerDown = false;
    });

    if (!wasTap) return;

    final TVService tv = context.read<TVService>();
    triggerHaptic(HapticStrength.light);
    if (tv.isConnected) {
      tv.pointerClick();
      return;
    }

    // Offline a tap still answers: it points at the device picker.
    _reportOffline();
  }

  void _onLongPress() {
    // Right click / context menu on most LG apps.
    triggerHaptic(HapticStrength.medium);
    _dispatch((TVService tv) => tv.sendKey('MENU'));
  }

  void _recenter() {
    triggerHaptic(HapticStrength.light);
    setState(() {
      _cursor = Offset.zero;
      _lastPointer = null;
    });
    _reportOffline();
  }

  /// Runs [action] against the TV, or explains how to connect when offline.
  void _dispatch(void Function(TVService tv) action) {
    final TVService tv = context.read<TVService>();
    if (tv.isConnected) {
      action(tv);
      return;
    }
    _reportOffline();
  }

  /// Offline taps still answer: they point at the device picker.
  void _reportOffline() {
    final TVService tv = context.read<TVService>();
    if (tv.isConnected) return;
    triggerHaptic(HapticStrength.medium);
    showDevicePicker(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = context.select<TVService, bool>((TVService t) => t.isConnected);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF16161C), Color(0xFF0F0F12)],
        ),
        border: Border.all(
          color: (connected ? const Color(0xFF00E5FF) : Colors.white12).withValues(alpha: 0.4),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: <Widget>[
            // Grid backdrop so movement is visible.
            Positioned.fill(
              child: CustomPaint(painter: _GridPainter(active: _pointerDown)),
            ),

            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: (_) => setState(() {
                _lastPointer = null;
                _pointerDown = false;
              }),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPress: _onLongPress,
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    children: <Widget>[
                      // Cursor hint
                      Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_pointerDown ? const Color(0xFF00E5FF) : Colors.white24)
                                .withValues(alpha: 0.6),
                            border: Border.all(
                              color: const Color(0xFF00E5FF),
                              width: 1.5,
                            ),
                            boxShadow: _pointerDown
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            connected
                                ? 'Swipe to move cursor • Tap to select'
                                : 'Not connected — tap to pick a TV',
                            style: TextStyle(
                              color: connected ? Colors.white38 : Colors.white24,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              top: 8,
              right: 8,
              child: _MiniButton(
                icon: connected ? Icons.my_location : Icons.link,
                onTap: _recenter,
                tooltip: connected ? 'Recenter' : 'Choose a TV',
              ),
            ),

            if (!_engaged)
              const Positioned.fill(
                child: Center(
                  child: Icon(Icons.mouse, size: 30, color: Colors.white12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: TactileButton(
        semanticLabel: tooltip,
        onPressed: onTap,
        borderRadius: BorderRadius.circular(24),
        color: Colors.white.withValues(alpha: 0.06),
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: const Color(0xFF00E5FF)),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({required this.active});

  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = (active ? const Color(0xFF00E5FF) : Colors.white)
          .withValues(alpha: active ? 0.10 : 0.04)
      ..strokeWidth = 1;

    const double step = 26;
    for (double x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.active != active;
}
