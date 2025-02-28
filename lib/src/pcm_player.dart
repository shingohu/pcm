import 'dart:io';

import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

export 'dart:typed_data';

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

  bool _playingFail = false;

  PCMPlayer(
      {String? playerId,
      int sampleRateInHz = 8000,
      AudioStreamType streamType = AudioStreamType.music})
      : playerId = playerId ?? _uuid.v4() {
    setUp(sampleRateInHz: sampleRateInHz, streamType: streamType);
  }

  String _threeDigits(int n) {
    if (n >= 100) return "${n}";
    if (n >= 10) return "0${n}";
    return "00${n}";
  }

  String _twoDigits(int n) {
    if (n >= 10) return "${n}";
    return "0${n}";
  }

  void _printLog(String message) {
    if (enableLog) {
      DateTime now = DateTime.now();
      String h = _twoDigits(now.hour);
      String min = _twoDigits(now.minute);
      String sec = _twoDigits(now.second);
      String ms = _threeDigits(now.millisecond);

      String time = "$h:$min:$sec.$ms";
      print("[PCMPlayer][$time]" + message);
    }
  }

  bool _supportPlatform() {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  ///初始化播放器
  ///[sampleRateInHz]采样率
  ///[streamType] the type of the audio stream [only android]
  Future<void> setUp({
    int sampleRateInHz = 8000,
    AudioStreamType streamType = AudioStreamType.music,
  }) async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    _dispose = false;
    _playingFail = false;
    _sampleRateInHz = sampleRateInHz;
    _printLog("初始化播放器,采样率$sampleRateInHz");
    return _channel.invokeMethod("setUpPlayer", {
      "sampleRateInHz": sampleRateInHz,
      "playerId": playerId,
      "streamType": streamType.value,
    });
  }

  ///开始播放
  Future<void> play() async {
    if (!_supportPlatform()) {
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
      if (await isPlaying) {
        return;
      }
    }

    _isPlayingNow = true;
    _isPlayingNow = await _channel.invokeMethod<bool>("startPlaying", {
          "playerId": playerId,
        }) ??
        false;
    if (_isPlayingNow) {
      _playingFail = false;
      _printLog("开始播放");
    } else {
      if (!_playingFail) {
        _playingFail = true;
        _printLog("播放失败");
      }
    }
  }

  /**
   * 以Stream方式持续播放PCM数据
   */
  Future<void> feed(Uint8List data) async {
    if (!_supportPlatform()) {
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
    if (!_supportPlatform()) {
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
    _playingFail = false;
    await _channel.invokeMethod("pausePlaying", {
      "playerId": playerId,
    });
  }

  ///结束播放(销毁播放器)
  Future<void> release() async {
    if (!_supportPlatform()) {
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
    _playingFail = false;
    _isPlayingNow = false;
    await _channel.invokeMethod("stopPlaying", {
      "playerId": playerId,
    });
  }

  ///清空播放数据
  Future<void> clear() async {
    if (!_supportPlatform()) {
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
    if (!_supportPlatform()) {
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
    if (!_supportPlatform()) {
      print("not support platform");
      return 0;
    }
    return await _channel.invokeMethod("remainingFrames", {
      "playerId": playerId,
    });
  }
}
