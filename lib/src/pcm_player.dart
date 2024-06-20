import 'dart:io';

import 'package:flutter/services.dart';

final _InnerPCMPlayer PCMPlayer = _InnerPCMPlayer._();

class _InnerPCMPlayer {
  _InnerPCMPlayer._();

  final _channel = const MethodChannel('pcm/recorder');

  bool isPlayingNow = false;
  int? _sampleRateInHz;

  bool? _voiceCall;
  bool _hasInit = false;

  Future<void> init({
    int sampleRateInHz = 8000,
    bool voiceCall = true,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    if (isPlayingNow) {
      print("player is playing Now");
      return;
    }
    if (_hasInit) {
      if (_sampleRateInHz != sampleRateInHz || _voiceCall != voiceCall) {
        print(
            "player has inited, but sampleRateInHz voiceCall is changed,release and reinit");
        await release();
      } else {
        return;
      }
    }

    _hasInit = true;
    _sampleRateInHz = sampleRateInHz;
    _voiceCall = voiceCall;
    await _channel.invokeMethod("initPlayer", {
      "sampleRateInHz": sampleRateInHz,
      "voiceChat": voiceCall,
    });
  }

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
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }

    if (_hasInit) {
      if (_sampleRateInHz != sampleRateInHz || _voiceCall != voiceCall) {
        print(
            "player has inited, but sampleRateInHz voiceCall is changed,release and reinit");
        await release();
      }
    }
    isPlayingNow = true;
    _sampleRateInHz = sampleRateInHz;
    _voiceCall = voiceCall;
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

  ///销毁播放器
  Future<void> release() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    _hasInit = false;
    if (isPlayingNow) {
      await stop;
    }
    await _channel.invokeMethod("releasePlayer");
    this._sampleRateInHz = null;
    this._voiceCall = null;
  }

  ///待播放长度
  Future<int> unPlayLength() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return 0;
    }
    return await _channel.invokeMethod("unPlayLength");
  }
}
