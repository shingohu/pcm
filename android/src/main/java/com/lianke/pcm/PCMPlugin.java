package com.lianke.pcm;


import android.Manifest;
import android.app.Activity;

import android.content.Context;

import android.content.pm.PackageManager;

import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.PermissionChecker;

import com.lianke.audioswitch.AudioSwitch;
import com.lianke.pcm.player.PCMPlayer;
import com.lianke.pcm.recorder.PCMRecorder;
import com.lianke.pcm.recorder.RecordListener;
import com.lianke.pcm.util.Util;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry;

/**
 * PcmPlugin
 */
public class PCMPlugin implements FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {
    private MethodChannel recorderChannel;
    private MethodChannel playerChannel;

    private MethodChannel utilChannel;
    private EventChannel pcmStreamChannel;
    private EventChannel.EventSink pcmStreamSink;
    private Handler uiHandler = new Handler(Looper.getMainLooper());

    private Context applicationContext;
    private Activity mActivity;
    private ActivityPluginBinding activityBinding;
    private Map<Integer, PermissionCallback> permissionCallbackMap = new HashMap<>();

    private AudioSwitch audioSwitch;


    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        applicationContext = flutterPluginBinding.getApplicationContext();
        recorderChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pcm/recorder");
        recorderChannel.setMethodCallHandler(this);
        pcmStreamChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "pcm/stream");
        pcmStreamChannel.setStreamHandler(this);

        playerChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pcm/player");
        playerChannel.setMethodCallHandler(this);


        utilChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pcm/util");
        utilChannel.setMethodCallHandler(this);


        setPCMRecorderListener();


        audioSwitch = new AudioSwitch();
        audioSwitch.init(applicationContext, new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pcm/audioManager"));

    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method;

        if ("startRecording".equals(method)) {
            if (!checkRecordPermission(applicationContext)) {
                result.success(false);
                return;
            }
            int sampleRateInHz = call.argument("sampleRateInHz");
            int preFrameSize = call.argument("preFrameSize");
            int audioSource = call.argument("audioSource");
            boolean success = PCMRecorder.shared().init(sampleRateInHz, preFrameSize, audioSource);
            if (success) {
                audioSwitch.requestAudioFocus();
                result.success(PCMRecorder.shared().start());
            } else {
                result.success(false);
            }
        } else if ("isRecording".equals(method)) {
            result.success(PCMRecorder.shared().isRecording());
        } else if ("stopRecording".equals(method)) {
            PCMRecorder.shared().stop();
            result.success(true);
        } else if ("requestRecordPermission".equals(method)) {
            requestRecordPermission(result);
        } else if ("checkRecordPermission".equals(method)) {
            result.success(checkRecordPermission(applicationContext));
        }
        ///player
        if ("startPlaying".equals(method)) {
            byte[] data = call.argument("data");
            int sampleRateInHz = call.argument("sampleRateInHz");
            boolean voiceChat = call.argument("voiceChat");
            if (!PCMPlayer.shared().hasInit() || !PCMPlayer.shared().isPlaying()) {
                audioSwitch.requestAudioFocus();
            }
            PCMPlayer.shared().init(sampleRateInHz, voiceChat);
            PCMPlayer.shared().play(data);
            result.success(true);
        } else if ("isPlaying".equals(method)) {
            result.success(PCMPlayer.shared().isPlaying());
        } else if ("stopPlaying".equals(method)) {
            PCMPlayer.shared().stop();
            result.success(true);
        } else if ("unPlayLength".equals(method)) {
            result.success(PCMPlayer.shared().unPlayLength());
        }


        if ("pcm2wav".equals(method)) {
            String pcmPath = call.argument("pcmPath");
            String wavPath = call.argument("wavPath");
            int sampleRateInHz = call.argument("sampleRateInHz");
            new Thread(
                    () -> {
                        Util.pcm2wav(pcmPath, wavPath, sampleRateInHz, 1, 16);
                        uiHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                result.success(true);
                            }
                        });
                    }
            ).start();

        } else if ("adpcm2wav".equals(method)) {
            String adpcmPath = call.argument("adpcmPath");
            String wavPath = call.argument("wavPath");
            int sampleRateInHz = call.argument("sampleRateInHz");
            new Thread(
                    () -> {
                        Util.adpcmFile2wav(adpcmPath, wavPath, sampleRateInHz, 1, 16);
                        uiHandler.post(new Runnable() {
                            @Override
                            public void run() {
                                result.success(true);
                            }
                        });
                    }
            ).start();
        }
    }


    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        recorderChannel.setMethodCallHandler(null);
        utilChannel.setMethodCallHandler(null);
        playerChannel.setMethodCallHandler(null);
        pcmStreamChannel.setStreamHandler(null);
        pcmStreamSink = null;
    }

    @Override
    public void onListen(Object arguments, EventChannel.EventSink events) {
        pcmStreamSink = events;
    }

    @Override
    public void onCancel(Object arguments) {
        pcmStreamSink = null;
    }


    //设置录音监听
    public void setPCMRecorderListener() {
        PCMRecorder.shared().setRecordListener(new PCMRecordListener());
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        mActivity = binding.getActivity();
        audioSwitch.setActivity(mActivity);
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {

    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {

    }

    @Override
    public void onDetachedFromActivity() {
        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(this);
            activityBinding = null;
            mActivity = null;
            audioSwitch.setActivity(null);
        }
    }


    @Override
    public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions, @NonNull int[] grantResults) {
        if (permissionCallbackMap.containsKey(requestCode)) {
            if (grantResults.length > 0 && permissionCallbackMap.get(requestCode) != null) {
                if (grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                    permissionCallbackMap.get(requestCode).onPermission(true);
                    return true;
                } else {
                    permissionCallbackMap.get(requestCode).onPermission(false);
                }
            }
        }
        return false;
    }


    class PCMRecordListener implements RecordListener {
        @Override
        public void onAudioProcess(byte[] pcm) {
            if (pcmStreamSink != null) {
                uiHandler.post(() -> {
                    if (pcmStreamSink != null) {
                        pcmStreamSink.success(pcm);
                    }
                });
            }
        }


    }

    abstract static class PermissionCallback {
        abstract void onPermission(boolean hasPermission);
    }


    public boolean checkRecordPermission(Context context) {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PermissionChecker.PERMISSION_GRANTED;
    }

    public void requestRecordPermission(Result result) {
        PermissionCallback callback = new PermissionCallback() {
            @Override
            void onPermission(boolean hasPermission) {
                result.success(hasPermission);
                permissionCallbackMap.remove(result.hashCode());
            }
        };
        permissionCallbackMap.put(result.hashCode(), callback);
        if (checkRecordPermission(applicationContext)) {
            callback.onPermission(true);
        } else {
            ActivityCompat.requestPermissions(mActivity, new String[]{Manifest.permission.RECORD_AUDIO}, result.hashCode());
        }
    }

}
