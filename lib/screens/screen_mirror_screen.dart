import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import '../widgets/device_picker.dart';
import '../widgets/tactile.dart';
import '../widgets/tv_feedback.dart';

/// Screen mirroring control surface: start/stop, resolution and latency preset.
class ScreenMirrorScreen extends StatefulWidget {
  const ScreenMirrorScreen({super.key});

  @override
  State<ScreenMirrorScreen> createState() => _ScreenMirrorScreenState();
}

enum MirrorPreset {
  gaming('Gaming mode', 'Lowest latency for competitive play', Icons.sports_esports),
  movie('Movie mode', 'Smooth playback, film-grade pacing', Icons.movie),
  balanced('Balanced', 'Recommended default', Icons.tune);

  const MirrorPreset(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

enum MirrorResolution {
  hd720('720p', 1280, 720),
  fullHd1080('1080p', 1920, 1080),
  ultraHd4k('4K', 3840, 2160);

  const MirrorResolution(this.label, this.width, this.height);

  final String label;
  final int width;
  final int height;
}

class _ScreenMirrorScreenState extends State<ScreenMirrorScreen> {
  bool _mirroring = false;
  MirrorResolution _resolution = MirrorResolution.fullHd1080;
  MirrorPreset _preset = MirrorPreset.balanced;

  void _toggle() {
    if (!_mirroring) {
      final TVService tv = context.read<TVService>();
      if (!tv.isConnected) {
        showRemoteToast(
          context,
          'Connect to your LG TV from the Remote tab first',
          error: true,
          action: SnackBarAction(
            label: 'Choose TV',
            onPressed: () => showDevicePicker(context),
          ),
        );
        return;
      }
    }

    setState(() => _mirroring = !_mirroring);
    showRemoteToast(
      context,
      _mirroring
          ? 'Mirroring started at ${_resolution.label}'
          : 'Mirroring stopped',
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(
          pinned: true,
          backgroundColor: Color(0xFF0F0F12),
          foregroundColor: Colors.white,
          title: Text('Screen Mirror'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate(<Widget>[
              _MirrorToggle(
                mirroring: _mirroring,
                resolution: _resolution,
                onToggle: _toggle,
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Resolution'),
              const SizedBox(height: 10),
              _ResolutionRow(
                selected: _resolution,
                onChanged: (MirrorResolution r) => setState(() => _resolution = r),
              ),
              const SizedBox(height: 20),
              const _SectionLabel('Latency optimization'),
              const SizedBox(height: 10),
              _PresetList(
                selected: _preset,
                onChanged: (MirrorPreset p) => setState(() => _preset = p),
              ),
              const SizedBox(height: 20),
              const _ConnectionHelper(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: Colors.white38,
        fontSize: 10,
        letterSpacing: 1.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

// ------------------------------------------------------------------- toggle

class _MirrorToggle extends StatelessWidget {
  const _MirrorToggle({
    required this.mirroring,
    required this.resolution,
    required this.onToggle,
  });

  final bool mirroring;
  final MirrorResolution resolution;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final Color accent = mirroring ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);

    return TactileButton(
      semanticLabel: mirroring ? 'Stop mirroring' : 'Start mirroring',
      strength: HapticStrength.medium,
      pressScale: 0.97,
      onPressed: onToggle,
      borderRadius: BorderRadius.circular(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: mirroring ? 0.28 : 0.16),
            const Color(0xFF0F0F12),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 76,
            width: 76,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (mirroring)
                  const SpinKitRipple(color: Color(0xFF00E5FF), size: 74)
                else
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                Icon(
                  mirroring ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            mirroring ? 'Stop mirroring' : 'Start mirroring',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${resolution.label}  •  ${resolution.width}x${resolution.height}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- resolution

class _ResolutionRow extends StatelessWidget {
  const _ResolutionRow({required this.selected, required this.onChanged});

  final MirrorResolution selected;
  final ValueChanged<MirrorResolution> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: MirrorResolution.values.map((MirrorResolution r) {
        final bool isSelected = r == selected;
        const Color accent = Color(0xFF00E5FF);

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: TactileButton(
              semanticLabel: 'Resolution ${r.label}',
              onPressed: () => onChanged(r),
              borderRadius: BorderRadius.circular(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: isSelected
                    ? accent.withValues(alpha: 0.18)
                    : const Color(0xFF1A1A20),
                border: Border.all(
                  color: isSelected ? accent : Colors.white12,
                  width: isSelected ? 1.6 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: <Widget>[
                  Text(
                    r.label,
                    style: TextStyle(
                      color: isSelected ? accent : Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${r.height}p',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ------------------------------------------------------------------ presets

class _PresetList extends StatelessWidget {
  const _PresetList({required this.selected, required this.onChanged});

  final MirrorPreset selected;
  final ValueChanged<MirrorPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: MirrorPreset.values.map((MirrorPreset p) {
        final bool isSelected = p == selected;
        const Color violet = Color(0xFF7C4DFF);

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TactileButton(
            semanticLabel: p.label,
            onPressed: () => onChanged(p),
            borderRadius: BorderRadius.circular(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: isSelected
                  ? violet.withValues(alpha: 0.16)
                  : const Color(0xFF1A1A20),
              border: Border.all(
                color: isSelected ? violet : Colors.white12,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                Icon(
                  p.icon,
                  color: isSelected ? violet : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        p.label,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.description,
                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? violet : Colors.white24,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// --------------------------------------------------------- connection steps

class _ConnectionHelper extends StatelessWidget {
  const _ConnectionHelper();

  static const List<String> _steps = <String>[
    'Connect the phone and TV to the same Wi-Fi network.',
    'On the TV open Home ▸ Screen Share (Smart View).',
    'Choose "Share from phone" and wait for this device.',
    'Tap Start mirroring above to send your screen.',
  ];

  @override
  Widget build(BuildContext context) {
    const Color cyan = Color(0xFF00E5FF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cyan.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(Icons.help_outline, color: Color(0xFF00E5FF), size: 18),
              SizedBox(width: 8),
              Text(
                'Connection helper',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < _steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cyan.withValues(alpha: 0.16),
                      border: Border.all(color: cyan.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _steps[i],
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}