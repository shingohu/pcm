import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

late _AudioManager AudioManager = _AudioManager._();

///android 蓝牙SCO状态
enum BluetoothScoState { DISCONNECTED, CONNECTING, CONNECTED, ERROR }

///音频输出设备
enum AudioDeviceType {
  SPEAKER,
  EARPIECE,
  WIREDHEADSET,
  BLUETOOTHHEADSET,
  BLUETOOTHA2DP
}

AudioDevice Earpiece = AudioDevice(
    name: AudioDeviceType.EARPIECE.name, type: AudioDeviceType.EARPIECE);
AudioDevice Speaker = AudioDevice(
    name: AudioDeviceType.SPEAKER.name, type: AudioDeviceType.SPEAKER);
AudioDevice WiredHeadset = AudioDevice(
    name: AudioDeviceType.WIREDHEADSET.name,
    type: AudioDeviceType.WIREDHEADSET);

class AudioDevice {
  final String name;
  final AudioDeviceType type;

  AudioDevice({required this.name, required this.type});
}

AudioDeviceType _getAudioDeviceTypeByString(String type) {
  if (type == "SPEAKER") {
    return AudioDeviceType.SPEAKER;
  }
  if (type == "EARPIECE") {
    return AudioDeviceType.EARPIECE;
  }
  if (type == "WIREDHEADSET") {
    return AudioDeviceType.WIREDHEADSET;
  }
  if (type == "BLUETOOTHHEADSET") {
    return AudioDeviceType.BLUETOOTHHEADSET;
  }
  if (type == "BLUETOOTHA2DP") {
    return AudioDeviceType.BLUETOOTHA2DP;
  }
  return AudioDeviceType.SPEAKER;
}

///音频管理
class _AudioManager {
  ///android sco 状态变更
  ValueNotifier<BluetoothScoState> bluetoothScoStateNotifier =
      ValueNotifier(BluetoothScoState.DISCONNECTED);

  ///android sco 状态
  BluetoothScoState get bluetoothScoState => bluetoothScoStateNotifier.value;

  ///外置音频输出设备变更
  ValueNotifier<List<AudioDevice>> audioDevicesNotifier = ValueNotifier([]);

  ///外置音频输出设备(不包含内置耳机和内置扬声器)
  List<AudioDevice> get audioDevices => audioDevicesNotifier.value;

  ///当前音频设备变更通知
  ValueNotifier<AudioDevice> currentAudioDeviceNotifier = ValueNotifier(
      AudioDevice(
          name: AudioDeviceType.EARPIECE.name, type: AudioDeviceType.EARPIECE));

  ///当前的输出设备
  AudioDevice get currentAudioDevice => currentAudioDeviceNotifier.value;

  ///是否连接有无线耳机
  bool get isWiredHeadsetOn {
    for (int i = 0; i < audioDevices.length; i++) {
      if (audioDevices[i].type == AudioDeviceType.WIREDHEADSET) {
        return true;
      }
    }
    return false;
  }

  ///是否连接有蓝牙耳机
  bool get isBluetoothHeadsetOn {
    for (int i = 0; i < audioDevices.length; i++) {
      if (audioDevices[i].type == AudioDeviceType.BLUETOOTHHEADSET) {
        return true;
      }
    }
    return false;
  }

  ///是否连接有蓝牙音响
  bool get isBluetoothA2dpOn {
    for (int i = 0; i < audioDevices.length; i++) {
      if (audioDevices[i].type == AudioDeviceType.BLUETOOTHA2DP) {
        return true;
      }
    }
    return false;
  }

  ///蓝牙HFP设备名称
  String? get bluetoothHeadsetName {
    for (int i = 0; i < audioDevices.length; i++) {
      if (audioDevices[i].type == AudioDeviceType.BLUETOOTHHEADSET) {
        return audioDevices[i].name;
      }
    }
    return null;
  }

