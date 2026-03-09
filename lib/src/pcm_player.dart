import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hotrestart.dart';
import 'simple_lock.dart';

export 'dart:typed_data';

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

  String get playerId => hashCode.toString();

  SimpleLock _lock = SimpleLock();

  ///是否已经销毁
  bool get isDispose {
    if (_dispose) {
      _cachedPlayers.remove(this);
    }
    return _dispose;
  }

  ///是否已经销毁
  bool _dispose = false;

  ///播放失败标记(iOS上有可能失败)
  bool _playingFail = false;
  Stopwatch _stopwatch = Stopwatch();
  Stopwatch _startwatch = Stopwatch();

  ///是否打印日志(debug模式下默认打开)
  bool _enableLog = kDebugMode;

  ///是否开启打印日志
  void enableLog(bool enable) {
    _enableLog = enable;
  }

  ///全部创建的播放器
  static List<PCMPlayer> _cachedPlayers = [];

  ///全部创建的播放器
  static List<PCMPlayer> get all => _cachedPlayers;

  ///销毁全部的播放器
  static void releaseAll() async {
    for (PCMPlayer player in _cachedPlayers) {
      player.release();
    }
  }

  PCMPlayer({int sampleRateInHz = 8000, bool enableAEC = false, AudioStreamType streamType = AudioStreamType.music}) {
    _setUp(sampleRateInHz: sampleRateInHz, streamType: streamType, enableAEC: enableAEC);
    _cachedPlayers.add(this);
  }

  void _printLog(String message) {
    if (_enableLog) {
      print("[PCMPlayer][${DateTime.now().toString().substring(0, 23).split(" ").last}]" + message);
    }
  }

  bool _supportPlatform() {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  ///初始化播放器
  ///[sampleRateInHz]采样率
  ///[streamType] the type of the audio stream [only android]
  ///[enableAEC]iOS是否设置回音消除的subType [only iOS]
  Future<void> _setUp({
    int sampleRateInHz = 8000,
    AudioStreamType streamType = AudioStreamType.music,
    bool enableAEC = false,
  }) async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      await _invokeMethod("setUpPlayer", {
        "sampleRateInHz": sampleRateInHz,
        "playerId": playerId,
        "streamType": streamType.value,
        "enableAEC": enableAEC,
      });
      _printLog("初始化播放器,采样率$sampleRateInHz");
    });
  }

  ///开始播放
  Future<void> play() async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已销毁");
        return;
      }
      if (_isPlayingNow) {
        return;
      }
      _startwatch.reset();
      _startwatch.start();
      _isPlayingNow = true;
      _isPlayingNow = await _invokeMethod<bool>("startPlaying", {
            "playerId": playerId,
          }) ??
          false;
      if (_isPlayingNow) {
        _playingFail = false;
        _startwatch.stop();
        _printLog("开始播放(${_startwatch.elapsedMilliseconds}ms)");
      } else {
        if (!_playingFail) {
          _playingFail = true;
          _printLog("播放失败");
        }
      }
    });
  }

  /**
   * 以Stream方式持续播放PCM数据
   */
  Future<void> feed(Uint8List data) async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已销毁");
        return;
      }
      return _invokeMethod("feedPlaying", {
        "data": data,
        "playerId": playerId,
      });
    });
  }

  ///停止播放(不销毁播放器)
  Future<void> stop() async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已销毁");
        return;
      }
      if (!_isPlayingNow && !_playingFail) {
        return;
      }
      _playingFail = false;
      bool printStop = _isPlayingNow;
      _stopwatch.reset();
      _stopwatch.start();
      _isPlayingNow = false;
      await _invokeMethod("pausePlaying", {
        "playerId": playerId,
      });
      if (printStop) {
        _stopwatch.stop();
        _printLog("结束播放(${_stopwatch.elapsedMilliseconds}ms)");
      }
    });
  }

  ///结束播放(销毁播放器)
  Future<void> release() async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已销毁");
        return;
      }
      bool printStop = _isPlayingNow;
      _stopwatch.reset();
      _stopwatch.start();
      _dispose = true;
      _isPlayingNow = false;
      await _invokeMethod("stopPlaying", {
        "playerId": playerId,
      });
      _cachedPlayers.remove(this);
      if (printStop) {
        _stopwatch.stop();
        _printLog("结束播放(${_stopwatch.elapsedMilliseconds}ms)");
      }
      _printLog("销毁播放器");
    });
  }

  ///清空播放数据
  Future<void> clear() async {
    if (!_supportPlatform()) {
      print("not support platform");
      return;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已经销毁");
        return;
      }
      await _invokeMethod("clearPlaying", {
        "playerId": playerId,
      });
    });
  }

  ///是否正在播放
  Future<bool> get isPlaying async {
    if (!_supportPlatform()) {
      print("not support platform");
      return false;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已经销毁");
        return false;
      }
      return await _invokeMethod("isPlaying", {
        "playerId": playerId,
      });
    });
  }

  ///剩余播放帧长度
  Future<int> remainingFrames() async {
    if (!_supportPlatform()) {
      print("not support platform");
      return 0;
    }
    return _lock.synchronized(() async {
      if (isDispose) {
        _printLog("播放器已经销毁");
        return 0;
      }
      int remain = await _invokeMethod("remainingFrames", {
        "playerId": playerId,
      });
      if (isDispose) {
        remain = 0;
      }
      return remain;
    });
  }

  ///设置播放首选设备 only android
  ///[deviceId] 要设置的音频设备id 为0表示切换到默认设备上
  static Future<void> setPreferredDevice(int deviceId) async {
    if (Platform.isAndroid) {
      return await _invokeMethod("setPlayPreferredDevice", {"deviceId": deviceId});
    }
  }

  static Future<T?> _invokeMethod<T>(
    String method, [
    dynamic arguments,
  ]) async {
    if (kDebugMode) {
      await hotRestart();
    }
    return await _channel.invokeMethod<T>(method, arguments);
  }
}
