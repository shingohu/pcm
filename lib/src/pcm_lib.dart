import 'dart:io';

import 'package:flutter/services.dart';

const _channel = const MethodChannel('com.lianke.pcm');

class PCMLib {
  static bool _enableLog = true;

  ///开启或者关闭日志
  static Future<void> enableLog({
    required bool enable,
  }) async {
    _enableLog = enable;
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
      return _channel.invokeMethod("enableLog", {
        "enableLog": enable,
      });
    }
  }

  ///热重启,释放native端资源
  static Future<void> hotRestart() async {
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
      return _channel.invokeMethod("hotRestart");
    }
  }

  ///打印日志
  static void log(String message) {
    if (_enableLog) {
      print(message);
    }
  }

  ///是否正在打电话
  Future<bool> get isTelephoneCalling async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("isTelephoneCalling");
  }
}
