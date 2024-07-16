import 'dart:io';

import 'package:flutter/services.dart';

final _InnerPCMPlayer PCMPlayer = _InnerPCMPlayer._();

class _InnerPCMPlayer {
  _InnerPCMPlayer._();

  final _channel = const MethodChannel('pcm/recorder');
  bool isPlayingNow = false;

  /**
   * 播放PCM数据
   * [data] pcm数据
   * [sampleRateInHz]采样率
   * [voiceCall]是否语音呼叫(android有效)
   */
  Future<void> play(
    Uint8List data, {
    int sampleRateInHz = 8000,
    bool voiceCall = false,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    isPlayingNow = true;
    _channel.invokeMethod("startPlaying", {
      "data": data,
      "sampleRateInHz": sampleRateInHz,
      "voiceChat": voiceCall,
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("isPlaying");
  }

  ///结束播放
  Future<void> stop() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod("stopPlaying");
    isPlayingNow = false;
  }

  ///待播放长度
  Future<int> unPlayLength() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return 0;
    }
    return await _channel.invokeMethod("unPlayLength");
  }
}
