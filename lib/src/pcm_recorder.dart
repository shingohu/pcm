import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pcm/pcm.dart';
import 'package:record/record.dart';

final _InnerPCMRecorder PCMRecorder = _InnerPCMRecorder._();

const _channel = const MethodChannel('com.lianke.pcm');

class _InnerPCMRecorder {
  final _streamChannel = const EventChannel('com.lianke.pcm.stream');

  Stream<Uint8List?>? _pcmStream;
  Function(Uint8List?)? _onAudioCallback;

  bool isRecordingNow = false;
  Completer? _stopCompleter;

  final _otherPlatformRecorder = AudioRecorder();

  ///移动平台是否使用第三方record库进行录音 默认不使用
  bool _useRecordOnPhonePlatform = false;

  ///设置移动平台是否使用第三方record库进行录音
  void useRecordOnMobilePlatform(bool use) {
    _useRecordOnPhonePlatform = use;
  }

  /**
   * 开始录音
   * [sampleRateInHz] 录音采样率
   * [preFrameSize]每次获取回调数据大小
   * [echoCancel]是否开启回音消除(设备支持的情况下),开启后录音可能会被影响
   * Android上开启回声消除使用VOICE_COMMUNICATION录音,iOS开启后会导致启动MIC变慢
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
    this._onAudioCallback = onData;

    if (Platform.isWindows || Platform.isMacOS || _useRecordOnPhonePlatform) {
      List<int> audios = [];
      Completer<bool>? _startCompleter = Completer();
      (await _otherPlatformRecorder.startStream(RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              echoCancel: echoCancel,
              sampleRate: sampleRateInHz,
              numChannels: 1,
              autoGain: autoGain,
              noiseSuppress: noiseSuppress)))
          .listen((data) {
        if (_startCompleter != null && !_startCompleter.isCompleted) {
          PCMLib.log("开始录音");
          _startCompleter.complete(true);
        }
        audios.addAll(data.toList());
        while (audios.length >= preFrameSize) {
          Uint8List pcmData =
              Uint8List.fromList(audios.sublist(0, preFrameSize));
          audios.removeRange(0, preFrameSize);
          _audioListener(pcmData);
        }
      }, onDone: () {
        if (audios.length > 0) {
          for (int i = audios.length; i < preFrameSize; i++) {
            audios.add(0);
          }
          _audioListener(Uint8List.fromList(audios));
        }
        _audioListener(null);
        PCMLib.log("结束录音");
      }, onError: (e) {
        print(e);
        if (_startCompleter != null) {
          _startCompleter.complete(false);
        }
      });
      bool success = await _startCompleter.future;
      _startCompleter = null;
      if (!success) {
        this.isRecordingNow = false;
        _stopCompleter = null;
        return false;
      } else {
        this.isRecordingNow = true;
        if (_stopCompleter == null) {
          _stopCompleter = Completer();
        }
      }
      return success;
    }

    if ((Platform.isAndroid || Platform.isIOS)) {
      bool success = await _channel.invokeMethod("startRecording", {
        "sampleRateInHz": sampleRateInHz,
        "preFrameSize": preFrameSize,
        "enableAEC": echoCancel,
        "autoGain": autoGain,
        "noiseSuppress": noiseSuppress,
      });
      if (!success) {
        this.isRecordingNow = false;
        _stopCompleter = null;
        return false;
      } else {
        this.isRecordingNow = true;
        if (_stopCompleter == null) {
          _stopCompleter = Completer();
        }
      }
      return false;
    }

    return false;
  }

  _InnerPCMRecorder._() {
    if (Platform.isIOS || Platform.isAndroid) {
      _pcmStream = _streamChannel
          .receiveBroadcastStream()
          .map((buffer) => buffer as Uint8List?);
      _pcmStream?.listen((data) {
        _audioListener(data);
      });
    }
  }

  void _audioListener(Uint8List? data) {
    _onAudioCallback?.call(data);
    if (data == null) {
      isRecordingNow = false;
      if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
        _stopCompleter?.complete();
        _stopCompleter = null;
      }
    } else {
      isRecordingNow = true;
    }
  }

  ///是否正在录音
  Future<bool> get isRecording async {
    if (Platform.isWindows || Platform.isMacOS || _useRecordOnPhonePlatform) {
      return await _otherPlatformRecorder.isRecording();
    }
    if (Platform.isIOS || Platform.isAndroid) {
      return await _channel.invokeMethod("isRecording");
    }
    return false;
  }

  ///停止录音
  Future<void> stop() async {
    if (Platform.isWindows || Platform.isMacOS || _useRecordOnPhonePlatform) {
      await _otherPlatformRecorder.stop();
    } else if (Platform.isIOS || Platform.isAndroid) {
      await _channel.invokeMethod("stopRecording");
    }
    if (_stopCompleter != null) {
      await _stopCompleter!.future;
      _stopCompleter = null;
    }
    isRecordingNow = false;
  }

  ///请求录音权限
  Future<bool> requestRecordPermission() async {
    if (Platform.isWindows || Platform.isMacOS || _useRecordOnPhonePlatform) {
      return await _otherPlatformRecorder.hasPermission();
    }
    if (Platform.isIOS || Platform.isAndroid) {
      return await _channel.invokeMethod("requestRecordPermission");
    }
    return false;
  }

  ///检查录音权限
  Future<bool> checkRecordPermission() async {
    if (Platform.isIOS || Platform.isAndroid) {
      return await _channel.invokeMethod("checkRecordPermission");
    } else if (Platform.isWindows || Platform.isMacOS) {
      return await _otherPlatformRecorder.hasPermission();
    }
    return false;
  }
}
