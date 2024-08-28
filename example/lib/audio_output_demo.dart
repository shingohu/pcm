import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

///音频输出设备demo
class AudioOutputDemoPage extends StatefulWidget {
  const AudioOutputDemoPage({super.key});

  @override
  State<AudioOutputDemoPage> createState() => _AudioOutputDemoPageState();
}

class _AudioOutputDemoPageState extends State<AudioOutputDemoPage> {
  @override
  void initState() {
    AudioManager.currentAudioDeviceNotifier
        .addListener(onCurrentAudioDeviceChanged);
    AudioManager.audioDevicesNotifier.addListener(onAudioDevicesChanged);
    AudioManager.bluetoothScoStateNotifier
        .addListener(onBluetoothSCOStateChanged);
    super.initState();
  }

  void onCurrentAudioDeviceChanged() {
    print("当前输出变更为->${AudioManager.currentAudioDevice.type}");
    isChangeAudioDevice = true;
    changeAudioDeviceTimer?.cancel();
    changeAudioDeviceTimer = Timer(Duration(milliseconds: 200), () {
      isChangeAudioDevice = false;
    });
    if (PCMPlayer.isPlayingNow) {
      Future.delayed(Duration(milliseconds: 100), () async {
        int remain = await PCMPlayer.remainingFrames();
        if (remain > 1600) {
          PCMPlayer.clear();
        }
      });
    }
  }

  bool isChangeAudioDevice = false;
  Timer? changeAudioDeviceTimer;

  void onAudioDevicesChanged() {
    print("音频输出设备变更");
    print(AudioManager.audioDevices
        .map((e) {
          return {"name": e.name, "type": e.type.name};
        })
        .toList()
        .toString());
    if (PCMPlayer.isPlayingNow) {
      setAudioDevice();
    }
  }

  void onBluetoothSCOStateChanged() {
    if (PCMPlayer.isPlayingNow) {
      if (AudioManager.bluetoothScoState == BluetoothScoState.DISCONNECTED ||
          AudioManager.bluetoothScoState == BluetoothScoState.ERROR) {
        if (AudioManager.currentAudioDevice.type ==
            AudioDeviceType.BLUETOOTHHEADSET) {
          if (AudioManager.isWiredHeadsetOn) {
            AudioManager.setCurrentAudioDevice(AudioDeviceType.WIREDHEADSET);
          } else if (AudioManager.isBluetoothA2dpOn) {
            AudioManager.setCurrentAudioDevice(AudioDeviceType.BLUETOOTHA2DP);
          } else {
            AudioManager.setCurrentAudioDevice(AudioDeviceType.SPEAKER);
          }
        }
      }
    }
  }

  @override
  void dispose() {
    PCMRecorder.stop();
    PCMPlayer.stop();
    AudioManager.currentAudioDeviceNotifier
        .removeListener(onCurrentAudioDeviceChanged);
    AudioManager.audioDevicesNotifier.removeListener(onAudioDevicesChanged);
    AudioManager.bluetoothScoStateNotifier
        .removeListener(onBluetoothSCOStateChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("音频输出设备测试"),
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
                onPressed: () {
                  AudioManager.setCurrentAudioDevice(AudioDeviceType.SPEAKER);
                },
                child: Text("输出到扬声器")),
            TextButton(
                onPressed: () {
                  AudioManager.setCurrentAudioDevice(AudioDeviceType.EARPIECE);
                },
                child: Text("输出到听筒")),
            TextButton(
                onPressed: () {
                  if (AudioManager.isWiredHeadsetOn) {
                    AudioManager.setCurrentAudioDevice(
                        AudioDeviceType.WIREDHEADSET);
                  } else {
                    showToast("未连接有线耳机");
                  }
                },
                child: Text("输出到有线耳机")),
            TextButton(
                onPressed: () {
                  if (AudioManager.isBluetoothA2dpOn) {
                    AudioManager.setCurrentAudioDevice(
                        AudioDeviceType.BLUETOOTHA2DP);
                  } else {
                    showToast("未连接蓝牙A2DP设备");
                  }
                },
                child: Text("输出到蓝牙A2DP")),
            TextButton(
                onPressed: () {
                  if (AudioManager.isBluetoothHeadsetOn) {
                    AudioManager.setCurrentAudioDevice(
                        AudioDeviceType.BLUETOOTHHEADSET);
                  } else {
                    showToast("未连接蓝牙耳机设备");
                  }
                },
                child: Text("输出到蓝牙HFP")),
          ],
        ),
      ),
    );
  }

  Future<void> startRecord() async {
    bool hasPermission = await PCMRecorder.requestRecordPermission();
    if (hasPermission) {
      await requestAudioFocus();
      int? start = DateTime.now().millisecondsSinceEpoch;
      PCMRecorder.start(
          preFrameSize: 960,
          enableAEC: true,
          onData: (audio) async {
            if (start != null) {
              print(
                  "录音第一帧回调耗时->${DateTime.now().millisecondsSinceEpoch - start!}");
              start = null;
            }

            if (audio != null) {
              PCMPlayer.play(audio, voiceCall: true);
            }
          });
    } else {
      showToast("没有录音权限");
    }
  }

  Future<void> requestAudioFocus() async {
    if (Platform.isAndroid) {
      await AudioManager.setAudioModeInCommunication();
    } else if (Platform.isIOS) {
      await AudioManager.setPlayAndRecordSession(defaultToSpeaker: true);
    }
    if (Platform.isAndroid) {
      ///苹果不设置
      setAudioDevice();
    }
  }

  Future<void> setAudioDevice() async {
    if (AudioManager.isWiredHeadsetOn) {
      AudioManager.setCurrentAudioDevice(AudioDeviceType.WIREDHEADSET);
    } else if (AudioManager.isBluetoothHeadsetOn) {
      AudioManager.setCurrentAudioDevice(AudioDeviceType.BLUETOOTHHEADSET);
    } else if (AudioManager.isBluetoothA2dpOn) {
      AudioManager.setCurrentAudioDevice(AudioDeviceType.BLUETOOTHA2DP);
    } else {
      AudioManager.setCurrentAudioDevice(AudioDeviceType.SPEAKER);
    }
  }

  Future<void> abandonAudioFocus() async {
    AudioManager.abandonAudioFocus();
  }

  Future<void> stopRecord() async {
    await PCMRecorder.stop();
    await PCMPlayer.stop();
    await abandonAudioFocus();
    if (Platform.isAndroid) {
      await AudioManager.setAudioModeNormal();
    }
  }
}
