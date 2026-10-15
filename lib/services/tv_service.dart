import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'net/net.dart';

/// A discovered LG webOS TV on the local network.
class LgTvDevice {
  LgTvDevice({
    required this.name,
    required this.ip,
    required this.mac,
    this.port = 3000,
  });

  final String name;
  final String ip;
  final String mac;
  final int port;

  @override
  String toString() => '$name ($ip)';
}

/// Connection lifecycle for the remote.
enum TvConnectionState { disconnected, scanning, pairing, connected, error }

/// Handles LG webOS TV discovery (SSDP over UDP), pairing (HTTP :3000) and
/// control (WebSocket :3001).
///
/// Every native touchpoint sits behind [net], which compiles to a no-op on
/// web, so calling [startDiscovery] in a browser preview is safe.
class TVService extends ChangeNotifier {
  TVService();

  static const String _ssdpAddress = '239.255.255.250';
  static const int _ssdpPort = 1900;
  static const int _httpPort = 3000;
  static const int _wsPort = 3001;

  /// SSDP search target advertised by LG webOS TVs.
  static const String _lgSearchTarget = 'urn:lg-iot:service:discovery:1';

  /// Bootstrapped app keys for the well known LG streaming apps.
  static const Map<String, String> appIds = <String, String>{
    'YouTube': 'youtube.leanback.v4',
    'Netflix': 'com.webos.app.livetv',
    'Prime Video': 'com.amazon.avod',
    'Disney+': 'com.disney.disneyplus',
    'Browser': 'com.webos.app.livetv',
  };

  /// webOS remote key codes.
  static const Map<String, int> keyCodes = <String, int>{
    'UP': 0,
    'DOWN': 1,
    'LEFT': 2,
    'RIGHT': 3,
    'ENTER': 4,
    'BACK': 8,
    'EXIT': 9,
    'RED': 403,
    'GREEN': 404,
    'YELLOW': 405,
    'BLUE': 406,
    'MENU': 82,
    'DASHBOARD': 115,
    'GUIDE': 83,
    'INFO': 31,
    'PLAY': 415,
    'PAUSE': 19,
    'STOP': 412,
    'REWIND': 414,
    'FASTFORWARD': 417,
    'VOLUMEUP': 24,
    'VOLUMEDOWN': 25,
    'MUTE': 21,
    'CHANNELUP': 0x21b,
    'CHANNELDOWN': 0x21c,
    'CC': 0x11a,
    'POWER': 91,
    'BACKSPACE': 409,
    'SPACE': 2,
    'ASTERISK': 42,
    '0': 7,
    '1': 8,
    '2': 9,
    '3': 10,
    '4': 11,
    '5': 12,
    '6': 13,
    '7': 14,
    '8': 15,
    '9': 16,
  };

  final Map<String, LgTvDevice> _devices = <String, LgTvDevice>{};

  TvConnectionState _state = TvConnectionState.disconnected;
  LgTvDevice? _device;
  String? _clientKey;
  String? _error;
  double _volume = 0.5;
  bool _muted = false;

  LgSocket? _ws;
  StreamSubscription<LgSsdpReply>? _ssdpSubscription;
  StreamSubscription<String>? _wsSubscription;

  // ---------------------------------------------------------------- getters

  TvConnectionState get state => _state;
  bool get isConnected => _state == TvConnectionState.connected;
  bool get isScanning => _state == TvConnectionState.scanning;
  String? get error => _error;
  String? get clientKey => _clientKey;
  double get volume => _volume;
  bool get muted => _muted;
  LgTvDevice? get device => _device;
  String? get tvIpAddress => _device?.ip;

  /// True when native sockets are usable (false in the web build).
  bool get isNativeSocketAvailable => netSupported;

  List<LgTvDevice> get devices => _devices.values.toList()
    ..sort((LgTvDevice a, LgTvDevice b) => a.name.compareTo(b.name));

  // ----------------------------------------------------------------- setup

  /// Kicks off an initial scan.
  Future<void> initialize() => startDiscovery();

  // ------------------------------------------------------------- discovery

  /// SSDP `M-SEARCH` sweep for LG webOS TVs.
  ///
  /// On web this short-circuits: there is no UDP socket, so it reports
  /// `disconnected` instead of throwing a null assertion from the socket layer.
  Future<void> startDiscovery() async {
    if (_state == TvConnectionState.scanning) return;

    if (kIsWeb || !netSupported) {
      _error = 'Device discovery is only available on mobile and desktop.';
      _state = TvConnectionState.disconnected;
      notifyListeners();
      debugPrint('[LGTV] discovery skipped: no native sockets on this platform');
      return;
    }

    _state = TvConnectionState.scanning;
    _error = null;
    notifyListeners();

    try {
      await _ssdpSubscription?.cancel();
      _ssdpSubscription = ssdpMsearch(
        searchTarget: _lgSearchTarget,
        address: _ssdpAddress,
        port: _ssdpPort,
      ).listen(_onSsdpReply, onError: (Object e) {
        _error = 'Discovery error: $e';
        _state = TvConnectionState.error;
        notifyListeners();
      });

      // SSDP uses MX to advertise its window; give replies a moment to land.
      await Future<void>.delayed(const Duration(seconds: 3));
    } catch (e) {
      _error = 'Discovery failed: $e';
      _state = TvConnectionState.error;
    } finally {
      if (_state == TvConnectionState.scanning) {
        _state = TvConnectionState.disconnected;
        notifyListeners();
      }
    }
  }

