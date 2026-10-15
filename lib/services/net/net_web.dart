/// Web backend: native sockets are unavailable, so everything degrades to
/// a no-op. Keeps the app running under `flutter run -d chrome`.
library;

import 'net_types.dart';

export 'net_types.dart';

bool get netSupported => false;

Future<LgSocket> connectWebSocket(Uri uri) =>
    throw UnsupportedError('WebSocket is unavailable in the web build');

Stream<LgSsdpReply> ssdpMsearch({
  required String searchTarget,
  required String address,
  required int port,
}) =>
    const Stream<LgSsdpReply>.empty();