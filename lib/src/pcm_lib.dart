import 'dart:io';

import 'package:flutter/services.dart';

const _channel = const MethodChannel('com.lianke.pcm');

class PCMLib {
  ///热重启,释放native端资源
  static Future<void> hotRestart() async {
    if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
      return _channel.invokeMethod("hotRestart");
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
