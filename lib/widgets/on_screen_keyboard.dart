import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';

/// On-screen remote keyboard. Every key press is forwarded to the TV over the
/// webOS control socket so text can be typed in search boxes and forms.
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

    switch (label) {
      case 'ESC':
        tv.pressBack();
      case 'DEL':
        if (_buffer.isNotEmpty) {
          setState(() => _buffer = _buffer.substring(0, _buffer.length - 1));
        }
        tv.sendKey('BACKSPACE');
      default:
        setState(() => _buffer += label);
        tv.sendKey(_charKeys[label] ?? label);
    }
  }

  Future<void> _sendAll() async {
    final TVService tv = context.read<TVService>();
    if (_buffer.isEmpty) return;
    await tv.sendText(_buffer);
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
    return InkWell(
      onTap: connected ? () => setState(() => _expanded = !_expanded) : null,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.keyboard,
              size: 22,
              color: connected ? const Color(0xFF00E5FF) : Colors.white24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'On-screen keyboard',
                style: TextStyle(
                  color: connected ? Colors.white : Colors.white24,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              color: connected ? Colors.white38 : Colors.white12,
            ),
          ],
        ),
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
                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14),
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
                      onPressed: connected ? () => _press(key) : null,
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
                  onPressed: connected ? () => _press(' ') : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'DEL',
                  onPressed: connected ? () => _press('DEL') : null,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: _KeyButton(
                  label: 'SEND',
                  accent: const Color(0xFF7C4DFF),
                  onPressed: connected ? _sendAll : null,
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
    required this.onPressed,
    this.accent = const Color(0xFF00E5FF),
  });

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
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9),
          child: Ink(
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: accent.withValues(alpha: 0.10),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
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
      ),
    );
  }
}