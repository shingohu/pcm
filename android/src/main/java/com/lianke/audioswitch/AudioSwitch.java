package com.lianke.audioswitch;

import static android.media.AudioManager.GET_DEVICES_INPUTS;
import static android.media.AudioManager.GET_DEVICES_OUTPUTS;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.annotation.NonNull;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class AudioSwitch implements MethodChannel.MethodCallHandler {


    ///有效的音频输出设备
    private List<AudioDevice> availableAudioDevices = new CopyOnWriteArrayList<>();

    private AudioManager audioManager;
    private Context applicationContext;

    private MethodChannel audioManagerChannel;

    private Activity mActivity;

    private Handler mHandler;

    public void setActivity(Activity activity) {
        this.mActivity = activity;
    }

    public void init(Context context, MethodChannel channel) {
        this.mHandler = new Handler(Looper.getMainLooper());
        this.applicationContext = context;
        this.audioManagerChannel = channel;
        this.audioManagerChannel.setMethodCallHandler(this);
        audioManager = (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        enumerateDevices();
        audioManager.registerAudioDeviceCallback(new AudioDeviceCallback() {
            @Override
            public void onAudioDevicesAdded(AudioDeviceInfo[] addedDevices) {
                enumerateDevices();
            }

            @Override
            public void onAudioDevicesRemoved(AudioDeviceInfo[] removedDevices) {
                enumerateDevices();
            }
        }, new Handler());

    }

    public void enumerateDevices() {
        availableAudioDevices.clear();
        if (isBluetoothA2dpOn()) {
            availableAudioDevices.add(new AudioDevice(getBluetoothA2dpName(), AudioDeviceType.BLUETOOTHA2DP));
        }
        if (isBluetoothHeadsetOn()) {
            availableAudioDevices.add(new AudioDevice(getBluetoothHeadsetName(), AudioDeviceType.BLUETOOTHHEADSET));
        }

        if (isWiredHeadsetOn()) {
            availableAudioDevices.add(new AudioDevice(AudioDeviceType.WIREDHEADSET.name(), AudioDeviceType.WIREDHEADSET));
        }

        notifyCurrentAudioDeviceChanged();
        notifyAvailableAudioDevicesChanged();
    }


    //是否连接有线耳机
    public boolean isWiredHeadsetOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = 0; i < devices.length; i++) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_USB_HEADSET || deviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADSET || deviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADPHONES) {
                return true;
            }
        }
        return false;
    }

    public boolean isBluetoothHeadsetOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_INPUTS);

        ///倒序
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                return true;
            }
        }
        return false;
    }


    //是否连接蓝牙音响
    public boolean isBluetoothA2dpOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i > 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP) {
                return true;
            }
        }
        return false;
    }

    public String getBluetoothHeadsetName() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_INPUTS);
        ///倒序 取最新的那个
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                return deviceInfo.getProductName().toString();
            }
        }
        return "";
    }

    public String getBluetoothA2dpName() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        ///倒序 取最新的那个
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP) {
                return deviceInfo.getProductName().toString();
            }
        }
        return "";
    }


    public List<Map<String, String>> getAvailableAudioDevices() {
        List<Map<String, String>> list = new ArrayList<>();
        for (int i = 0; i < availableAudioDevices.size(); i++) {
            AudioDevice device = availableAudioDevices.get(i);
            list.add(new HashMap<String, String>() {
                {
                    put("name", device.name);
                    put("type", device.type.name());
                }
            });
        }

        return list;
    }


    /**
     * 切换当前音频输出设备
     *
     * @param index
     */
    public void setCurrentAudioDevice(int index) {
        if (index == AudioDeviceType.BLUETOOTHHEADSET.ordinal()) {
            openSpeaker(false);
            startBluetoothSco();
            notifyCurrentAudioDeviceChanged();
        } else if (index == AudioDeviceType.SPEAKER.ordinal()) {
            stopBluetoothSco();
            openSpeaker(true);
            notifyCurrentAudioDeviceChanged();
        } else {
            stopBluetoothSco();
            openSpeaker(false);
            notifyCurrentAudioDeviceChanged();
        }
    }


    public void openSpeaker(boolean open) {
        if (open) {
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
                List<AudioDeviceInfo> devices = audioManager.getAvailableCommunicationDevices();
                for (AudioDeviceInfo device : devices) {
                    if (device.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                        audioManager.setCommunicationDevice(device);
                        break;
                    }
                }
            } else {
                audioManager.setSpeakerphoneOn(true);
            }
            //  Log.e("AudioManager", "打开扬声器");
        } else {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.clearCommunicationDevice();
            } else {
                audioManager.setSpeakerphoneOn(false);
            }
            // Log.e("AudioManager", "关闭扬声器");
        }
    }


    private void startBluetoothSco() {
        if (isBluetoothHeadsetOn()) {
            boolean isScoOn = isBluetoothScoOn();
            setAudioModeInCommunication();
            registerSco();
            if (!isScoOn) {
                ///android 11
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    List<AudioDeviceInfo> devices = audioManager.getAvailableCommunicationDevices();
                    AudioDeviceInfo scoDevice = null;
                    for (int i = 0; i < devices.size(); i++) {
                        AudioDeviceInfo device = devices.get(i);
                        if (device.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                            scoDevice = device;
                            break;
                        }
                    }
                    if (scoDevice != null) {
                        audioManager.setCommunicationDevice(scoDevice);
                    }
                } else {
                    audioManager.startBluetoothSco();
                }
            } else {
                setScoState(BluetoothScoState.CONNECTED);
                audioManager.setBluetoothScoOn(true);
            }
        } else {
            setScoState(BluetoothScoState.DISCONNECTED);
        }
    }

    private void stopBluetoothSco() {
        if (this.scoState == BluetoothScoState.CONNECTED || this.scoState == BluetoothScoState.CONNECTING) {
            audioManager.setBluetoothScoOn(false);
            ///android11
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                audioManager.stopBluetoothSco();
            } else {
                audioManager.stopBluetoothSco();
            }
            Log.e("AudioManager", "停止SCO");
        } else {
            unRegisterSco();
        }
    }


    private boolean isBluetoothScoOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (audioManager.getCommunicationDevice() != null) {
                return audioManager.getCommunicationDevice().getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO;
            }
            return false;
        } else {
            return audioManager.isBluetoothScoOn();
        }
    }


    private void registerSco() {
        if (scoReceiver == null) {
            scoReceiver = new BroadcastReceiver() {
                @Override
                public void onReceive(Context context, Intent intent) {
                    if (intent.getAction() == null) {
                        return;
                    }
                    if (intent.getAction().equals(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)) {
                        int scoAudioState = intent.getIntExtra(AudioManager.EXTRA_SCO_AUDIO_STATE, -1);
                        if (scoAudioState == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
                            audioManager.setBluetoothScoOn(true);
                            setScoState(BluetoothScoState.CONNECTED);
                            Log.e("AudioManager", "SCO已开启");
                        } else if (scoAudioState == AudioManager.SCO_AUDIO_STATE_DISCONNECTED) {
                            if (scoState == BluetoothScoState.CONNECTED) {
                                audioManager.setBluetoothScoOn(false);
                                setScoState(BluetoothScoState.DISCONNECTED);
                                unRegisterSco();
                                Log.e("AudioManager", "SCO已断开");
                            } else if (scoState == BluetoothScoState.CONNECTING) {
                                setScoState(BluetoothScoState.ERROR);
                                unRegisterSco();
                                Log.e("AudioManager", "SCO开启失败");
                            }
                        } else if (scoAudioState == AudioManager.SCO_AUDIO_STATE_ERROR) {
                            audioManager.setBluetoothScoOn(false);
                            setScoState(BluetoothScoState.ERROR);
                            unRegisterSco();
                            Log.e("AudioManager", "SCO开启失败");
                        } else if (scoAudioState == AudioManager.SCO_AUDIO_STATE_CONNECTING) {
                            Log.e("AudioManager", "SCO开启中");
                            setScoState(BluetoothScoState.CONNECTING);
                        }

                    }
                }
            };
            IntentFilter intentFilter = new IntentFilter();
            intentFilter.addAction(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED);
            applicationContext.registerReceiver(scoReceiver, intentFilter);
        }
    }

    private void unRegisterSco() {
        if (scoReceiver != null) {
            applicationContext.unregisterReceiver(scoReceiver);
            scoReceiver = null;
        }
    }

    private BroadcastReceiver scoReceiver;


    ///sco的状态
    private BluetoothScoState scoState = BluetoothScoState.DISCONNECTED;


    private boolean isTelephoneCalling() {
        return audioManager.getMode() == AudioManager.MODE_IN_CALL;
    }


    private void setScoState(BluetoothScoState state) {
        if (this.scoState != state) {
            this.scoState = state;
            notifyBluetoothScoStateChange();
            notifyCurrentAudioDeviceChanged();
        }
    }


    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

        String method = call.method;
        ///audio manager
        if ("requestAudioFocus".equals(method)) {
            requestAudioFocus();
            result.success(true);
        } else if ("abandonAudioFocus".equals(method)) {
            abandonAudioFocus();
            result.success(true);
        } else if ("setAudioModeNormal".equals(method)) {
            setAudioModeNormal();
            result.success(true);
        } else if ("setAudioModeInCommunication".equals(method)) {
            setAudioModeInCommunication();
            result.success(true);
        } else if ("isTelephoneCalling".equals(method)) {
            result.success(isTelephoneCalling());
        } else if ("isBluetoothScoOn".equals(method)) {
            result.success(isBluetoothScoOn());
        } else if ("getAvailableAudioDevices".equals(method)) {
            result.success(getAvailableAudioDevices());
        } else if ("getCurrentAudioDevice".equals(method)) {
            result.success(getCurrentAudioDevice());
        } else if ("setCurrentAudioDevice".equals(method)) {
            new Thread(new Runnable() {
                @Override
                public void run() {
                    int index = (int) call.arguments;
                    setCurrentAudioDevice(index);
                    result.success(true);
                }
            }).start();

        }
    }


    public boolean isSpeakerOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (audioManager.getCommunicationDevice() != null) {
                return audioManager.getCommunicationDevice().getType() ==
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER;
            }
        }
        return audioManager.isSpeakerphoneOn();
    }


    ///释放音频焦点,录音结束的时候释放音频焦点
    final AudioManager.OnAudioFocusChangeListener audioFocusChangeListener = new AudioManager.OnAudioFocusChangeListener() {
        @Override
        public void onAudioFocusChange(int focusChange) {
            //Log.e("AudioManager", "音频焦点->" + focusChange);
        }
    };

    ///请求音频焦点,停止音乐播放器,录音的时候临时占用音频焦点
    public void requestAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.requestAudioFocus(new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).build());
        } else {
            audioManager.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
        }
    }

    public void abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            audioManager.abandonAudioFocusRequest(new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN).build());
        } else {
            audioManager.abandonAudioFocus(audioFocusChangeListener);
        }
    }


    public void setAudioModeInCommunication() {
        if (mActivity != null) {
            mActivity.setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);
        }
        if (audioManager.getMode() != AudioManager.MODE_IN_COMMUNICATION) {
            audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
            //Log.e("AudioManager", "MODE->MODE_IN_COMMUNICATION");
        }
    }

    public void setAudioModeNormal() {
        if (mActivity != null) {
            mActivity.setVolumeControlStream(AudioManager.STREAM_MUSIC);
        }
        if (audioManager.getMode() != AudioManager.MODE_NORMAL) {
            audioManager.setMode(AudioManager.MODE_NORMAL);
            // Log.e("AudioManager", "MODE->MODE_NORMAL");
        }
    }


    public Map<String, String> getCurrentAudioDevice() {

//        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
//            AudioDeviceInfo audioDeviceInfo = audioManager.getCommunicationDevice();
//            Log.e("T", audioDeviceInfo.toString());
//        }
        if (isSpeakerOn()) {
            return new HashMap<String, String>() {
                {
                    put("name", AudioDeviceType.SPEAKER.name());
                    put("type", AudioDeviceType.SPEAKER.name());
                }
            };
        } else if (isWiredHeadsetOn()) {
            return new HashMap<String, String>() {
                {
                    put("name", AudioDeviceType.WIREDHEADSET.name());
                    put("type", AudioDeviceType.WIREDHEADSET.name());
                }
            };
        } else if (scoState == BluetoothScoState.CONNECTED || scoState == BluetoothScoState.CONNECTING) {
            return new HashMap<String, String>() {
                {
                    put("name", getBluetoothHeadsetName());
                    put("type", AudioDeviceType.BLUETOOTHHEADSET.name());
                }
            };
        } else {
            if (audioManager.getMode() != AudioManager.MODE_IN_COMMUNICATION) {
                if (isBluetoothA2dpOn()) {
                    return new HashMap<String, String>() {
                        {
                            put("name", getBluetoothA2dpName());
                            put("type", AudioDeviceType.BLUETOOTHA2DP.name());
                        }
                    };
                }
            }


            return new HashMap<String, String>() {
                {
                    put("name", AudioDeviceType.EARPIECE.name());
                    put("type", AudioDeviceType.EARPIECE.name());
                }
            };
        }
    }


    void notifyCurrentAudioDeviceChanged() {
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                if (audioManagerChannel != null) {
                    audioManagerChannel.invokeMethod("onCurrentAudioDeviceChanged", getCurrentAudioDevice());
                }
            }
        });
    }

    void notifyAvailableAudioDevicesChanged() {
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                if (audioManagerChannel != null) {
                    audioManagerChannel.invokeMethod("onAudioDevicesChanged", getAvailableAudioDevices());
                }
            }
        });
    }

    void notifyBluetoothScoStateChange() {
        mHandler.post(new Runnable() {
            @Override
            public void run() {
                if (audioManagerChannel != null) {
                    audioManagerChannel.invokeMethod("bluetoothScoChanged", scoState.ordinal());
                }
            }
        });
    }
};
