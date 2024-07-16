import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';
import 'package:webrtc_agc/webrtc_agc.dart';

///webrct agc demo
class WebrtcAGCDemoPage extends StatefulWidget {
  const WebrtcAGCDemoPage({super.key});

  @override
  State<WebrtcAGCDemoPage> createState() => _WebrtcAGCDemoPageState();
}

class _WebrtcAGCDemoPageState extends State<WebrtcAGCDemoPage> {
  WebrtcAgc webrtcAgc = WebrtcAgc();

  List<int> audios = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    webrtcAgc.release();
    PCMRecorder.stop();
    PCMPlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("自动增益测试"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
                onPressed: () {
                  startRecord();
                },
                child: Text("开始录音")),
            TextButton(
                onPressed: () {
                  stopRecord();
                },
                child: Text("结束录音")),
            TextButton(
                onPressed: () async {
                  await PCMPlayer.stop();
                  if (audios.length > 0) {
                    PCMPlayer.play(Uint8List.fromList(audios),
                        voiceCall: false);
                  }
                },
                child: Text("原生播放")),
            TextButton(
                onPressed: () async {
                  await PCMPlayer.stop();

                  if (audios.length > 0) {
                    PCMPlayer.play(
                        Uint8List.fromList(
                            webrtcAgc.process(Uint8List.fromList(audios))),
                        voiceCall: false);
                  }
                },
                child: Text("增益播放")),
          ],
        ),
      ),
    );
  }

  Future<void> startRecord() async {
    bool hasPermission = await PCMRecorder.requestRecordPermission();
    if (hasPermission) {
      await stopRecord();
      await requestAudioFocus();
      audios.clear();
      webrtcAgc.init(8000);
      webrtcAgc.setConfig(targetLevelDBFS: 3, compressionGainDB: 20);
      PCMRecorder.start(
          preFrameSize: 960,
          audioSource: AudioSource.MIC,
          onData: (audio) async {
            if (audio != null) {
              audios.addAll(audio);
            }
          });
    } else {
      showToast("没有录音权限");
    }
  }

  Future<void> requestAudioFocus() async {
    if (Platform.isIOS) {
      await AudioManager.setPlayAndRecordSession(defaultToSpeaker: true);
    }
  }

  Future<void> abandonAudioFocus() async {
    AudioManager.abandonAudioFocus();
  }

  Future<void> stopRecord() async {
    await PCMRecorder.stop();
    await PCMPlayer.stop();
    await abandonAudioFocus();
  }
}
