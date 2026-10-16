/// Native backend: serves picked media from the phone over plain HTTP so the
/// television can pull it, which is the only way webOS will play a local file.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

bool get mediaServerSupported => true;

/// A tiny single purpose HTTP server.
///
/// One entry is published per picked file; the television receives a
/// `http://<phone-ip>:<port>/<token>` URL that it can stream or seek in.
class MediaServer {
  MediaServer._();

  static final MediaServer instance = MediaServer._();

  HttpServer? _server;
  final Map<String, _Published> _published = <String, _Published>{};
  String? _cachedIp;

  bool get isRunning => _server != null;
  int? get port => _server?.port;

  /// Publishes the file at [path] and returns the URL the TV can fetch.
  ///
  /// Returns `null` when no usable network address can be determined.
  Future<String?> publish(String path, {String? mimeType}) async {
    final File file = File(path);
    if (!file.existsSync()) return null;

    final HttpServer server = await _ensureServer();
    final String extension = _extensionOf(path);
    final String token =
        '${DateTime.now().microsecondsSinceEpoch}_${_published.length}$extension';
    final _Published entry = _Published(
      file: file,
      mimeType: mimeType ?? _mimeFor(extension),
    );
    _published[token] = entry;

    final String? ip = await _localIp();
    if (ip == null) {
      _published.remove(token);
      return null;
    }

    return 'http://$ip:${server.port}/$token';
  }

  /// Drops every published file and closes the socket.
  Future<void> stop() async {
    _published.clear();
    final HttpServer? server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<HttpServer> _ensureServer() async {
    final HttpServer? existing = _server;
    if (existing != null) return existing;

    final HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    server.listen(_handleRequest, onError: (Object _) {}, cancelOnError: false);
    _server = server;
    return server;
  }

  Future<String?> _localIp() async {
    final String? cached = _cachedIp;
    if (cached != null && cached.isNotEmpty) return cached;

    String? ip;
    try {
      ip = await NetworkInfo().getWifiIP();
    } catch (_) {
      ip = null;
    }

    if (ip == null || ip.isEmpty) {
      try {
        final List<NetworkInterface> interfaces =
            await NetworkInterface.list(type: InternetAddressType.IPv4);
        for (final NetworkInterface iface in interfaces) {
          final bool loopback =
              iface.addresses.isNotEmpty && iface.addresses.first.isLoopback;
          if (loopback) continue;
          for (final InternetAddress addr in iface.addresses) {
            if (addr.address.startsWith('192.168.') ||
                addr.address.startsWith('10.')) {
              ip = addr.address;
              break;
            }
          }
          if (ip != null) break;
        }
      } catch (_) {
        ip = null;
      }
    }

    if (ip == null || ip.isEmpty) return null;
    _cachedIp = ip;
    return ip;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final _Published? entry = _published[request.uri.pathSegments.last];
    final HttpResponse response = request.response;

    // The TV and any browser preview may hit the server cross origin.
    response.headers.set('Access-Control-Allow-Origin', '*');

    if (entry == null || !entry.file.existsSync()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final int length = await entry.file.length();
    response.headers.contentType = ContentType.parse(entry.mimeType);
    response.headers.set('Accept-Ranges', 'bytes');
    response.headers.set('Cache-Control', 'no-store');

    final int? start = _rangeStart(request.headers.value('range'), length);
    if (start != null) {
      // Partial content: the TV relies on this to seek inside videos.
      final int end = _rangeEnd(request.headers.value('range'), length);
      response.statusCode = HttpStatus.partialContent;
      response.headers.contentLength = end - start + 1;
      response.headers.set(
        'Content-Range',
        'bytes $start-$end/$length',
      );
      await _pipe(request, response, entry.file, start, end + 1);
      return;
    }

    response.statusCode = HttpStatus.ok;
    response.headers.contentLength = length;
    await _pipe(request, response, entry.file, 0, length);
  }

  Future<void> _pipe(
    HttpRequest request,
    HttpResponse response,
    File file,
    int start,
    int endExclusive,
  ) async {
    try {
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }

      final Stream<List<int>> chunks =
          file.openRead(start, endExclusive > start ? endExclusive : start + 1);
      await response.addStream(chunks);
      await response.close();
    } catch (e) {
      debugPrint('[LGTV] media server failed to stream file: $e');
      await response.close();
    }
  }

  static int? _rangeStart(String? header, int length) {
    if (header == null || !header.startsWith('bytes=')) return null;
    final String spec = header.substring('bytes='.length).split(',').first.trim();
    if (spec.startsWith('-')) {
      final int? suffix = int.tryParse(spec.substring(1));
      if (suffix == null || suffix <= 0) return null;
      return length > suffix ? length - suffix : 0;
    }
    final int? start = int.tryParse(spec.split('-').first);
    if (start == null || start >= length) return null;
    return start;
  }

  static int _rangeEnd(String? header, int length) {
    if (header == null || !header.startsWith('bytes=')) return length - 1;
    final String spec = header.substring('bytes='.length).split(',').first.trim();
    final int? end = int.tryParse(spec.split('-').last);
    if (end == null || end >= length) return length - 1;
    return end;
  }

  static String _extensionOf(String path) {
    final int dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot).toLowerCase();
  }

  static const Map<String, String> _mimeTypes = <String, String>{
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    '.bmp': 'image/bmp',
    '.heic': 'image/heic',
    '.mp4': 'video/mp4',
    '.m4v': 'video/mp4',
    '.mov': 'video/quicktime',
    '.mkv': 'video/x-matroska',
    '.webm': 'video/webm',
    '.avi': 'video/x-msvideo',
    '.mp3': 'audio/mpeg',
    '.m4a': 'audio/mp4',
    '.aac': 'audio/aac',
    '.flac': 'audio/flac',
    '.wav': 'audio/wav',
    '.ogg': 'audio/ogg',
    '.opus': 'audio/ogg',
  };

  static String _mimeFor(String extension) =>
      _mimeTypes[extension] ?? 'application/octet-stream';
}

class _Published {
  const _Published({required this.file, required this.mimeType});

  final File file;
  final String mimeType;
}
