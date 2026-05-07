import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_recorder/flutter_recorder.dart';

import 'hotrestart.dart';

final _InnerPCMRecorder PCMRecorder = _InnerPCMRecorder._();

const _channel = const MethodChannel('com.lianke.pcm');

class _InnerPCMRecorder {
  late final _streamChannel = const EventChannel('com.lianke.pcm.stream');

  Timer? _intervalTimer;
  StreamSubscription<Uint8List?>? _pcmStreamSub;
  Function(Uint8List?)? _onAudioCallback;

  bool _isRecordingNow = false;

  bool get isRecordingNow => _isRecordingNow;
  Completer? _stopCompleter;

  Stopwatch _startWatch = Stopwatch();
  Stopwatch _stopWatch = Stopwatch();

  ///是否打印日志(debug模式下默认打开)
  bool _enableLog = kDebugMode;

  bool get _useRecorderPlugin => Platform.isWindows;

  ///是否开启打印日志
  void enableLog(bool enable) {
    _enableLog = enable;
  }

  void _printLog(String message) {
    if (_enableLog) {
      print("[PCMRecorder][${DateTime.now().toString().substring(0, 23).split(" ").last}]" + message);
    }
  }

  _InnerPCMRecorder._();

  void _addPCMStreamSubscription(int chunkBytes, Duration interval) {
    if (_pcmStreamSub == null) {
      if (_useRecorderPlugin) {
        _pcmStreamSub = _splitAudioStream(Recorder.instance.uint8ListStream.map((data) => data.rawData),
            chunkBytes: chunkBytes, interval: interval, listen: (data) {
          _audioListener(data);
        });
      } else {
        _pcmStreamSub = _streamChannel.receiveBroadcastStream().map((buffer) => buffer as Uint8List?).listen((data) {
          _audioListener(data);
        });
      }
    }
  }

  void _removePCMStreamSubscription() {
    _pcmStreamSub?.cancel();
    _pcmStreamSub = null;
    _intervalTimer?.cancel();
    _intervalTimer = null;
  }

  /// 音频流精准分割工具
  /// [source] 原始流：8k 16bit 单通道，每次4096字节
  /// [chunkBytes] 每帧固定字节数（例如 320 字节 = 20ms）
  /// [interval] 每帧固定间隔时间（例如 Duration(milliseconds: 20)）
  StreamSubscription<Uint8List> _splitAudioStream(
    Stream<Uint8List> source, {
    required int chunkBytes,
    required Duration interval,
    required Function(Uint8List) listen,
  }) {
    // 数据缓冲区
    Uint8List? buffer;
    // 定时输出触发器
    _intervalTimer?.cancel();
    _intervalTimer = Timer.periodic(interval, (timer) {
      if (buffer != null && buffer!.length >= chunkBytes) {
        // 取出固定长度 = 你要的一帧数据
        final chunk = buffer!.sublist(0, chunkBytes);
        listen(chunk);
        // 剩余数据留在缓冲区
        buffer = buffer!.sublist(chunkBytes);
      }
    });

    // 1. 监听原始流，不断拼接数据
    return source.listen(
      (data) {
        if (buffer == null) {
          buffer = data;
        } else {
          // 拼接新数据到缓冲区
          final newBuf = Uint8List(buffer!.length + data.length);
          newBuf.setAll(0, buffer!);
          newBuf.setAll(buffer!.length, data);
          buffer = newBuf;
        }
      },
      onDone: () {
        _intervalTimer?.cancel();
        _intervalTimer = null;
      },
    );
  }

  bool _supportPlatform() {
    return Platform.isIOS || Platform.isAndroid || Platform.isMacOS || Platform.isWindows;
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
    if (_isRecordingNow) {
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
      int audioBytesToMs(int totalBytes, int sampleRate, int bits, int channel) {
        int bytesPerSample = bits ~/ 8;
        double sec = totalBytes / (sampleRate * bytesPerSample * channel);
        return (sec * 1000).round();
      }

      _addPCMStreamSubscription(
          preFrameSize, Duration(milliseconds: audioBytesToMs(preFrameSize, sampleRateInHz, 16, 1)));
      if (_useRecorderPlugin) {
        try {
          await Recorder.instance.init(sampleRate: sampleRateInHz);
          Recorder.instance.startStreamingData();
          Recorder.instance.start();
          success = Recorder.instance.isDeviceStarted();
        } catch (e) {
          _printLog(e.toString());
        }
      } else {
        success = (await _invokeMethod("startRecording", {
              "sampleRateInHz": sampleRateInHz,
              "preFrameSize": preFrameSize,
              "enableAEC": echoCancel,
              "autoGain": autoGain,
              "noiseSuppress": noiseSuppress,
            })) ??
            false;
      }
    } else {
      print("not support platform");
      return false;
    }

    if (!success) {
      _printLog("录音失败");
      this._isRecordingNow = false;
      _stopCompleter = null;
      _removePCMStreamSubscription();
      return false;
    } else {
      _startWatch.stop();
      _printLog("开始录音(${_startWatch.elapsedMilliseconds}ms)");
      this._isRecordingNow = true;
      if (_stopCompleter == null) {
        _stopCompleter = Completer();
      }
    }
    return success;
  }

  void _audioListener(Uint8List? data) {
    _onAudioCallback?.call(data);
    if (data == null) {
      _isRecordingNow = false;
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopWatch.stop();
        _printLog("结束录音(${_stopWatch.elapsedMilliseconds}ms)");
        _stopCompleter?.complete();
      }
    } else {
      _isRecordingNow = true;
    }
  }

  ///是否正在录音
  Future<bool> get isRecording async {
    if (_supportPlatform()) {
      if (_useRecorderPlugin) {
        return Recorder.instance.isDeviceStarted();
      }
      return (await _invokeMethod("isRecording")) ?? false;
    }
    return false;
  }

  ///停止录音
  Future<void> stop() async {
    if (_supportPlatform()) {
      _stopWatch.reset();
      _stopWatch.start();
      if (_useRecorderPlugin) {
        bool isRecording = Recorder.instance.isDeviceStarted();
        if (isRecording) {
          Recorder.instance.stopStreamingData();
        }
        Recorder.instance.deinit();
        if (isRecording) {
          _audioListener(null);
        }
      } else {
        await _invokeMethod("stopRecording");
      }
    }
    if (_stopCompleter != null) {
      await _stopCompleter!.future;
      _stopCompleter = null;
    }
    _removePCMStreamSubscription();
    _isRecordingNow = false;
  }

  ///请求录音权限
  Future<bool> requestRecordPermission() async {
    if (Platform.isWindows || Platform.isMacOS) {
      return true;
    }
    if (_supportPlatform()) {
      return (await _invokeMethod<bool>("requestRecordPermission")) ?? false;
    }
    return false;
  }

  ///检查录音权限
  Future<bool> checkRecordPermission() async {
    if (Platform.isWindows || Platform.isMacOS) {
      return true;
    }
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
