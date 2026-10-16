/// Web backend: there is no `dart:io` socket to bind, so nothing can be
/// served to the television. The cast screen detects this and explains that
/// casting from the gallery needs a phone or desktop build.
library;

bool get mediaServerSupported => false;

class MediaServer {
  MediaServer._();

  static final MediaServer instance = MediaServer._();

  bool get isRunning => false;
  int? get port => null;

  Future<String?> publish(String path, {String? mimeType}) async => null;

  Future<void> stop() async {}
}
