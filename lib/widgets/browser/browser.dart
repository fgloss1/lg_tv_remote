/// Picks the native (webview_flutter) or web placeholder browser at compile
/// time, so `flutter build web` never links the native-only plugin.
library;

export 'browser_web.dart' if (dart.library.io) 'browser_io.dart';