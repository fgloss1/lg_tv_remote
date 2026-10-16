import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';
import '../widgets/device_picker.dart';
import '../widgets/tactile.dart';
import '../widgets/tv_feedback.dart';

/// Media Cast Screen - cast photos, videos and music from phone to TV.
///
/// The three tiles always open a real system picker. webOS cannot pull a file
/// off the phone, so a picked file is served over HTTP by the phone and the
/// television streams it from that URL.
class MediaCastScreen extends StatefulWidget {
  const MediaCastScreen({super.key});

  @override
  State<MediaCastScreen> createState() => _MediaCastScreenState();
}

/// Which picker a tile opens, used to key the busy spinner.
enum _CastKind {
  photos('Photos'),
  videos('Videos'),
  music('Music');

  const _CastKind(this.label);

  final String label;
}

class _MediaCastScreenState extends State<MediaCastScreen> {
  final ImagePicker _picker = ImagePicker();

  _CastKind? _busy;
  String _status = 'Pick something from your phone and it plays on the TV';
  List<String> _lastCasts = <String>[];

  /// Runs a picker flow with the busy flag set and cleared around it.
  Future<void> _run(
    _CastKind kind,
    Future<void> Function(TVService tv) action,
  ) async {
    if (_busy != null) return;

    // Resolved before the first await so no BuildContext crosses a gap.
    final TVService tv = context.read<TVService>();
    setState(() {
      _busy = kind;
      _status = 'Waiting for the picker…';
    });

    try {
      await action(tv);
    } catch (e) {
      _fail('${kind.label} picker failed: $e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  void _setStatus(String value) {
    if (!mounted) return;
    setState(() => _status = value);
  }

  Future<void> _castPhotos() => _run(_CastKind.photos, (TVService tv) async {
        final List<XFile> files =
            await _picker.pickMultiImage(imageQuality: 90);
        if (files.isEmpty) {
          _setStatus('No photos picked');
          return;
        }
        await _play(tv, files.map((XFile f) => f.path).toList(), 'photo');
      });

  Future<void> _castVideos() => _run(_CastKind.videos, (TVService tv) async {
        final XFile? file =
            await _picker.pickVideo(source: ImageSource.gallery);
        if (file == null) {
          _setStatus('No video picked');
          return;
        }
        await _play(tv, <String>[file.path], 'video');
      });

  Future<void> _castMusic() => _run(_CastKind.music, (TVService tv) async {
        // image_picker has no audio filter, so music goes through file_picker,
        // which can restrict the dialog to audio files.
        final FilePickerResult? result = await FilePicker.pickFiles(
          dialogTitle: 'Pick a track to play on the TV',
          type: FileType.audio,
          allowMultiple: false,
        );

        final PlatformFile? file =
            result == null || result.files.isEmpty ? null : result.files.first;
        if (file == null) {
          _setStatus('No track picked');
          return;
        }

        final String? path = file.path;
        if (path == null || path.isEmpty) {
          _fail('That file could not be read on this platform');
          return;
        }
        await _play(tv, <String>[path], 'track');
      });

  /// Publishes each picked file over HTTP and asks the TV to play it.
  Future<void> _play(TVService tv, List<String> paths, String kind) async {
    if (!mounted) return;

    if (!tv.isConnected) {
      setState(() => _lastCasts = _names(paths));
      _setStatus('Ready to cast ${paths.length} $kind file(s) — pick a TV first');
      showRemoteToast(
        context,
        'Selected ${paths.length} $kind file(s). Choose a TV to start casting.',
        action: SnackBarAction(
          label: 'Choose TV',
          onPressed: () => showDevicePicker(context),
        ),
      );
      return;
    }

    try {
      for (int i = 0; i < paths.length; i++) {
        await tv.playLocalMedia(paths[i], kind);
        _setStatus('Casting ${paths.length - i} file(s)…');
      }
      setState(() => _lastCasts = _names(paths));
      _setStatus('Playing ${paths.length} $kind file(s) on the TV');
    } catch (e) {
      _fail('Cast failed: $e');
    }
  }

  List<String> _names(List<String> paths) => paths
      .map((String p) => p.split(RegExp(r'[/\\]')).last)
      .toList();

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _status = message);
    showRemoteToast(context, message, error: true);
  }