  void _onSsdpReply(LgSsdpReply reply) {
    final _LgSsdpAdvertisement? adv =
        _LgSsdpAdvertisement.parse(reply.payload);
    if (adv == null) return;

    final LgTvDevice found = LgTvDevice(
      name: adv.friendlyName,
      ip: reply.address,
      mac: adv.mac,
    );

    if (_devices[found.ip] == null) {
      _devices[found.ip] = found;
      notifyListeners();
      // Auto-select the first TV discovered.
      if (_device == null) unawaited(connectToDevice(found));
    }
  }

  // ---------------------------------------------------------------- pairing

  /// Pairs with [target] and opens the WebSocket control channel.
  Future<void> connectToDevice(LgTvDevice target) async {
    if (kIsWeb || !netSupported) {
      _error = 'TV control is only available on mobile and desktop.';
      _state = TvConnectionState.error;
      notifyListeners();
      return;
    }

    await disconnect();

    _device = target;
    _state = TvConnectionState.pairing;
    _error = null;
    notifyListeners();

    try {
      // Step 1: request a pairing grant. The first attempt makes the TV show a
      // confirmation dialog; later attempts are auto approved.
      final http.Response grant = await http
          .get(Uri.parse('http://${target.ip}:$_httpPort/pair'))
          .timeout(const Duration(seconds: 4));

      if (grant.statusCode != 200) {
        throw HttpFailure('Pairing refused (HTTP ${grant.statusCode})');
      }

      final Map<String, dynamic> body =
          json.decode(grant.body) as Map<String, dynamic>;
      _clientKey = body['pairing_key'] as String?;

      // Step 2: register this device so the TV whitelists the key.
      if (_clientKey != null) {
        await http.post(
          Uri.parse('http://${target.ip}:$_httpPort/register'),
          headers: <String, String>{'Content-Type': 'application/json'},
          body: json.encode(<String, dynamic>{
            'pairing_key': _clientKey,
            'device_name': 'LG TV Remote',
            'device_id': _clientKey,
          }),
        ).timeout(const Duration(seconds: 4));
      }

      // Step 3: open the control channel.
      _ws = await connectWebSocket(
        Uri.parse('ws://${target.ip}:$_wsPort'),
      ).timeout(const Duration(seconds: 5));

      _wsSubscription = _ws!.messages.listen(
        _handleSocketEvent,
        onError: (Object e) {
          _error = 'Socket error: $e';
          _state = TvConnectionState.error;
          notifyListeners();
        },
        onDone: () {
          if (_state == TvConnectionState.connected) {
            _state = TvConnectionState.disconnected;
            notifyListeners();
          }
        },
      );

      _send(<String, dynamic>{
        'type': 'register',
        'pairing_key': _clientKey,
        'client-key': _clientKey,
        'name': 'flutter_lg_remote',
      });

      _state = TvConnectionState.connected;
      notifyListeners();
    } on TimeoutException catch (e) {
      _error = 'Timed out while pairing: ${e.message ?? 'no response'}';
      _state = TvConnectionState.error;
      notifyListeners();
    } catch (e) {
      _error = 'Pairing failed: $e';
      _state = TvConnectionState.error;
      notifyListeners();
    }
  }

  void _handleSocketEvent(String event) {
    try {
      final Object? decoded = json.decode(event);
      if (decoded is! Map) return;
      if (decoded['type'] == 'registered') {
        _state = TvConnectionState.connected;
        notifyListeners();
      }
    } catch (_) {
      debugPrint('[LGTV] unparsable frame: $event');
    }
  }

  // -------------------------------------------------------------- transport

  void _send(Map<String, dynamic> payload) {
    final LgSocket? ws = _ws;
    if (ws == null || !ws.isOpen) return;
    ws.add(json.encode(payload));
  }

  /// Fire-and-forget command with a unique request id.
  void _command(String method, [Map<String, dynamic> extra = const <String, dynamic>{}]) {
    _send(<String, dynamic>{
      'type': 'request',
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'method': method,
      ...extra,
    });
  }

  // ---------------------------------------------------------------- controls

  /// Sends a named remote key.
  void sendKey(String name) {
    final String upper = name.toUpperCase();
    final int? code = keyCodes[upper];
    if (code == null) {
      debugPrint('[LGTV] unknown key: $name');
      return;
    }
    _command('msc.request', <String, dynamic>{
      'type': 'button',
      'name': upper,
      'x': 1,
      'y': 1,
      'buttonCode': code,
      'timeStamp': 0,
      'origin': 'device2',
    });
  }

  void pressUp() => sendKey('UP');
  void pressDown() => sendKey('DOWN');
  void pressLeft() => sendKey('LEFT');
  void pressRight() => sendKey('RIGHT');
  void pressEnter() => sendKey('ENTER');
  void pressBack() => sendKey('BACK');
  void channelUp() => sendKey('CHANNELUP');
  void channelDown() => sendKey('CHANNELDOWN');

