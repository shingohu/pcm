import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'hotrestart.dart';

final _InnerPCMRecorder PCMRecorder = _InnerPCMRecorder._();

const _channel = const MethodChannel('com.lianke.pcm');

class _InnerPCMRecorder {
  final _streamChannel = const EventChannel('com.lianke.pcm.stream');

  Stream<Uint8List?>? _pcmStream;
  Function(Uint8List?)? _onAudioCallback;

  bool isRecordingNow = false;
  Completer? _stopCompleter;

  Stopwatch _startWatch = Stopwatch();
  Stopwatch _stopWatch = Stopwatch();

  ///是否打印日志(debug模式下默认打开)
  bool _enableLog = kDebugMode;

  ///是否开启打印日志
  void enableLog(bool enable) {
    _enableLog = enable;
  }

  void _printLog(String message) {
    if (_enableLog) {
      print("[${DateTime.now().toString().substring(0, 23)}][PCMRecorder]" + message);
    }
  }

  _InnerPCMRecorder._() {
    if (_supportPlatform()) {
      _pcmStream = _streamChannel.receiveBroadcastStream().map((buffer) => buffer as Uint8List?);
      _pcmStream?.listen((data) {
        _audioListener(data);
      });
    }
  }

  bool _supportPlatform() {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS;
  }

  /**
   * 开始录音
   * [sampleRateInHz] 录音采样率
   * [preFrameSize]每次获取回调数据大小
   * [echoCancel]是否开启回音消除(设备支持的情况下),开启后录音可能会被影响
   * Android上开启回声消除使用VOICE_COMMUNICATION录音
   * iOS开启后会导致启动MIC变慢,并且音量变小(这个时候对应的PCMPlayer也需要开启回声消除配置),销毁也会耗时,并且Options也会变更,会导致移除配置的BluetoothA2dp,mode也会变成VoiceChat
   * [autoGain]是否开启自动增益(设备支持的情况下),only android,开启后录音音量可能会被影响
   * [noiseSuppress]是否开启降噪(设备支持的情况下)，only android,开启后录音音量可能会被影响
   * [onData] 音频数据回调
   */
  Future<bool> start(
      {int sampleRateInHz = 8000,
      int preFrameSize = 320,
      bool echoCancel = false,
      bool autoGain = false,
      bool noiseSuppress = false,
      Function(Uint8List?)? onData}) async {
    if (isRecordingNow) {
      if (await isRecording) {
        _printLog("正在录音中");
        return true;
      }
    }
    this._onAudioCallback = onData;
    bool success = false;
    if (_supportPlatform()) {
      _startWatch.reset();
      _startWatch.start();
      success = (await _invokeMethod("startRecording", {
            "sampleRateInHz": sampleRateInHz,
            "preFrameSize": preFrameSize,
            "enableAEC": echoCancel,
            "autoGain": autoGain,
            "noiseSuppress": noiseSuppress,
          })) ??
          false;
    } else {
      print("not support platform");
      return false;
    }

    if (!success) {
      _printLog("录音失败");
      this.isRecordingNow = false;
      _stopCompleter = null;
      return false;
    } else {
      _startWatch.stop();
      _printLog("开始录音(${_startWatch.elapsedMilliseconds}ms)");
      this.isRecordingNow = true;
      if (_stopCompleter == null) {
        _stopCompleter = Completer();
      }
    }
    return success;
  }

  void _audioListener(Uint8List? data) {
    _onAudioCallback?.call(data);
    if (data == null) {
      isRecordingNow = false;
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopWatch.stop();
        _printLog("结束录音(${_stopWatch.elapsedMilliseconds}ms)");
        _stopCompleter?.complete();
      }
    } else {
      isRecordingNow = true;
    }
  }

  ///是否正在录音
  Future<bool> get isRecording async {
    if (_supportPlatform()) {
      return (await _invokeMethod("isRecording")) ?? false;
    }
    return false;
  }

  ///停止录音
  Future<void> stop() async {
    if (_supportPlatform()) {
      _stopWatch.reset();
      _stopWatch.start();
      await _invokeMethod("stopRecording");
    }
    if (_stopCompleter != null) {
      await _stopCompleter!.future;
      _stopCompleter = null;
    }
    isRecordingNow = false;
  }

  ///请求录音权限
  Future<bool> requestRecordPermission() async {
    if (_supportPlatform()) {
      return (await _invokeMethod<bool>("requestRecordPermission")) ?? false;
    }
    return false;
  }

  ///检查录音权限
  Future<bool> checkRecordPermission() async {
    if (_supportPlatform()) {
      return (await _invokeMethod<bool>("checkRecordPermission")) ?? false;
    }
    return false;
  }

  ///设置录音首选设备
  ///only android
  Future<void> setPreferredDevice(int deviceId) async {
    if (Platform.isAndroid) {
      return _invokeMethod("setRecordPreferredDevice", {"deviceId": deviceId});
    }
  }

  Future<T?> _invokeMethod<T>(
    String method, [
    dynamic arguments,
  ]) async {
    if (kDebugMode) {
      await hotRestart();
    }
    return await _channel.invokeMethod<T>(method, arguments);
  }
}
