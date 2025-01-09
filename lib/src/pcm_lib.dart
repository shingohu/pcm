import 'dart:io';

import 'package:flutter/services.dart';

const _channel = const MethodChannel('com.lianke.pcm');

class PCMLib {
  ///开启或者关闭日志
  static Future<void> enableLog({
    required bool enable,
  }) async {
    if (Platform.isIOS || Platform.isAndroid) {
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
}