  /// Toggles TV power. Mirrored locally so the UI reacts immediately.
  Future<void> togglePower() async {
    _powerOn = !_powerOn;
    notifyListeners();
    sendKey('POWER');
  }

  bool _powerOn = true;
  bool get isPowered => _powerOn;

  void toggleMute() {
    _muted = !_muted;
    notifyListeners();
    sendKey('MUTE');
  }

  /// Sets the absolute volume (0.0 - 1.0) in 1% steps.
  void setVolume(double level) {
    final double clamped = level.clamp(0.0, 1.0);
    final int delta = ((clamped - _volume) * 100).round();
    _volume = clamped;
    notifyListeners();

    final int steps = delta.abs();
    for (int i = 0; i < steps; i++) {
      sendKey(delta > 0 ? 'VOLUMEUP' : 'VOLUMEDOWN');
    }
  }

  /// Air-mouse pointer movement in screen pixels.
  void pointerMove(double dx, double dy) {
    _command('msc.request', <String, dynamic>{
      'type': 'move',
      'dx': dx,
      'dy': dy,
    });
  }

  /// Air-mouse click.
  void pointerClick() {
    _command('msc.request', <String, dynamic>{
      'type': 'button',
      'name': 'ENTER',
      'x': 1,
      'y': 1,
      'buttonCode': 4,
      'origin': 'device2',
    });
  }

  void pointerScroll(double amount) {
    _command('msc.request', <String, dynamic>{
      'type': 'wheel',
      'dy': amount,
      'dx': 0,
    });
  }

  /// Types a string on the TV through the virtual keyboard endpoint.
  Future<void> sendText(String text) async {
    final LgTvDevice? target = _device;
    if (target == null || text.isEmpty) return;
    try {
      await http.post(
        Uri.parse('http://${target.ip}:$_httpPort/keyboard/input'),
        headers: <String, String>{'Content-Type': 'application/json'},
        body: json.encode(<String, dynamic>{'type': 'keyboard', 'data': text}),
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('[LGTV] sendText failed: $e');
    }
  }

  /// Launches one of the bundled apps by friendly name.
  void launchApp(String friendlyName) {
    final String? id = appIds[friendlyName];
    if (id == null) return;

    _command('launch', <String, dynamic>{
      'id': id,
      'params': <String, dynamic>{'target': friendlyName},
    });
  }

  /// Plays [uri] on the TV's system media player.
  ///
  /// webOS cannot pull files off the phone, so a `file://` URI is rejected with
  /// guidance to serve the media over the network instead.
  Future<void> playMedia(String uri, String kind) async {
    final LgTvDevice? target = _device;
    if (target == null) {
      throw StateError('Not connected to a TV');
    }

    final Uri? parsed = Uri.tryParse(uri);
    final bool isRemote =
        parsed != null && parsed.hasScheme && parsed.scheme != 'file';

    if (!isRemote) {
      throw ArgumentError(
        'webOS cannot pull local files from the phone. '
        'Cast $kind over a local HTTP server or use a network URL.',
      );
    }

    await http.post(
      Uri.parse('http://${target.ip}:$_httpPort/webapp/launch'),
      headers: <String, String>{'Content-Type': 'application/json'},
      body: json.encode(<String, dynamic>{
        'id': 'com.webos.app.livetv',
        'params': <String, dynamic>{'uri': uri, 'title': kind},
      }),
    ).timeout(const Duration(seconds: 5));
  }

  // ------------------------------------------------------------- lifecycle

  Future<void> disconnect() async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    await _ws?.close();
    _ws = null;
    await _ssdpSubscription?.cancel();
    _ssdpSubscription = null;
    _clientKey = null;
    _device = null;
    _state = TvConnectionState.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(disconnect());
    super.dispose();
  }
}

/// Raised when the TV answers the pairing endpoint with a non-200 status.
class HttpFailure implements Exception {
  const HttpFailure(this.message);

  final String message;

  @override
  String toString() => 'HttpFailure: $message';
}

/// Parsed representation of an LG SSDP advertisement.
class _LgSsdpAdvertisement {
  _LgSsdpAdvertisement({required this.friendlyName, required this.mac});

  final String friendlyName;
  final String mac;

  static _LgSsdpAdvertisement? parse(String raw) {
    if (!raw.contains('lg-iot') && !raw.contains('urn:lg')) return null;

    String friendly = 'LG webOS TV';
    String mac = '';

    for (final String line in raw.split('\r\n')) {
      final int i = line.indexOf(':');
      if (i < 0) continue;
      final String key = line.substring(0, i).trim().toLowerCase();
      final String value = line.substring(i + 1).trim();

      if (key == 'usn' && value.startsWith('uuid:')) {
        // usn:uuid:XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX::urn:lg-iot:...
        mac = value.replaceFirst('uuid:', '').split('::').first;
      } else if (key == 'lg-device-name') {
        friendly = value;
      }
    }

    return _LgSsdpAdvertisement(friendlyName: friendly, mac: mac);
  }
}