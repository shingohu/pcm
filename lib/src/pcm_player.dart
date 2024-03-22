import 'package:flutter/services.dart';

final _InnerPCMPlayer PCMPlayer = _InnerPCMPlayer._();

class _InnerPCMPlayer {
  _InnerPCMPlayer._();

  final _channel = const MethodChannel('pcm/recorder');

  bool isPlayingNow = false;

  // Future<void> init({
  //   int sampleRateInHz = 8000,
  //   bool voiceCall = true,
  // }) async {
  //   await _channel.invokeMethod("initPlayer", {
  //     "sampleRateInHz": sampleRateInHz,
  //     "voiceChat": voiceCall,
  //   });
  // }

  /**
   * 播放PCM数据
   * [data] pcm数据
   * [sampleRateInHz]采样率
   * [voiceCall]是否语音呼叫(android有效)
   */
  Future<void> start(
    Uint8List data, {
    int sampleRateInHz = 8000,
    bool voiceCall = true,
  }) async {
    isPlayingNow = true;
    await _channel.invokeMethod("startPlaying", {
      "data": data,
      "sampleRateInHz": sampleRateInHz,
      "voiceChat": voiceCall,
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    return await _channel.invokeMethod("isPlaying");
  }

  ///结束播放
  Future<void> stop() async {
    await _channel.invokeMethod("stopPlaying");
    isPlayingNow = false;
  }
}