  @override
  Widget build(BuildContext context) {
    final TVService tv = context.watch<TVService>();
    final bool connected = tv.isConnected;

    return CustomScrollView(
      slivers: <Widget>[
        const SliverAppBar(
          pinned: true,
          backgroundColor: Color(0xFF0F0F12),
          foregroundColor: Colors.white,
          title: Text('Media Cast'),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _Banner(
                  connected: connected,
                  deviceName: tv.device?.name,
                  onTap: () => showDevicePicker(context),
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.92,
                  children: <Widget>[
                    MediaGridItem(
                      icon: Icons.photo_library,
                      label: 'Cast Photos',
                      subtitle: 'Stream images from your gallery',
                      accentColor: const Color(0xFF00E5FF),
                      busy: _busy == _CastKind.photos,
                      onTap: _castPhotos,
                    ),
                    MediaGridItem(
                      icon: Icons.video_library,
                      label: 'Cast Videos',
                      subtitle: 'Stream a local video file',
                      accentColor: const Color(0xFF7C4DFF),
                      busy: _busy == _CastKind.videos,
                      onTap: _castVideos,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                MediaGridItem(
                  icon: Icons.music_note,
                  label: 'Cast Music',
                  subtitle: 'Play phone audio on the TV speakers',
                  accentColor: Colors.purpleAccent,
                  busy: _busy == _CastKind.music,
                  onTap: _castMusic,
                  horizontal: true,
                ),
                const SizedBox(height: 16),
                _StatusCard(
                  status: _status,
                  files: _lastCasts,
                  onClear: () => setState(() {
                    _lastCasts = <String>[];
                    _status = 'Pick something from your phone and it plays on the TV';
                  }),
                ),
                if (kIsWeb || !tv.canServeLocalMedia) ...<Widget>[
                  const SizedBox(height: 12),
                  const _PlatformNote(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------- sub widgets

/// Connection hint banner - tapping it opens the device picker.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.connected,
    required this.onTap,
    this.deviceName,
  });

  final bool connected;
  final VoidCallback onTap;
  final String? deviceName;

  @override
  Widget build(BuildContext context) {
    final Color color = connected ? Colors.green : Colors.redAccent;

    return TactileButton(
      semanticLabel: connected ? 'Connected TV. Tap to switch' : 'Choose a TV',
      onPressed: onTap,
      borderRadius: BorderRadius.circular(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          Icon(
            connected ? Icons.cast_connected : Icons.cast,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connected
                  ? 'Connected to ${deviceName ?? 'your TV'} — choose what to stream'
                  : 'Connect to your LG TV from the Remote tab first',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          Icon(Icons.chevron_right, color: color.withValues(alpha: 0.8), size: 20),
        ],
      ),
    );
  }
}

/// Shows what the pickers did last, so a tap always has a visible result.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.status,
    required this.files,
    required this.onClear,
  });

  final String status;
  final List<String> files;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            status,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (files.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final String file in files.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF00E5FF),
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        file,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (files.length > 4)
              Text(
                '+ ${files.length - 4} more',
                style: const TextStyle(color: Colors.white24, fontSize: 11),
              ),
            const SizedBox(height: 8),
            TactileButton(
              semanticLabel: 'Clear selection',
              onPressed: onClear,
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.06),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explains the web limitation instead of failing silently.
class _PlatformNote extends StatelessWidget {
  const _PlatformNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Web preview: pickers open, but serving the file to the television '
        'needs a phone or desktop build of the app.',
        style: TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}

/// Grid item widget for media cast.
///
/// [onTap] is required and the tile is always live - the picker is the thing
/// the tap opens, and connection problems are reported afterwards.
class MediaGridItem extends StatelessWidget {
  const MediaGridItem({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.subtitle,
    this.horizontal = false,
    this.busy = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final bool horizontal;

  /// Shows a spinner while the system picker is open.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final Widget content = horizontal
        ? Row(
            children: <Widget>[
              _icon(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              _icon(),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ],
          );

    return TactileButton(
      semanticLabel: label,
      strength: HapticStrength.medium,
      onPressed: onTap,
      borderRadius: BorderRadius.circular(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.35)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accentColor.withValues(alpha: 0.14),
            const Color(0xFF0F0F12).withValues(alpha: 0.6),
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _icon() {
    if (busy) {
      return SizedBox(
        width: 36,
        height: 36,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: accentColor,
        ),
      );
    }
    return Icon(icon, color: accentColor, size: 36);
  }
}
