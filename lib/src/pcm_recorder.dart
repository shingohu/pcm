import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

final _InnerPCMRecorder PCMRecorder = _InnerPCMRecorder._();

enum AudioSource {
  MIC(1),
  VOICE_COMMUNICATION(7);

  const AudioSource(this.value);

  final int value;
}

class _InnerPCMRecorder {
  final _channel = const MethodChannel('pcm/recorder');
  final _streamChannel = const EventChannel('pcm/stream');

  late Stream<Uint8List?> _pcmStream;
  Function(Uint8List?)? _onAudioCallback;

  bool isRecordingNow = false;
  Completer? _stopCompleter;

  /**
   * 开始录音
   * [sampleRateInHz] 录音频率
   * [preFrameSize]回调数据大小
   * [audioSource]音源选择(android有用)
   * [onData] 音频数据回调
   */
  Future<bool> start(
      {int sampleRateInHz = 8000,
      int preFrameSize = 320,
      AudioSource audioSource = AudioSource.VOICE_COMMUNICATION,
      Function(Uint8List?)? onData}) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    this._onAudioCallback = onData;
    this.isRecordingNow = true;
    bool success = await _channel.invokeMethod("startRecording", {
      "sampleRateInHz": sampleRateInHz,
      "preFrameSize": preFrameSize,
      "audioSource": audioSource.value,
    });
    if (!success) {
      this.isRecordingNow = false;
      _stopCompleter = null;
    } else {
      if (_stopCompleter == null) {
        _stopCompleter = Completer();
      }
    }
    return success;
  }

  _InnerPCMRecorder._() {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    _pcmStream = _streamChannel
        .receiveBroadcastStream()
        .map((buffer) => buffer as Uint8List?);

    _pcmStream.listen((data) {
      if (data == null) {
        isRecordingNow = false;
        if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
          _stopCompleter?.complete();
          _stopCompleter = null;
        }
      } else {
        isRecordingNow = true;
      }
      _onAudioCallback?.call(data);
    });
  }

  ///是否正在录音
  Future<bool> get isRecording async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    bool success = await _channel.invokeMethod("isRecording");
    return success;
  }

  ///停止录音(不销毁录音器)
  Future<void> stop() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod("stopRecording");
    if (_stopCompleter != null) {
      await _stopCompleter!.future;
      _stopCompleter = null;
    }
    isRecordingNow = false;
  }

  Future<bool> requestRecordPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("requestRecordPermission");
  }

  Future<bool> checkRecordPermission() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("checkRecordPermission");
  }
}
