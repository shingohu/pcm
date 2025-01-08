import 'dart:io';

import 'package:flutter/services.dart';

const _channel = const MethodChannel('com.lianke.pcm');

class PCMLog {
  ///开启或者关闭日志
  static Future<void> enable({
    required bool enable,
  }) async {
    if (Platform.isIOS || Platform.isAndroid) {
      return _channel.invokeMethod("enableLog", {
        "enableLog": enable,
      });
    }
  }
}
