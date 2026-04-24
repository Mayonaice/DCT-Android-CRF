import 'package:flutter/services.dart';

class OrientationLock {
  static const MethodChannel _channel = MethodChannel('app.crf/orientation');

  static Future<void> landscape() async {
    try {
      await _channel.invokeMethod('lockLandscape');
    } catch (_) {}
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  static Future<void> portrait() async {
    try {
      await _channel.invokeMethod('lockPortrait');
    } catch (_) {}
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } catch (_) {}
  }

  static Future<void> unlock() async {
    try {
      await _channel.invokeMethod('unlock');
    } catch (_) {}
    try {
      await SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }
}
