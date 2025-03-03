package com.lianke.pcm;


import static android.media.AudioManager.GET_DEVICES_INPUTS;

import android.Manifest;
import android.app.Activity;
import android.content.Context;

import android.content.pm.PackageManager;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.PermissionChecker;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.Log;
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

    private MethodChannel pcmMethodChannel;
    private EventChannel pcmStreamChannel;
    private EventChannel.EventSink pcmStreamSink;
    private Handler uiHandler = new Handler(Looper.getMainLooper());

    private Context applicationContext;
    private Activity mActivity;
    private ActivityPluginBinding activityBinding;
    private Map<Integer, PermissionCallback> permissionCallbackMap = new HashMap<>();

    private Map<String, PCMPlayer> players = new LinkedHashMap<>();
    private Map<String, ExecutorService> playOpServices = new LinkedHashMap<>();

    ExecutorService recordOpService = Executors.newSingleThreadExecutor();


    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        applicationContext = flutterPluginBinding.getApplicationContext();
        pcmMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.lianke.pcm");
        pcmMethodChannel.setMethodCallHandler(this);
        pcmStreamChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "com.lianke.pcm.stream");
        pcmStreamChannel.setStreamHandler(this);
        setPCMListener();
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        String method = call.method;

        if ("startRecording".equals(method)) {
            if (!checkRecordPermission(applicationContext)) {
                Log.e("[PCMRecorder]", "没有录音权限");
                result.success(false);
                return;
            }
            recordOpService.submit(() -> {
                int sampleRateInHz = call.argument("sampleRateInHz");
                int preFrameSize = call.argument("preFrameSize");
                boolean enableAEC = Boolean.TRUE.equals(call.argument("enableAEC"));
                boolean autoGain = Boolean.TRUE.equals(call.argument("autoGain"));
                boolean noiseSuppress = Boolean.TRUE.equals(call.argument("noiseSuppress"));
                boolean success = PCMRecorder.shared().setUp(sampleRateInHz, preFrameSize, enableAEC, autoGain, noiseSuppress);
                if (success) {
                    success = PCMRecorder.shared().start();
                }
                result.success(success);
            });

        } else if ("isRecording".equals(method)) {
            recordOpService.submit(() -> result.success(PCMRecorder.shared().isRecording()));
        } else if ("stopRecording".equals(method)) {
            recordOpService.submit(() -> {
                PCMRecorder.shared().stop();
                result.success(true);
            });
        } else if ("setRecordPreferredDevice".equals(method)) {
            int deviceId = call.argument("deviceId");
            PCMRecorder.shared().setPreferredDevice(findInputAudioDevice(deviceId));
            result.success(true);
        } else if ("requestRecordPermission".equals(method)) {
            requestRecordPermission(result);
        } else if ("checkRecordPermission".equals(method)) {
            result.success(checkRecordPermission(applicationContext));
        }
        ///player
        else if ("setUpPlayer".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                PCMPlayer player = new PCMPlayer();
                players.put(playerId, player);
                ExecutorService service = Executors.newSingleThreadExecutor();
                playOpServices.put(playerId, service);
                service.submit(() -> {
                    int sampleRateInHz = call.argument("sampleRateInHz");
                    int streamType = call.argument("streamType");
                    player.setUp(sampleRateInHz, streamType);
                    result.success(true);
                });
            } else {
                result.success(true);
            }

        } else if ("startPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(false);
                        return;
                    }
                    players.get(playerId).start();
                    result.success(players.get(playerId).isPlaying());
                });
            }
        } else if ("pausePlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(false);
                        return;
                    }
                    players.get(playerId).pause();
                    result.success(true);
                });
            }
        } else if ("isPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(false);
                        return;
                    }
                    result.success(players.get(playerId).isPlaying());
                });
            }
        } else if ("stopPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(false);
                        return;
                    }
                    players.get(playerId).stop();
                    players.remove(playerId);
                    playOpServices.get(playerId).shutdown();
                    playOpServices.remove(playerId);
                    result.success(true);
                });
            }
        } else if ("clearPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (players.containsKey(playerId)) {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(true);
                        return;
                    }
                    players.get(playerId).clear();
                    result.success(true);
                });
            } else {
                result.success(true);
            }

        } else if ("remainingFrames".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(0);
            } else {
                playOpServices.get(playerId).submit(() -> {
                    if (!players.containsKey(playerId)) {
                        result.success(0);
                        return;
                    }
                    result.success(players.get(playerId).remainingFrames());
                });
            }
        } else if ("feedPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (players.containsKey(playerId)) {
                byte[] data = call.argument("data");
                players.get(playerId).feed(data);
                result.success(true);
            } else {
                result.success(true);
            }
        } else if ("hotRestart".equals(method)) {
            hotRestart();
            result.success(true);
        }
    }


    AudioDeviceInfo findInputAudioDevice(int id) {
        if (applicationContext != null) {
            AudioManager audioManager = (AudioManager) applicationContext.getSystemService(Context.AUDIO_SERVICE);
            AudioDeviceInfo[] allDeviceInfo = new AudioDeviceInfo[0];
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
                allDeviceInfo = audioManager.getDevices(GET_DEVICES_INPUTS);
                for (AudioDeviceInfo device : allDeviceInfo) {
                    if (device.getId() == id) {
                        return device;
                    }
                }
            }
        }
        return null;
    }


    void hotRestart() {
        PCMRecorder.shared().stop();
        clearAllPlayer();
    }

    void clearAllPlayer() {
        for (PCMPlayer player : players.values()) {
            player.stop();
        }
        for (ExecutorService service : playOpServices.values()) {
            service.shutdown();
        }
        players.clear();
        playOpServices.clear();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        hotRestart();
        pcmMethodChannel.setMethodCallHandler(null);
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


    //设置录音和播放监听
    public void setPCMListener() {
        PCMRecorder.shared().setRecordListener(new PCMRecordListener());
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
        mActivity = binding.getActivity();
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
