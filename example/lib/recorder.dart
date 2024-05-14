import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

import 'audio_mixer.dart';

class RecorderPage extends StatefulWidget {
  const RecorderPage({super.key});

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  Map<String, List<Uint8List>> _speakerAudioBufferMap = {};
  String userId = "1";

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
                  userId = DateTime.now().millisecondsSinceEpoch.toString();
                  startRecord();
                },
                child: Text("开始录音")),
            TextButton(
                onPressed: () {
                  stopRecord();
                },
                child: Text("结束录音")),
            TextButton(
                onPressed: () {
                  startPlay();
                },
                child: Text("开始播放")),
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
              // PCMPlayer.start(Uint8List(640));
              // audioList.add(audio);

              if (!_speakerAudioBufferMap.containsKey(userId)) {
                _speakerAudioBufferMap[userId] = [];
              }
              _speakerAudioBufferMap[userId]!.add(audio);
            }
          });
      setState(() {});
    } else {
      showToast("没有录音权限");
    }
  }

  Future<void> stopRecord() async {
    await PCMRecorder.stop();
  }

  Future<void> endPlay() async {
    _playingSpeakTimer?.cancel();
    _playingSpeakTimer = null;
    _speakerAudioBufferMap.clear();
    await PCMPlayer.stop();
    AudioManager.endVoiceChatMode();
    audioList.clear();

    setState(() {});
  }

  Future<void> startPlay() async {
    _startPlayingSpeak();

    // PCMPlayer.start(
    //     Uint8List.fromList(audioList.expand((element) => element).toList()));
    // audioList.clear();
  }

  Uint8List? _mixAudioData() {
    List<Uint8List> audioList = [];
    for (int i = 0; i < _speakerAudioBufferMap.values.length; i++) {
      List<Uint8List> temp = _speakerAudioBufferMap.values.elementAt(i);
      if (temp.length > 0) {
        audioList.add(temp.first);
        temp.removeAt(0);
      }
    }
    return AudioMixer.mix(audioList);
  }

  Timer? _playingSpeakTimer;

  ///开始播放语音
  void _startPlayingSpeak() {
    if (_playingSpeakTimer == null) {
      ///每隔30S取一次数据
      _playingSpeakTimer = Timer.periodic(Duration(milliseconds: 10), (timer) {
        Uint8List? audio = _mixAudioData();
        if (audio != null) {
          PCMPlayer.start(audio);
        }
      });
    }
  }
}
