import 'package:flutter/services.dart';
import 'dart:io';
final _channel = const MethodChannel('pcm/util');

Future<void> pcm2wav({required String pcmPath,
  required String wavPath,
  int sampleRateInHz = 8000}) async {
  if (!Platform.isIOS && Platform.isAndroid) {
    return;
  }
  return _channel.invokeMethod("pcm2wav", {
    "pcmPath": pcmPath,
    "wavPath": wavPath,
    "sampleRateInHz": sampleRateInHz
  });
}


Future<void> adpcm2wav({required String adpcmPath,
  required String wavPath,
  int sampleRateInHz = 8000}) async {
  if (!Platform.isIOS && Platform.isAndroid) {
    return;
  }
  return _channel.invokeMethod("adpcm2wav", {
    "adpcmPath": adpcmPath,
    "wavPath": wavPath,
    "sampleRateInHz": sampleRateInHz
  });
}
