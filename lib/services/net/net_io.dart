/// Native backend backed by `dart:io`: real UDP SSDP discovery and the
/// webOS WebSocket control channel.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'net_types.dart';

export 'net_types.dart';

bool get netSupported => true;

/// WebSocket wrapper over `dart:io`.
class _IoSocket implements LgSocket {
  _IoSocket(this._socket);

  final WebSocket _socket;

  @override
  bool get isOpen => _socket.readyState == WebSocket.open;

  @override
  void add(String data) => _socket.add(data);

  @override
  Stream<String> get messages =>
      _socket.map((Object? event) => '$event').asBroadcastStream();

  @override
  Future<void> close() async {
    try {
      await _socket.close(WebSocketStatus.normalClosure, 'bye');
    } catch (_) {
      // Already closed.
    }
  }
}

Future<LgSocket> connectWebSocket(Uri uri) async {
  final WebSocket socket = await WebSocket.connect(uri.toString());
  return _IoSocket(socket);
}

/// Broadcasts the SSDP `M-SEARCH` probe and yields every unicast reply.
Stream<LgSsdpReply> ssdpMsearch({
  required String searchTarget,
  required String address,
  required int port,
}) async* {
  final RawDatagramSocket socket =
      await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  socket.broadcastEnabled = true;

  try {
    final String message = <String>[
      'M-SEARCH * HTTP/1.1',
      'HOST: $address:$port',
      'MAN: "ssdp:discover"',
      'MX: 2',
      'ST: $searchTarget',
      '',
      '',
    ].join('\r\n');

    socket.send(utf8.encode(message), InternetAddress(address), port);

    // Drain events until the MX window expires.
    await for (final RawSocketEvent event in socket) {
      if (event != RawSocketEvent.read) continue;

      final Datagram? datagram = socket.receive();
      if (datagram == null) continue;

      yield LgSsdpReply(
        payload: utf8.decode(datagram.data, allowMalformed: true),
        address: datagram.address.address,
      );
    }
  } finally {
    socket.close();
  }
}