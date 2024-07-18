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


import com.lianke.pcm.player.PCMPlayer;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Timer;
import java.util.concurrent.CopyOnWriteArrayList;


import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

public class AudioSwitch implements MethodChannel.MethodCallHandler {

    private static final String TAG = "AudioSwitch";


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
//        IntentFilter intentFilter = new IntentFilter();
//        intentFilter.addAction("android.intent.action.HEADSET_PLUG");
//        this.applicationContext.registerReceiver(new BroadcastReceiver() {
//            @Override
//            public void onReceive(Context context, Intent intent) {
//                int state = intent.getIntExtra("state", -1);
//                Log.e(TAG, "耳机状态->" + state);
//                enumerateDevices();
//            }
//        }, intentFilter);
        audioManager.registerAudioDeviceCallback(new AudioDeviceCallback() {
            @Override
            public void onAudioDevicesAdded(AudioDeviceInfo[] addedDevices) {
                if (addedDevices.length == 1) {
                    if (isWiredHeadsetAudioDevice(addedDevices[0])) {
                        if (isBluetoothHeadsetOn() || isBluetoothA2dpOn()) {
                            updateAudioDevices();
                            return;
                        }
                    }
                } else {
                    for (int i = 0; i < addedDevices.length; i++) {
                        if (isBluetoothHeadsetAudioDevice(addedDevices[i])) {
                            return;
                        }
                    }
                }
                enumerateDevices();
            }

            @Override
            public void onAudioDevicesRemoved(AudioDeviceInfo[] removedDevices) {
                if (removedDevices.length == 1) {
                    if (isWiredHeadsetAudioDevice(removedDevices[0])) {
                        if (isBluetoothHeadsetOn() || isBluetoothA2dpOn()) {
                            updateAudioDevices();
                            return;
                        }
                    }
                    if (isBluetoothHeadsetAudioDevice(removedDevices[0])) {
                        updateAudioDevices();
                        return;
                    }
                }
                enumerateDevices();
            }
        }, new Handler());

    }


    void updateAudioDevices() {
        mHandler.removeCallbacks(updateAudioDevicesRunner);
        mHandler.postDelayed(updateAudioDevicesRunner, 500);
    }

    Runnable updateAudioDevicesRunner = new Runnable() {
        @Override
        public void run() {
            enumerateDevices();
        }
    };

    public void enumerateDevices() {
        mHandler.removeCallbacks(updateAudioDevicesRunner);
        loadAvailableAudioDevices();
        notifyCurrentAudioDeviceChanged();
        notifyAvailableAudioDevicesChanged();
    }

    private void loadAvailableAudioDevices() {
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
    }

    private boolean isWiredHeadsetAudioDevice(AudioDeviceInfo deviceInfo) {
        if (deviceInfo.getType() == AudioDeviceInfo.TYPE_USB_HEADSET || deviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADSET || deviceInfo.getType() == AudioDeviceInfo.TYPE_WIRED_HEADPHONES) {
            return true;
        }
        return false;
    }

    private boolean isBluetoothHeadsetAudioDevice(AudioDeviceInfo deviceInfo) {
        if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
            return true;
        }
        return false;
    }

    private boolean isBluetoothA2dpAudioDevice(AudioDeviceInfo deviceInfo) {
        if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP) {
            return true;
        }
        return false;
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
            if (isBluetoothHeadsetAudioDevice(deviceInfo)) {
                return true;
            }
        }
        return false;
    }

    //是否连接蓝牙音响
    public boolean isBluetoothA2dpOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (isBluetoothA2dpAudioDevice(deviceInfo)) {
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
            if (isBluetoothHeadsetAudioDevice(deviceInfo)) {
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
            if (isBluetoothA2dpAudioDevice(deviceInfo)) {
                return deviceInfo.getProductName().toString();
            }
        }
        return "";
    }


    public List<Map<String, String>> getAvailableAudioDevices() {
        loadAvailableAudioDevices();
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
        if (index == AudioDeviceType.BLUETOOTHHEADSET.ordinal() && isBluetoothHeadsetOn()) {
            openSpeaker(false);
            setBluetoothHeadsetOn();
            startBluetoothSco();
            return;
        } else if (index == AudioDeviceType.BLUETOOTHA2DP.ordinal() && isBluetoothA2dpOn()) {
            openSpeaker(false);
            setBluetoothA2dpOn();
            stopBluetoothSco();
        } else if (index == AudioDeviceType.WIREDHEADSET.ordinal() && isWiredHeadsetOn()) {
            setWiredHeadsetOn();
            openSpeaker(false);
        } else if (index == AudioDeviceType.SPEAKER.ordinal()) {
            setSpeakerOn();
            openSpeaker(true);
        } else {
            openSpeaker(false);
            setBuildInEarpieceOn();
        }
        notifyCurrentAudioDeviceChanged();
    }

    ///设置音频输出到蓝牙 (这里播放器必须初始化了才可以)
    ///为什么不能用setCommunicationDevice 会报错
    private void setBluetoothA2dpOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (isBluetoothA2dpAudioDevice(deviceInfo)) {
                PCMPlayer.shared().setPreferredDevice(deviceInfo);
                return;
            }
        }
    }

    private void setBluetoothHeadsetOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (isBluetoothHeadsetAudioDevice(deviceInfo)) {
                PCMPlayer.shared().setPreferredDevice(deviceInfo);
                return;
            }
        }
    }

    private void setWiredHeadsetOn() {

        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (isWiredHeadsetAudioDevice(deviceInfo)) {
                PCMPlayer.shared().setPreferredDevice(deviceInfo);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audioManager.setCommunicationDevice(deviceInfo);
                    return;
                }
            }
        }

    }


    private void setBuildInEarpieceOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) {
                PCMPlayer.shared().setPreferredDevice(deviceInfo);
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    audioManager.setCommunicationDevice(deviceInfo);
                }
                return;
            }
        }
    }


    private void setSpeakerOn() {
        AudioDeviceInfo[] devices = audioManager.getDevices(
                GET_DEVICES_OUTPUTS);
        for (int i = devices.length - 1; i >= 0; i--) {
            AudioDeviceInfo deviceInfo = devices[i];
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                PCMPlayer.shared().setPreferredDevice(deviceInfo);
                return;
            }
        }
    }

    public void openSpeaker(boolean open) {
        audioManager.setSpeakerphoneOn(open);
//        if (open) {
//            if (android.os.Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//                List<AudioDeviceInfo> devices = audioManager.getAvailableCommunicationDevices();
//                for (AudioDeviceInfo device : devices) {
//                    if (device.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
//                        audioManager.setCommunicationDevice(device);
//                        break;
//                    }
//                }
//            } else {
//                audioManager.setSpeakerphoneOn(true);
//            }
//            //  Log.e("AudioManager", "打开扬声器");
//        } else {
//            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
//                audioManager.clearCommunicationDevice();
//            } else {
//                audioManager.setSpeakerphoneOn(false);
//            }
//            // Log.e("AudioManager", "关闭扬声器");
//        }
    }


    private void startBluetoothSco() {
        if (isBluetoothHeadsetOn()) {
            boolean isScoOn = isBluetoothScoOn();
            registerSco();
            if (!isScoOn) {
                ///android 13
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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
                    audioManager.setBluetoothScoOn(true);
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
            ///android13
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                audioManager.clearCommunicationDevice();
            } else {
                audioManager.stopBluetoothSco();
            }
            Log.e("AudioManager", "停止SCO");
        } else {
            unRegisterSco();
        }
    }


    private boolean isBluetoothScoOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
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
                                audioManager.stopBluetoothSco();
                                unRegisterSco();
                                setScoState(BluetoothScoState.DISCONNECTED);
                                Log.e("AudioManager", "SCO已断开");
                            } else if (scoState == BluetoothScoState.CONNECTING) {
                                audioManager.setBluetoothScoOn(false);
                                audioManager.stopBluetoothSco();
                                unRegisterSco();
                                setScoState(BluetoothScoState.ERROR);
                                Log.e("AudioManager", "SCO开启失败");
                            }
                        } else if (scoAudioState == AudioManager.SCO_AUDIO_STATE_ERROR) {
                            audioManager.setBluetoothScoOn(false);
                            audioManager.stopBluetoothSco();
                            unRegisterSco();
                            setScoState(BluetoothScoState.ERROR);
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
            new Thread(() -> {
                int index = (int) call.arguments;
                setCurrentAudioDevice(index);
                mHandler.post(() -> result.success(true));
            }).start();
        } else if ("stopBluetoothSco".equals(method)) {
            stopBluetoothSco();
            result.success(true);
        }
    }


    public boolean isSpeakerOn() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (audioManager.getCommunicationDevice() != null) {
                return audioManager.getCommunicationDevice().getType() ==
                        AudioDeviceInfo.TYPE_BUILTIN_SPEAKER;
            }
        }
        return audioManager.isSpeakerphoneOn();
    }

    AudioFocusRequest audioFocusRequest;

    ///释放音频焦点,录音结束的时候释放音频焦点
    final AudioManager.OnAudioFocusChangeListener audioFocusChangeListener = new AudioManager.OnAudioFocusChangeListener() {
        @Override
        public void onAudioFocusChange(int focusChange) {
        }
    };

    ///请求音频焦点,停止音乐播放器,录音的时候临时占用音频焦点
    public void requestAudioFocus() {
        audioManager.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_VOICE_CALL, AudioManager.AUDIOFOCUS_GAIN_TRANSIENT);
    }

    public void abandonAudioFocus() {
        audioManager.abandonAudioFocus(audioFocusChangeListener);
    }


    //设置通话模式(耗时大约200ms)
    public void setAudioModeInCommunication() {
        if (audioManager.getMode() != AudioManager.MODE_IN_COMMUNICATION) {
            if (mActivity != null) {
                mActivity.setVolumeControlStream(AudioManager.STREAM_VOICE_CALL);
            }
            audioManager.setMode(AudioManager.MODE_IN_COMMUNICATION);
        }
    }

    //设置正常模式(耗时大约200ms)
    public void setAudioModeNormal() {
        if (audioManager.getMode() != AudioManager.MODE_NORMAL) {
            if (mActivity != null) {
                mActivity.setVolumeControlStream(AudioManager.STREAM_MUSIC);
            }
            audioManager.setMode(AudioManager.MODE_NORMAL);
        }
    }


    public Map<String, String> getCurrentAudioDevice() {
        AudioDeviceInfo deviceInfo = PCMPlayer.shared().getPreferredDevice();

        if (deviceInfo != null) {
            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                return new HashMap<String, String>() {
                    {
                        put("name", AudioDeviceType.SPEAKER.name());
                        put("type", AudioDeviceType.SPEAKER.name());
                    }
                };
            }

            if (deviceInfo.getType() == AudioDeviceInfo.TYPE_BUILTIN_EARPIECE) {
                return new HashMap<String, String>() {
                    {
                        put("name", AudioDeviceType.EARPIECE.name());
                        put("type", AudioDeviceType.EARPIECE.name());
                    }
                };
            }

            if (isWiredHeadsetAudioDevice(deviceInfo) && isWiredHeadsetOn()) {

                return new HashMap<String, String>() {
                    {
                        put("name", AudioDeviceType.WIREDHEADSET.name());
                        put("type", AudioDeviceType.WIREDHEADSET.name());
                    }
                };
            }

            if ((scoState == BluetoothScoState.CONNECTED || scoState == BluetoothScoState.CONNECTING) && isBluetoothHeadsetOn()) {
                return new HashMap<String, String>() {
                    {
                        put("name", deviceInfo.getProductName().toString());
                        put("type", AudioDeviceType.BLUETOOTHHEADSET.name());
                    }
                };
            }

            if (isBluetoothA2dpAudioDevice(deviceInfo) && isBluetoothA2dpOn()) {
                return new HashMap<String, String>() {
                    {
                        put("name", deviceInfo.getProductName().toString());
                        put("type", AudioDeviceType.BLUETOOTHA2DP.name());
                    }
                };
            }
        }


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


            setBuildInEarpieceOn();
            return new HashMap<String, String>() {
                {
                    put("name", AudioDeviceType.EARPIECE.name());
                    put("type", AudioDeviceType.EARPIECE.name());
                }
            };
        }
    }


    Runnable onCurrentAudioDeviceChangedRunner = new Runnable() {
        @Override
        public void run() {
            if (audioManagerChannel != null) {
                audioManagerChannel.invokeMethod("onCurrentAudioDeviceChanged", getCurrentAudioDevice());
            }
        }
    };


    void notifyCurrentAudioDeviceChanged() {
        mHandler.removeCallbacks(onCurrentAudioDeviceChangedRunner);
        mHandler.post(onCurrentAudioDeviceChangedRunner);
    }


    Runnable onAudioDevicesChanged = new Runnable() {
        @Override
        public void run() {
            if (audioManagerChannel != null) {
                audioManagerChannel.invokeMethod("onAudioDevicesChanged", getAvailableAudioDevices());
            }
        }
    };

    void notifyAvailableAudioDevicesChanged() {
        mHandler.removeCallbacks(onAudioDevicesChanged);
        mHandler.post(onAudioDevicesChanged);
    }


    Runnable bluetoothScoChangedRunner = new Runnable() {
        @Override
        public void run() {
            if (audioManagerChannel != null) {
                audioManagerChannel.invokeMethod("bluetoothScoChanged", scoState.ordinal());
            }
        }
    };

    void notifyBluetoothScoStateChange() {
        mHandler.removeCallbacks(bluetoothScoChangedRunner);
        mHandler.post(bluetoothScoChangedRunner);
    }
};
