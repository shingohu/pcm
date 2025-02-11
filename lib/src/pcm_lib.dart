import 'dart:io';

import 'package:flutter/services.dart';

const _channel = const MethodChannel('com.lianke.pcm');

///热重启,释放native端资源
Future<void> PCMHotRestart() async {
  if (Platform.isIOS || Platform.isAndroid || Platform.isMacOS) {
    return _channel.invokeMethod("hotRestart");
  }
}
