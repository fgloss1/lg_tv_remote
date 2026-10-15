/// Selects the native or web networking backend at compile time.
///
/// Importing this file keeps `dart:io` out of the web bundle while still
/// exposing the same API on mobile and desktop.
library;

export 'net_web.dart' if (dart.library.io) 'net_io.dart';