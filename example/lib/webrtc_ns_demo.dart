import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';
import 'package:webrtc_ns/webrtc_ns.dart';

///webrct ns demo
///可以在使用MIC录音并带耳机(有线)的情况下,感受降噪和不降噪的区别
class WebrtcNSDemoPage extends StatefulWidget {
  const WebrtcNSDemoPage({super.key});

  @override
  State<WebrtcNSDemoPage> createState() => _WebrtcNSDemoPageState();
}

class _WebrtcNSDemoPageState extends State<WebrtcNSDemoPage> {
  WebrtcNS webrtcNS = WebrtcNS();

  List<int> audios = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    webrtcNS.release();
    PCMRecorder.stop();
    PCMPlayer.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("降噪测试"),
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
                            webrtcNS.process(Uint8List.fromList(audios))),
                        voiceCall: false);
                  }
                },
                child: Text("降噪播放")),
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
      webrtcNS.init(8000, level: NSLevel.VeryHigh);
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
    if (Platform.isAndroid) {
      AudioManager.setAudioModeNormal();
    }
  }

  Future<void> stopRecord() async {
    await PCMRecorder.stop();
    await PCMPlayer.stop();
    await abandonAudioFocus();
  }
}
