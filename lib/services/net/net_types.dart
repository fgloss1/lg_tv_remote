/// Platform-agnostic socket primitives shared by the native and web backends.
library;

/// A minimal text socket abstraction (WebSocket on mobile/desktop).
abstract class LgSocket {
  /// Whether the socket is open and able to accept frames.
  bool get isOpen;

  /// Sends a text frame.
  void add(String data);

  /// Inbound text frames.
  Stream<String> get messages;

  /// Closes the socket.
  Future<void> close();
}

/// A single SSDP reply.
class LgSsdpReply {
  const LgSsdpReply({required this.payload, required this.address});

  final String payload;
  final String address;
}

/// Whether the native networking backend is available in this build.
bool get netSupported => false;

/// Opens a text socket. Throws [UnsupportedError] on platforms without it.
Future<LgSocket> connectWebSocket(Uri uri) =>
    throw UnsupportedError('WebSocket is not available on this platform');

/// Broadcasts an SSDP `M-SEARCH` and streams the unicast replies.
Stream<LgSsdpReply> ssdpMsearch({
  required String searchTarget,
  required String address,
  required int port,
}) =>
    const Stream<LgSsdpReply>.empty();