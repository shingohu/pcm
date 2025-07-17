import 'package:flutter/services.dart';

bool _shouldHotRestart = true;
const _channel = const MethodChannel('com.lianke.pcm');

Future<void> hotRestart() async {
  if (!_shouldHotRestart) {
    return;
  }
  _shouldHotRestart = false;
  return _channel.invokeMethod("hotRestart");
}
