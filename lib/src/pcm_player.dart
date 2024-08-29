import 'dart:io';

import 'package:flutter/services.dart';

final _InnerPCMPlayer PCMPlayer = _InnerPCMPlayer._();

class _InnerPCMPlayer {
  _InnerPCMPlayer._() {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    isPlaying.then((isPlaying) {
      _isPlayingNow = isPlaying;
    });
  }

  final _channel = const MethodChannel('pcm/player');

  bool get isPlayingNow => _isPlayingNow;
  bool _isPlayingNow = false;

  ///因为网络等原因导致接收数据不稳定,播放不连续时,播放静音数据
  ///[muteTimeMs]播放静音数据的时间 为0表示不播放静音数据
  ///[maxMuteTimeMs]最多连续播放多久的静音数据
  ///只在android上有效
  Future<void> setPlayMuteTime(int muteTimeMs,
      {int maxMuteTimeMs = 100}) async {
    if (Platform.isAndroid) {
      return _channel.invokeMethod("setPlayMuteTime", {
        "muteTimeMs": muteTimeMs,
        "maxMuteTimeMs": maxMuteTimeMs,
      });
    }
  }

  /**
   * 以Stream方式持续播放PCM数据
   * [data] pcm数据
   * [sampleRateInHz]采样率
   * [voiceCall]stream type is voice call?（only android）,一般需要配合audio mode一起使用
   * true: STREAM_VOICE_CALL Used to identify the volume of audio streams for phone calls
   * false: STREAM_MUSIC Used to identify the volume of audio streams for music playback
   */
  Future<void> play(Uint8List data,
      {int sampleRateInHz = 8000, bool voiceCall = false}) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    _isPlayingNow = true;
    return _channel.invokeMethod("startPlaying", {
      "data": data,
      "sampleRateInHz": sampleRateInHz,
      "voiceCall": voiceCall,
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("isPlaying");
  }

  ///结束播放(销毁播放器)
  Future<void> stop() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod("stopPlaying");
    _isPlayingNow = false;
  }

  ///清空播放器
  Future<void> clear() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod("clearPlayer");
  }

  ///剩余播放帧长度
  Future<int> remainingFrames() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return 0;
    }
    return await _channel.invokeMethod("remainingFrames");
  }
}
