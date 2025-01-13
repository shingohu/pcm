import 'dart:io';

import 'package:flutter/services.dart';

final _InnerBeepPlayer BeepPlayer = _InnerBeepPlayer._();

const _channel = const MethodChannel('com.lianke.pcm');

/**
 * 加载和播放低延时的短音效音频文件
 * 注意只支持放置在asset目录下的文件
 */
class _InnerBeepPlayer {
  _InnerBeepPlayer._();

  ///提前加载asset文件,建议使用AAC格式,对耳机有更低延迟
  Future<bool> load(String assetPath) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return (await _channel
              .invokeMethod<bool>("loadSound", {"soundPath": assetPath})) ??
          false;
    } else {
      print("[BeepPlayer] not support platform");
    }
    return false;
  }

  ///播放asset文件
  Future<void> play(String assetPath) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return (await _channel
          .invokeMethod("playSound", {"soundPath": assetPath}));
    } else {
      print("[BeepPlayer] not support platform");
    }
  }

  ///停止播放asset文件
  Future<void> stop(String assetPath) async {
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      return (await _channel
          .invokeMethod("stopSound", {"soundPath": assetPath}));
    } else {
      print("[BeepPlayer] not support platform");
    }
  }
}
