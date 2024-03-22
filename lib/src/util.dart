import 'package:flutter/services.dart';

final _channel = const MethodChannel('pcm/util');

Future<void> pcm2wav(
    {required String pcmPath,
    required String wavPath,
    int sampleRateInHz = 8000}) async {
  return _channel.invokeMethod("pcm2wav", {
    "pcmPath": pcmPath,
    "wavPath": wavPath,
    "sampleRateInHz": sampleRateInHz
  });
}


Future<void> adpcm2wav(
    {required String adpcmPath,
      required String wavPath,
      int sampleRateInHz = 8000}) async {
  return _channel.invokeMethod("adpcm2wav", {
    "adpcmPath": adpcmPath,
    "wavPath": wavPath,
    "sampleRateInHz": sampleRateInHz
  });
}
