import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  @override
  void initState() {
    AudioManager.currentAudioDeviceNotifier.addListener(() {});
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("录音"),
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
                child: Text("结束录音并播放")),
            TextButton(
                onPressed: () {
                  endPlay();
                },
                child: Text("结束播放")),
            TextButton(
                onPressed: () {
                  FlutterVolumeController.setVolume(1,
                      stream: AudioStream.voiceCall);
                },
                child: Text("调整音量")),
          ],
        ),
      ),
    );
  }

  List<Uint8List> audioList = [];

  Future<void> startRecord() async {
    bool hasPermission = await PCMRecorder.requestRecordPermission();
    if (hasPermission) {
      AudioManager.startVoiceChatMode(defaultToSpeaker: true);
      PCMRecorder.start(
          preFrameSize: 640,
          onData: (audio) {
            if (audio != null) {
              ///部分手机蓝牙录音的时候需要开启播放才可以收音
              PCMPlayer.start(Uint8List(640));
              audioList.add(audio);
            }
          });
      setState(() {});
    } else {
      showToast("没有录音权限");
    }
  }

  Future<void> stopRecord() async {
    await PCMRecorder.stop();
    startPlay();
  }

  Future<void> endPlay() async {
    await PCMPlayer.stop();
    AudioManager.endVoiceChatMode();
    audioList.clear();
    setState(() {});
  }

  Future<void> startPlay() async {
    PCMPlayer.start(
        Uint8List.fromList(audioList.expand((element) => element).toList()));
    audioList.clear();
  }
}
