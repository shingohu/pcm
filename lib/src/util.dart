import 'dart:io';

import 'package:flutter/services.dart';

final _channel = const MethodChannel('pcm/util');

class PCMUtil {
  static Future<void> pcm2wav(
      {required String pcmPath,
      required String wavPath,
      int sampleRateInHz = 8000}) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    return _channel.invokeMethod("pcm2wav", {
      "pcmPath": pcmPath,
      "wavPath": wavPath,
      "sampleRateInHz": sampleRateInHz
    });
  }

  static Future<void> adpcm2wav(
      {required String adpcmPath,
      required String wavPath,
      int sampleRateInHz = 8000}) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    return _channel.invokeMethod("adpcm2wav", {
      "adpcmPath": adpcmPath,
      "wavPath": wavPath,
      "sampleRateInHz": sampleRateInHz
    });
  }

  ///开启或者关闭日志
  static Future<void> enableLog({
    required bool enableLog,
  }) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    return _channel.invokeMethod("enableLog", {
      "enableLog": enableLog,
    });
  }
}
