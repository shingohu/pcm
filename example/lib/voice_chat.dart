import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_to_airplay/flutter_to_airplay.dart';
import 'package:oktoast/oktoast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pcm/pcm.dart';
import 'package:synchronized/synchronized.dart';

class CallPage extends StatefulWidget {
  const CallPage({super.key});

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  bool isMute = false;
  bool isStart = false;

  bool get defaultToSpeaker => true;
  bool lastSpeakerOn = true;

  bool userAirPlayOnIos = true;

  @override
  void initState() {
    super.initState();
    AudioManager.externalAudioDevicesNotifier
        .addListener(onAudioDevicesChanged);
    AudioManager.currentAudioDeviceNotifier
        .addListener(onCurrentAudioDeviceChanged);
  }

  @override
  void dispose() {
    AudioManager.externalAudioDevicesNotifier
        .removeListener(onAudioDevicesChanged);
    AudioManager.currentAudioDeviceNotifier
        .removeListener(onCurrentAudioDeviceChanged);
    super.dispose();
  }

  void onAudioDevicesChanged() {
    if (isStart) {
      if (AudioManager.isWiredHeadsetOn) {
        AudioManager.setCurrentAudioDevice(AudioDeviceType.WIREDHEADSET);
      } else if (AudioManager.isBluetoothHeadsetOn) {
        AudioManager.setCurrentAudioDevice(AudioDeviceType.BLUETOOTHHEADSET);
      } else if (lastSpeakerOn) {
        AudioManager.setCurrentAudioDevice(AudioDeviceType.SPEAKER);
      } else {
        AudioManager.setCurrentAudioDevice(AudioDeviceType.EARPIECE);
      }
      setState(() {});
    }
  }

  void onCurrentAudioDeviceChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset(
              "assets/images/calling_bg.png",
              fit: BoxFit.cover,
            ),
          ),
          Scaffold(
            backgroundColor: Color(0x00000000),
            body: SafeArea(
              child: Column(
                children: [
                  SizedBox(height: 70),
                  Text("语音通话",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500)),
                  SizedBox(height: 15),
                  Expanded(child: Container()),
                  Row(
                    children: [
                      Expanded(child: micBtn()),
                      Expanded(child: startOrEndBtn()),
                      Expanded(child: audioDeviceBtn())
                    ],
                  ),
                  SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget micBtn() {
    return Visibility(
      visible: isStart,
      child: GestureDetector(
        onTap: () async {
          this.isMute = !isMute;
          setState(() {});
        },
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isMute ? Colors.grey[700] : Colors.white,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                isMute ? Icons.mic_off : Icons.mic,
                color: isMute ? Colors.white : Colors.black,
                size: 30,
              ),
            ),
            SizedBox(height: 8),
            Text(!isMute ? "麦克风已开" : "麦克风已关",
                style: TextStyle(color: Colors.white, fontSize: 13))
          ],
        ),
      ),
    );
  }

  Widget audioDeviceBtn() {
    Widget icon = Container();

    AudioDevice currentAudioDevice = AudioManager.currentAudioDevice;
    String name = "";
    if (currentAudioDevice.type == AudioDeviceType.SPEAKER) {
      name = "扬声器";
      icon = Icon(
        CupertinoIcons.speaker_2,
        color: Colors.black,
        size: 25,
      );
    } else if (currentAudioDevice.type == AudioDeviceType.WIREDHEADSET) {
      name = "耳机";
      icon = Icon(
        CupertinoIcons.headphones,
        color: Colors.black,
        size: 25,
      );
    } else if (currentAudioDevice.type == AudioDeviceType.BLUETOOTHHEADSET) {
      name = currentAudioDevice.name;
      icon = Icon(
        CupertinoIcons.bluetooth,
        color: Colors.black,
        size: 25,
      );
    } else {
      name = "听筒";
      icon = Icon(
        CupertinoIcons.ear,
        color: Colors.black,
        size: 25,
      );
    }
    return Visibility(
      visible: isStart,
      child: Container(
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (userAirPlayOnIos && Platform.isIOS)
              AirPlayRoutePickerView(
                height: 60,
                width: 60,
                tintColor: Colors.white,
                activeTintColor: Colors.white,
              ),
            IgnorePointer(
              ignoring: userAirPlayOnIos && Platform.isIOS,
              child: GestureDetector(
                onTap: () {
                  if (Platform.isAndroid || !userAirPlayOnIos) {
                    showDialog(
                        context: context,
                        builder: (ctx) {
                          return Scaffold(
                            backgroundColor: Colors.black54,
                            body: Center(child: outputAudioDeviceList()),
                          );
                        });
                  }
                },
                behavior: HitTestBehavior.deferToChild,
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(60),
                      ),
                      child: icon,
                    ),
                    SizedBox(height: 8),
                    Text(name,
                        style: TextStyle(color: Colors.white, fontSize: 13))
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget startOrEndBtn() {
    return GestureDetector(
      onTap: () {
        if (isStart) {
          endCall();
        } else {
          startCall();
        }
      },
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isStart ? Colors.red : Colors.green,
              borderRadius: BorderRadius.circular(60),
            ),
            child: Icon(
              isStart ? Icons.phone_disabled : Icons.phone,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(height: 8),
          Text(isStart ? "挂断" : "接听",
              style: TextStyle(color: Colors.white, fontSize: 13))
        ],
      ),
    );
  }

  ///音频输出设备列表
  Widget outputAudioDeviceList() {
    Widget _builtItem(String name, AudioDeviceType type) {
      bool checked = AudioManager.currentAudioDevice.type == type;
      IconData icon = CupertinoIcons.speaker_2;
      if (type == AudioDeviceType.BLUETOOTHHEADSET) {
        icon = Icons.bluetooth_audio;
      } else if (type == AudioDeviceType.WIREDHEADSET) {
        icon = Icons.headset;
      } else if (type == AudioDeviceType.SPEAKER) {
        icon = CupertinoIcons.speaker_2;
      } else {
        icon = CupertinoIcons.ear;
      }
      return GestureDetector(
        onTap: () {
          Navigator.of(context).pop();
          if (type == AudioDeviceType.EARPIECE) {
            lastSpeakerOn = false;
          } else if (type == AudioDeviceType.SPEAKER) {
            lastSpeakerOn = true;
          }
          AudioManager.setCurrentAudioDevice(type);
        },
        behavior: HitTestBehavior.translucent,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Icon(
                icon,
                color: Colors.black,
                size: 25,
              ),
              SizedBox(width: 10),
              Text(
                name,
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              Expanded(child: Container()),
              if (checked) Icon(Icons.check, color: Colors.green)
            ],
          ),
        ),
      );
    }

    List<Widget> children = [];

    if (AudioManager.isWiredHeadsetOn) {
      children.add(_builtItem("扬声器", AudioDeviceType.SPEAKER));
      children.add(Container(color: Colors.grey[400], height: 0.2));
      children.add(_builtItem("耳机", AudioDeviceType.WIREDHEADSET));
    } else if (AudioManager.isBluetoothHeadsetOn) {
      children.add(_builtItem("扬声器", AudioDeviceType.SPEAKER));
      children.add(Container(color: Colors.grey[400], height: 0.2));
      children.add(_builtItem("听筒", AudioDeviceType.EARPIECE));
      children.add(Container(color: Colors.grey[400], height: 0.2));
      children.add(_builtItem(AudioManager.bluetoothHeadsetName ?? "蓝牙",
          AudioDeviceType.BLUETOOTHHEADSET));
    } else {
      children.add(_builtItem("扬声器", AudioDeviceType.SPEAKER));
      children.add(Container(color: Colors.grey[400], height: 0.2));
      children.add(_builtItem("听筒", AudioDeviceType.EARPIECE));
    }

    return Container(
        margin: EdgeInsets.symmetric(horizontal: 25),
        padding: EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
            color: Colors.grey[300], borderRadius: BorderRadius.circular(15)),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 10),
              Text("选择设备", style: TextStyle(color: Colors.black, fontSize: 20)),
              SizedBox(height: 10),
              Column(
                children: children,
              ),
              Center(
                child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      "取消",
                      style: TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 18,
                          fontWeight: FontWeight.w600),
                    )),
              )
            ]));
  }

  Future<void> startCall() async {
    bool hasPermission = await PCMRecorder.requestRecordPermission();
    if (hasPermission) {
      await AudioManager.startVoiceChatMode(defaultToSpeaker: defaultToSpeaker);
      PCMRecorder.start(onData: (audio) {
        if (audio != null) {
          if (!isMute) {
            PCMPlayer.start(audio);
          }
        }
      });
      this.isStart = true;
      setState(() {});
    } else {
      showToast("没有录音权限");
    }
  }

  Future<void> endCall() async {
    await PCMRecorder.stop();
    await PCMPlayer.stop();
    AudioManager.endVoiceChatMode();
    this.isStart = false;
    this.isMute = false;
    this.lastSpeakerOn = defaultToSpeaker;
    setState(() {});
  }
}