  ///蓝牙A2DP设备名称
  String? get bluetoothA2dpName {
    for (int i = 0; i < audioDevices.length; i++) {
      if (audioDevices[i].type == AudioDeviceType.BLUETOOTHA2DP) {
        return audioDevices[i].name;
      }
    }
    return null;
  }

  _AudioManager._() {
    initialize();
  }

  bool _hasInit = false;

  Future<void> initialize() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    if (_hasInit) {
      return;
    }
    _hasInit = true;
    bluetoothScoStateNotifier.value = await isBluetoothScoOn
        ? BluetoothScoState.CONNECTED
        : BluetoothScoState.DISCONNECTED;
    await _getCurrentAudioDevice();
    await _getAvailableAudioDevices();
    _channel.setMethodCallHandler((call) async {
      String method = call.method;
      if ("bluetoothScoChanged" == method) {
        int value = call.arguments;
        BluetoothScoState _bluetoothScoState;
        if (value == 0) {
          _bluetoothScoState = BluetoothScoState.DISCONNECTED;
        } else if (value == 1) {
          _bluetoothScoState = BluetoothScoState.CONNECTING;
        } else if (value == 2) {
          _bluetoothScoState = BluetoothScoState.CONNECTED;
        } else if (value == 3) {
          _bluetoothScoState = BluetoothScoState.ERROR;
        } else {
          return;
        }
        bluetoothScoStateNotifier.value = _bluetoothScoState;
      }

      if ("onCurrentAudioDeviceChanged" == method) {
        Map<dynamic, dynamic> result = call.arguments;
        AudioDevice device = AudioDevice(
            name: result["name"]!,
            type: _getAudioDeviceTypeByString(result["type"]!));
        _notifyCurrentAudioDeviceChanged(device);
      }

      if ("onAudioDevicesChanged" == method) {
        List<dynamic> result = call.arguments;
        List<AudioDevice> devices = result.map((e) {
          return AudioDevice(
              name: e["name"]!, type: _getAudioDeviceTypeByString(e["type"]!));
        }).toList();
        _notifyAvailableAudioDevicesChanged(devices);
      }
    });
  }

  final _channel = const MethodChannel('pcm/audioManager');

  ///请求音频焦点
  Future<void> requestAudioFocus() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    return await _channel.invokeMethod("requestAudioFocus");
  }

  ///释放音频焦点
  Future<void> abandonAudioFocus() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    return await _channel.invokeMethod("abandonAudioFocus");
  }

  ///设置音频模式为正常(android)
  Future<void> setAudioModeNormal() async {
    await setAndroidAudioMode(AndroidAudioMode.normal);
  }

  ///设置音频模式为通话模式(android)
  Future<void> setAudioModeInCommunication() async {
    await setAndroidAudioMode(AndroidAudioMode.inCommunication);
  }

  ///设置音频模式(android)
  Future<void> setAndroidAudioMode(AndroidAudioMode mode) async {
    if (Platform.isAndroid) {
      await _channel.invokeMethod('setAudioMode', mode.index);
    }
  }

  ///获取音频模式(android)
  Future<AndroidAudioMode?> getAndroidAudioMode() async {
    if (Platform.isAndroid) {
      return AndroidAudioMode
          .values[await _channel.invokeMethod('getAudioMode')];
    }
    return null;
  }

  ///停止蓝牙sco
  Future<void> stopBluetoothSco() async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("stopBluetoothSco");
    }
  }

  ///设置iOS音频类型
  Future<void> setIOSCategory(IOSAudioSessionCategory category,
      {IOSAudioSessionMode? mode,
      IOSAudioSessionCategoryOptions? options,
      IOSAudioSessionRouteSharingPolicy? policy}) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod("setCategory", {
        "category": category.index,
        "mode": mode?.index,
        "options": options?.value,
        "policy": policy?.index,
      });
    }
  }

  ///获取当前iOS的音频类型
  Future<IOSAudioSessionCategory?> getIOSCategory() async {
    if (Platform.isIOS) {
      return IOSAudioSessionCategory
          .values[await _channel.invokeMethod("getCategory")];
    }
    return null;
  }

  ///获取当前iOS的音频选项
  Future<IOSAudioSessionCategoryOptions?> getIOSCategoryOptions() async {
    if (Platform.isIOS) {
      return IOSAudioSessionCategoryOptions(
          await _channel.invokeMethod("getCategoryOptions"));
    }
    return null;
  }

  ///设置录音和播放模式
  ///[defaultToSpeaker] 没有连接其它外设的情况下是否默认输出到喇叭
  Future<void> setPlayAndRecordSession({bool defaultToSpeaker = false}) async {
    if (Platform.isIOS) {
      IOSAudioSessionCategoryOptions options =
          IOSAudioSessionCategoryOptions.allowBluetooth |
              IOSAudioSessionCategoryOptions.allowBluetoothA2dp;
      if (defaultToSpeaker) {
        options = options | IOSAudioSessionCategoryOptions.defaultToSpeaker;
      }

      ///注意这里必须使用voiceChat 否则在后台无法播放,原因未知
      await setIOSCategory(IOSAudioSessionCategory.playAndRecord,
          mode: IOSAudioSessionMode.voiceChat, options: options);
    }
  }

  ///判断其他应用是否正在播放音频
  ///仅iOS有效
  Future<bool?> isOtherAudioPlaying() async {
    if (Platform.isIOS) {
      return await _channel.invokeMethod("isOtherAudioPlaying");
    }
    return null;
  }

  ///蓝牙sco是否已开启
  Future<bool> get isBluetoothScoOn async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("isBluetoothScoOn");
    }
    return false;
  }

  ///是否正在打电话
  Future<bool> get isTelephoneCalling async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod("isTelephoneCalling");
  }

  ///获取有效的音频输出设备
  Future<List<AudioDevice>> _getAvailableAudioDevices() async {
    List<dynamic> result =
        await _channel.invokeMethod("getAvailableAudioDevices");
    List<AudioDevice> devices = result.map((e) {
      return AudioDevice(
          name: e["name"]!, type: _getAudioDeviceTypeByString(e["type"]!));
    }).toList();
    _notifyAvailableAudioDevicesChanged(devices);
    return audioDevices;
  }

  ///通知当前设备发生变化
  void _notifyCurrentAudioDeviceChanged(AudioDevice device) {
    if (device.type != currentAudioDevice.type ||
        device.name != currentAudioDevice.name) {
      currentAudioDeviceNotifier.value = device;
    }
  }

  ///通知外接设备发生变化
  void _notifyAvailableAudioDevicesChanged(List<AudioDevice> devices) {
    String devicesToString = devices
        .map((e) {
          return {"name": e.name, "type": e.type.name};
        })
        .toList()
        .toString();
    if (devicesToString ==
        audioDevices
            .map((e) {
              return {"name": e.name, "type": e.type.name};
            })
            .toList()
            .toString()) {
      return;
    }
    audioDevicesNotifier.value = devices;
  }

  ///获取当前音频输出设备
  Future<AudioDevice> _getCurrentAudioDevice() async {
    Map<dynamic, dynamic> device =
        await _channel.invokeMethod("getCurrentAudioDevice");
    AudioDevice audioDevice = AudioDevice(
        name: device["name"]!,
        type: _getAudioDeviceTypeByString(device["type"]!));
    _notifyCurrentAudioDeviceChanged(audioDevice);
    return audioDevice;
  }

  ///设置当前音频输出设备
  Future<void> setCurrentAudioDevice(AudioDeviceType type) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return;
    }
    if (Platform.isAndroid) {
      if (type == AudioDeviceType.WIREDHEADSET && isWiredHeadsetOn) {
        _notifyCurrentAudioDeviceChanged(WiredHeadset);
      } else if (type == AudioDeviceType.SPEAKER) {
        _notifyCurrentAudioDeviceChanged(Speaker);
      } else if (type == AudioDeviceType.EARPIECE) {
        _notifyCurrentAudioDeviceChanged(Earpiece);
      } else if (type == AudioDeviceType.BLUETOOTHHEADSET &&
          isBluetoothHeadsetOn) {
        _notifyCurrentAudioDeviceChanged(AudioDevice(
            name: bluetoothHeadsetName ?? "",
            type: AudioDeviceType.BLUETOOTHHEADSET));
      } else if (type == AudioDeviceType.BLUETOOTHA2DP &&
          isBluetoothA2dpOn &&
          !isBluetoothHeadsetOn) {
        _notifyCurrentAudioDeviceChanged(AudioDevice(
            name: bluetoothA2dpName ?? "",
            type: AudioDeviceType.BLUETOOTHA2DP));
      }
    }
    await _channel.invokeMethod("setCurrentAudioDevice", type.index);
  }
}

