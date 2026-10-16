/// Selects the native or web local media server at compile time.
///
/// The TV pulls cast media over plain HTTP, so the phone has to serve the
/// picked file. Keeping this behind a conditional import leaves `dart:io` out
/// of the web bundle.
library;

export 'media_server_web.dart' if (dart.library.io) 'media_server_io.dart';
