import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
const _channel = const MethodChannel('com.lianke.pcm');

///the type of the audio stream [only android]
enum AudioStreamType {
  voice_call(0),
  system(1),
  ring(2),
  music(3),
  alarm(4),
  notification(5);

  final int value;

  const AudioStreamType(this.value);
}

class PCMPlayer {
  ///当前是否正在播放
  bool get isPlayingNow => _isPlayingNow;
  bool _isPlayingNow = false;

  final String playerId;

  ///是否已经销毁
  bool _dispose = false;

  ///是否已经初始化
  bool get _hasSetUp => _sampleRateInHz != null;

  ///初始化采样率
  int? _sampleRateInHz;

  ///是否打印日志
  bool enableLog = true;

  PCMPlayer(
      {String? playerId,
      int sampleRateInHz = 8000,
      AudioStreamType streamType = AudioStreamType.music})
      : playerId = playerId ?? _uuid.v4() {
    setUp(sampleRateInHz: sampleRateInHz, streamType: streamType);
  }

  void _printLog(String message) {
    if (enableLog) {
      print("[PCMPlayer] $playerId:" + message);
    }
  }

  ///初始化播放器
  ///[sampleRateInHz]采样率
  ///[streamType] the type of the audio stream [only android]
  Future<void> setUp({
    int sampleRateInHz = 8000,
    AudioStreamType streamType = AudioStreamType.music,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return;
    }
    if (_sampleRateInHz != null) {
      if (_sampleRateInHz != sampleRateInHz) {
        _printLog("播放器已经初始化，采样率为$_sampleRateInHz");
      }
      return;
    }
    _dispose = false;
    _sampleRateInHz = sampleRateInHz;
    _printLog("初始化播放器,采样率$sampleRateInHz");
    return _channel.invokeMethod("setUpPlayer", {
      "sampleRateInHz": sampleRateInHz,
      "playerId": playerId,
      "streamType": streamType,
    });
  }

  ///开始播放
  Future<void> play() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return;
    }
    if (_dispose) {
      _printLog("播放器已销毁");
      return;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
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
    if (_isPlayingNow) {
      _printLog("开始播放");
    } else {
      _printLog("开始播放失败");
    }
  }

  /**
   * 以Stream方式持续播放PCM数据
   */
  Future<void> feed(Uint8List data) async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return;
    }
    if (_dispose) {
      _printLog("播放器已销毁");
      return;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
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
      print("not support platform");
      return;
    }
    if (_dispose) {
      _printLog("播放器已销毁");
      return;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
      return;
    }
    if (_isPlayingNow) {
      _printLog("结束播放");
    }
    _isPlayingNow = false;
    await _channel.invokeMethod("pausePlaying", {
      "playerId": playerId,
    });
  }

  ///结束播放(销毁播放器)
  Future<void> release() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return;
    }
    if (_dispose) {
      _printLog("播放器已销毁");
      return;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
      return;
    }
    if (_isPlayingNow) {
      _printLog("结束播放");
    }
    _sampleRateInHz = null;
    _dispose = true;
    _isPlayingNow = false;
    await _channel.invokeMethod("stopPlaying", {
      "playerId": playerId,
    });
  }

  ///清空播放数据
  Future<void> clear() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return;
    }
    if (_dispose) {
      _printLog("播放器已经销毁");
      return;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
      return;
    }
    await _channel.invokeMethod("clearPlaying", {
      "playerId": playerId,
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return false;
    }
    if (_dispose) {
      _printLog("播放器已经销毁");
      return false;
    }
    if (!_hasSetUp) {
      _printLog("播放器未初始化");
      return false;
    }
    return await _channel.invokeMethod("isPlaying", {
      "playerId": playerId,
    });
  }

  ///剩余播放帧长度
  Future<int> remainingFrames() async {
    if (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS) {
      print("not support platform");
      return 0;
    }
    return await _channel.invokeMethod("remainingFrames", {
      "playerId": playerId,
    });
  }
}
