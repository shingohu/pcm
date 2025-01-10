import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _channel = const MethodChannel('com.lianke.pcm');

class PCMPlayer {
  bool get isPlayingNow => _isPlayingNow;
  bool _isPlayingNow = false;

  final String playerId;
  bool _dispose = false;

  bool _hasSetUp = false;

  PCMPlayer({String? playerId, int? sampleRateInHz})
      : playerId = playerId ?? _uuid.v4() {
    if (sampleRateInHz != null) {
      setUp(sampleRateInHz: sampleRateInHz);
    }
  }

  ///初始化播放器
  ///[sampleRateInHz]采样率
  Future<void> setUp({
    int sampleRateInHz = 8000,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_hasSetUp) {
      return;
    }
    _dispose = false;
    _hasSetUp = true;
    return _channel.invokeMethod("setUpPlayer", {
      "sampleRateInHz": sampleRateInHz,
      "playerId": playerId,
    });
  }

  ///开始播放
  Future<void> play() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_dispose || !_hasSetUp) {
      return;
    }
    if (_isPlayingNow) {
      return;
    }
    _isPlayingNow = true;
    _isPlayingNow = await _channel.invokeMethod<bool>("startPlaying", {
          "playerId": playerId,
        }) ??
        false;
  }

  /**
   * 以Stream方式持续播放PCM数据
   */
  Future<void> feed(Uint8List data) async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_dispose || !_hasSetUp) {
      return;
    }
    return _channel.invokeMethod("feedPlaying", {
      "data": data,
      "playerId": playerId,
    });
  }

  ///停止播放(不销毁播放器)
  Future<void> stop() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_dispose || !_hasSetUp) {
      return;
    }
    _isPlayingNow = false;
    await _channel.invokeMethod("pausePlaying", {
      "playerId": playerId,
    });
  }

  ///结束播放(销毁播放器)
  Future<void> release() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_dispose || !_hasSetUp) {
      return;
    }
    _hasSetUp = false;
    _dispose = true;
    _isPlayingNow = false;
    await _channel.invokeMethod("stopPlaying", {
      "playerId": playerId,
    });
  }

  ///清空播放数据
  Future<void> clear() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return;
    }
    if (_dispose || !_hasSetUp) {
      return;
    }
    await _channel.invokeMethod("clearPlaying", {
      "playerId": playerId,
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return false;
    }
    return await _channel.invokeMethod("isPlaying", {
      "playerId": playerId,
    });
  }

  ///剩余播放帧长度
  Future<int> remainingFrames() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      return 0;
    }
    return await _channel.invokeMethod("remainingFrames", {
      "playerId": playerId,
    });
  }
}
