import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/tv_service.dart';

/// Media Cast Screen - Cast photos, videos and music from phone to TV.
class MediaCastScreen extends StatefulWidget {
  const MediaCastScreen({super.key});

  @override
  State<MediaCastScreen> createState() => _MediaCastScreenState();
}

class _MediaCastScreenState extends State<MediaCastScreen> {
  final ImagePicker _picker = ImagePicker();

  bool _busy = false;

  Future<void> _castPhotos() async {
    if (_busy) return;
    // Resolve the service before any await so no BuildContext crosses a gap.
    final TVService tv = context.read<TVService>();
    setState(() => _busy = true);
    try {
      final List<XFile> files = await _picker.pickMultiImage(imageQuality: 85);
      if (files.isEmpty) return;

      for (final XFile file in files) {
        // Stream the image to the TV over the WebOS media endpoint.
        await tv.playMedia(Uri.file(file.path).toString(), 'image');
      }
      _toast('Casting ${files.length} photo(s) to TV');
    } catch (e) {
      _toast('Photo cast failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _castVideos() async {
    if (_busy) return;
    final TVService tv = context.read<TVService>();
    setState(() => _busy = true);
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      await tv.playMedia(Uri.file(file.path).toString(), 'video');
      _toast('Casting ${file.name} to TV');
    } catch (e) {
      _toast('Video cast failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _castMusic() async {
    if (_busy) return;
    final TVService tv = context.read<TVService>();
    setState(() => _busy = true);
    try {
      final XFile? file = await _picker.pickMedia();
      if (file == null) return;

      await tv.playMedia(Uri.file(file.path).toString(), 'audio');
      _toast('Playing ${file.name} on TV speakers');
    } catch (e) {
      _toast('Music cast failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isConnected = context.select<TVService, bool>((TVService t) => t.isConnected);

    return Stack(
      children: <Widget>[
        CustomScrollView(
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
                    _Banner(connected: isConnected),
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
                          onTap: isConnected ? _castPhotos : null,
                        ),
                        MediaGridItem(
                          icon: Icons.video_library,
                          label: 'Cast Videos',
                          subtitle: 'Stream a local video file',
                          accentColor: const Color(0xFF7C4DFF),
                          onTap: isConnected ? _castVideos : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    MediaGridItem(
                      icon: Icons.music_note,
                      label: 'Cast Music',
                      subtitle: 'Play phone audio on the TV speakers',
                      accentColor: Colors.purpleAccent,
                      onTap: isConnected ? _castMusic : null,
                      horizontal: true,
                    ),
                    if (_busy) ...<Widget>[
                      const SizedBox(height: 24),
                      const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Color(0xFF00E5FF),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Connection hint banner.
class _Banner extends StatelessWidget {
  const _Banner({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final Color color = connected ? Colors.green : Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
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
                  ? 'Connected — choose what to stream'
                  : 'Connect to your LG TV from the Remote tab first',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid item widget for media cast.
class MediaGridItem extends StatelessWidget {
  const MediaGridItem({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.onTap,
    this.subtitle,
    this.horizontal = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color accentColor;
  final VoidCallback? onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    final Widget content = horizontal
        ? Row(
            children: <Widget>[
              Icon(icon, color: accentColor, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white38,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                  ],
                ),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: accentColor, size: 36),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: enabled ? Colors.white : Colors.white38,
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

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
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
          ),
        ),
      ),
    );
  }
}