import 'dart:async';
import 'dart:convert';
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
  ///android sco 状态(暂时没用)
  ValueNotifier<BluetoothScoState> _bluetoothScoStateNotifier =
      ValueNotifier(BluetoothScoState.DISCONNECTED);

  ///外置音频输出设备变更
  ValueNotifier<List<AudioDevice>> externalAudioDevicesNotifier =
      ValueNotifier([]);

  ///外置音频输出设备(不包含内置耳机和内置扬声器)
  List<AudioDevice> get _externalAudioDevices =>
      externalAudioDevicesNotifier.value;

  ///当前音频设备变更通知
  ValueNotifier<AudioDevice> currentAudioDeviceNotifier = ValueNotifier(
      AudioDevice(
          name: AudioDeviceType.EARPIECE.name, type: AudioDeviceType.EARPIECE));

  ///当前的输出设备
  AudioDevice get currentAudioDevice => currentAudioDeviceNotifier.value;

  ///是否有可用的音频输出设备(不包含内置耳机和内置扬声器,这里可包含有蓝牙音响)
  bool get hasExternalAudioDevice => _externalAudioDevices.length > 0;

  ///是否有可用的音频输出设备(只包含蓝牙耳机和无线耳机)
  bool get hasExternalAudioDeviceInVoiceChatMode =>
      isWiredHeadsetOn || isBluetoothHeadsetOn;

  ///是否连接有无线耳机
  bool get isWiredHeadsetOn {
    for (int i = 0; i < _externalAudioDevices.length; i++) {
      if (_externalAudioDevices[i].type == AudioDeviceType.WIREDHEADSET) {
        return true;
      }
    }
    return false;
  }

  ///是否连接有蓝牙耳机
  bool get isBluetoothHeadsetOn {
    for (int i = 0; i < _externalAudioDevices.length; i++) {
      if (_externalAudioDevices[i].type == AudioDeviceType.BLUETOOTHHEADSET) {
        return true;
      }
    }
    return false;
  }

  ///蓝牙设备名称
  String? get bluetoothHeadsetName {
    for (int i = 0; i < _externalAudioDevices.length; i++) {
      if (_externalAudioDevices[i].type == AudioDeviceType.BLUETOOTHHEADSET) {
        return _externalAudioDevices[i].name;
      }
    }
    return null;
  }

  _AudioManager._() {
    _init();
  }

  void _init() async {
    _bluetoothScoStateNotifier.value = await _isBluetoothScoOn
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
        _bluetoothScoStateNotifier.value = _bluetoothScoState;
        print("音频SCO状态变更->${_bluetoothScoState.name}");
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
  Future<void> _requestAudioFocus() async {
    return await _channel.invokeMethod("requestAudioFocus");
  }

  ///释放音频焦点
  Future<void> _abandonAudioFocus() async {
    return await _channel.invokeMethod("abandonAudioFocus");
  }

  ///设置音频模式为通话
  Future<void> _setAudioModeInCommunication() async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("setAudioModeInCommunication");
    }
  }

  ///设置音频模式为正常
  Future<void> _setAudioModeNormal() async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("setAudioModeNormal");
    }
  }

  ///设置录音和播放模式
  Future<void> _setPlayAndRecordSession() async {
    if (Platform.isIOS) {
      ///设置这个之后,iOS当前的路由有可能变化
      await _channel.invokeMethod("setPlayAndRecordSession");
      await _getCurrentAudioDevice();
      await _getAvailableAudioDevices();
    }
  }

  ///蓝牙sco是否已开启
  Future<bool> get _isBluetoothScoOn async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod("isBluetoothScoOn");
    }
    return false;
  }

  ///是否正在打电话
  Future<bool> get isTelephoneCalling async {
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
    return _externalAudioDevices;
  }

  ///通知当前设备发生变化
  void _notifyCurrentAudioDeviceChanged(AudioDevice device) {
    if (device.type != currentAudioDevice.type ||
        device.name != currentAudioDevice.name) {
      currentAudioDeviceNotifier.value = device;
      print("当前输出设备变更->${device.type}");
    }
  }

  ///通知外接设备发生变化
  void _notifyAvailableAudioDevicesChanged(List<AudioDevice> devices) {
    if (devices.length != _externalAudioDevices.length) {
      String devicesToString = devices
          .map((e) {
            return {"name": e.name, "type": e.type.name};
          })
          .toList()
          .toString();
      if (devicesToString ==
          _externalAudioDevices
              .map((e) {
                return {"name": e.name, "type": e.type.name};
              })
              .toList()
              .toString()) {
        return;
      }
      externalAudioDevicesNotifier.value = devices;
      print("外置输出设备变更->${devicesToString}");
    }
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
    if (type != currentAudioDevice.type) {
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
      }

      await _channel.invokeMethod("setCurrentAudioDevice", type.index);
    }
  }

  ///开始语音通话
  ///没有连接耳机之前的情况下 默认是否开启扬声器
  Future<void> startVoiceChatMode({bool defaultToSpeaker = false}) async {
    if (Platform.isAndroid) {
      _requestAudioFocus();
      _setAudioModeInCommunication();
      if (isWiredHeadsetOn) {
        setCurrentAudioDevice(AudioDeviceType.WIREDHEADSET);
      } else if (isBluetoothHeadsetOn) {
        setCurrentAudioDevice(AudioDeviceType.BLUETOOTHHEADSET);
      } else if (defaultToSpeaker) {
        setCurrentAudioDevice(AudioDeviceType.SPEAKER);
      } else {
        setCurrentAudioDevice(AudioDeviceType.EARPIECE);
      }
    } else {
      await _setPlayAndRecordSession();
      if (isWiredHeadsetOn) {
        setCurrentAudioDevice(AudioDeviceType.WIREDHEADSET);
      } else if (isBluetoothHeadsetOn) {
        setCurrentAudioDevice(AudioDeviceType.BLUETOOTHHEADSET);
      } else if (defaultToSpeaker) {
        setCurrentAudioDevice(AudioDeviceType.SPEAKER);
      } else {
        setCurrentAudioDevice(AudioDeviceType.EARPIECE);
      }
    }
  }

  ///结束语音通话模式
  Future<void> endVoiceChatMode() async {
    if (Platform.isAndroid) {
      _setAudioModeNormal();
      _abandonAudioFocus();
      if (hasExternalAudioDevice) {
        setCurrentAudioDevice(AudioDeviceType.EARPIECE);
      } else {
        setCurrentAudioDevice(AudioDeviceType.SPEAKER);
      }
    } else {
      _abandonAudioFocus();
    }
  }
}