class AndroidAudioMode {
  static const invalid = AndroidAudioMode._(-2);
  static const current = AndroidAudioMode._(-1);
  static const normal = AndroidAudioMode._(0);
  static const ringtone = AndroidAudioMode._(1);
  static const inCall = AndroidAudioMode._(2);
  static const inCommunication = AndroidAudioMode._(3);
  static const values = {
    -2: invalid,
    -1: current,
    0: normal,
    1: ringtone,
    2: inCall,
    3: inCommunication,
  };

  final int index;

  const AndroidAudioMode._(this.index);
}

/// The categories for [AVAudioSession].
enum IOSAudioSessionCategory {
  ambient,
  soloAmbient,
  playback,
  record,
  playAndRecord,
  multiRoute,
}

/// The category options for [AVAudioSession].
class IOSAudioSessionCategoryOptions {
  static const IOSAudioSessionCategoryOptions none =
      IOSAudioSessionCategoryOptions(0);
  static const IOSAudioSessionCategoryOptions mixWithOthers =
      IOSAudioSessionCategoryOptions(0x1);
  static const IOSAudioSessionCategoryOptions duckOthers =
      IOSAudioSessionCategoryOptions(0x2);
  static const IOSAudioSessionCategoryOptions
      interruptSpokenAudioAndMixWithOthers =
      IOSAudioSessionCategoryOptions(0x11);
  static const IOSAudioSessionCategoryOptions allowBluetooth =
      IOSAudioSessionCategoryOptions(0x4);
  static const IOSAudioSessionCategoryOptions allowBluetoothA2dp =
      IOSAudioSessionCategoryOptions(0x20);
  static const IOSAudioSessionCategoryOptions allowAirPlay =
      IOSAudioSessionCategoryOptions(0x40);
  static const IOSAudioSessionCategoryOptions defaultToSpeaker =
      IOSAudioSessionCategoryOptions(0x8);

  final int value;

  const IOSAudioSessionCategoryOptions(this.value);

  IOSAudioSessionCategoryOptions operator |(
          IOSAudioSessionCategoryOptions option) =>
      IOSAudioSessionCategoryOptions(value | option.value);

  IOSAudioSessionCategoryOptions operator &(
          IOSAudioSessionCategoryOptions option) =>
      IOSAudioSessionCategoryOptions(value & option.value);

  bool contains(IOSAudioSessionCategoryOptions options) =>
      options.value & value == options.value;

  @override
  bool operator ==(Object other) =>
      other is IOSAudioSessionCategoryOptions && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// The modes for [AVAudioSession].
enum IOSAudioSessionMode {
  defaultMode,
  gameChat,
  measurement,
  moviePlayback,
  spokenAudio,
  videoChat,
  videoRecording,
  voiceChat,
  voicePrompt,
}

/// The route sharing policies for [AVAudioSession].
enum IOSAudioSessionRouteSharingPolicy {
  defaultPolicy,
  longFormAudio,
  longFormVideo,
  independent,
}
