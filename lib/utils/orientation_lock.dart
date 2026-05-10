import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum OrientationMode { unlocked, landscape, portrait }

class OrientationLock {
  static const MethodChannel _channel = MethodChannel('app.crf/orientation');

  static final ValueNotifier<OrientationMode> mode =
      ValueNotifier(OrientationMode.unlocked);

  static Future<void> landscape() async {
    mode.value = OrientationMode.landscape;
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
    mode.value = OrientationMode.portrait;
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
    mode.value = OrientationMode.unlocked;
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
