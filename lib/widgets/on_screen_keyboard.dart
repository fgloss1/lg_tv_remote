import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import 'tactile.dart';
import 'tv_feedback.dart';

/// On-screen remote keyboard. Every key press is forwarded to the TV over the
/// webOS control socket so text can be typed in search boxes and forms.
///
/// The keyboard always opens and always echoes the text locally; when no TV is
/// attached the keys simply report the missing connection instead of going
/// nowhere.
class OnScreenKeyboardButton extends StatefulWidget {
  const OnScreenKeyboardButton({super.key});

  @override
  State<OnScreenKeyboardButton> createState() => _OnScreenKeyboardButtonState();
}

class _OnScreenKeyboardButtonState extends State<OnScreenKeyboardButton> {
  bool _expanded = false;
  String _buffer = '';

  static const List<List<String>> _rows = <List<String>>[
    <String>['ESC', 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7'],
    <String>['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
    <String>['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
    <String>['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
    <String>['Z', 'X', 'C', 'V', 'B', 'N', 'M', '.', ',', '-'],
  ];

  /// Maps a printed character to its webOS remote key name.
  static const Map<String, String> _charKeys = <String, String>{
    '.': 'ASTERISK',
    ',': 'ASTERISK',
    '-': 'ASTERISK',
    ' ': 'SPACE',
  };

  void _press(String label) {
    final TVService tv = context.read<TVService>();

    if (label == 'ESC') {
      // Local echo first, then the remote command.
      setState(() => _buffer = '');
      dispatchToTv(context, tv, (TVService t) => t.pressBack());
      return;
    }

    if (label == 'DEL') {
      setState(() {
        if (_buffer.isNotEmpty) {
          _buffer = _buffer.substring(0, _buffer.length - 1);
        }
      });
      dispatchToTv(context, tv, (TVService t) => t.sendKey('BACKSPACE'));
      return;
    }

    setState(() => _buffer += label);
    dispatchToTv(
      context,
      tv,
      (TVService t) => t.sendKey(_charKeys[label] ?? label),
    );
  }

  Future<void> _sendAll() async {
    final TVService tv = context.read<TVService>();
    if (_buffer.isEmpty) return;

    if (!tv.isConnected) {
      reportNotConnected(context, tv);
      return;
    }

    await tv.sendText(_buffer);
    if (mounted) setState(() => _buffer = '');
  }

  void _clear() {
    setState(() => _buffer = '');
  }

  @override
  Widget build(BuildContext context) {
    final bool connected = context.select<TVService, bool>((TVService t) => t.isConnected);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: const Color(0xFF1A1A20),
        border: Border.all(
          color: (connected ? const Color(0xFF00E5FF) : Colors.white12).withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        children: <Widget>[
          _header(connected),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _keyboard(connected),
          ),
        ],
      ),
    );
  }

  Widget _header(bool connected) {
    return TactileButton(
      semanticLabel: 'Toggle on-screen keyboard',
      onPressed: () => setState(() => _expanded = !_expanded),
      borderRadius: BorderRadius.circular(18),
      color: Colors.white.withValues(alpha: 0.03),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.keyboard,
            size: 22,
            color: connected ? const Color(0xFF00E5FF) : Colors.white38,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'On-screen keyboard',
              style: TextStyle(
                color: connected ? Colors.white : Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_buffer.isNotEmpty)
            TactileButton(
              semanticLabel: 'Clear typed text',
              onPressed: _clear,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          const SizedBox(width: 6),
          Icon(
            _expanded ? Icons.expand_less : Icons.expand_more,
            color: connected ? Colors.white38 : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _keyboard(bool connected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      child: Column(
        children: <Widget>[
          if (_buffer.isNotEmpty) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _buffer,
                style: const TextStyle(
                  color: Color(0xFF00E5FF),
                  fontSize: 14,
                ),
              ),
            ),
          ],
          for (final List<String> row in _rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: row.map((String key) {
                  return Expanded(
                    child: _KeyButton(
                      label: key,
                      connected: connected,
                      onPressed: () => _press(key),
                    ),
                  );
                }).toList(),
              ),
            ),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: _KeyButton(
                  label: 'SPACE',
                  connected: connected,
                  onPressed: () => _press(' '),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  connected: connected,
                  onPressed: () => _press('DEL'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'SEND',
                  accent: const Color(0xFF7C4DFF),
                  strength: HapticStrength.medium,
                  connected: connected,
                  onPressed: _sendAll,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.connected,
    required this.onPressed,
    this.accent = const Color(0xFF00E5FF),
    this.strength = HapticStrength.selection,
  });

  final String label;
  final bool connected;
  final VoidCallback onPressed;
  final Color accent;
  final HapticStrength strength;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: connected ? 1 : 0.55,
      child: TactileButton(
        semanticLabel: 'Key $label',
        strength: strength,
        onPressed: onPressed,
        borderRadius: BorderRadius.circular(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: accent.withValues(alpha: 0.10),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: SizedBox(
          height: 42,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
