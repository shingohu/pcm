package com.lianke.pcm;


import android.Manifest;
import android.app.Activity;
import android.content.Context;

import android.content.pm.PackageManager;
import android.media.AudioManager;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.core.content.PermissionChecker;

import java.util.HashMap;
import java.util.Map;

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

    private Map<String, PCMPlayer> players = new HashMap<>();

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        applicationContext = flutterPluginBinding.getApplicationContext();
        pcmMethodChannel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "com.lianke.pcm");
        pcmMethodChannel.setMethodCallHandler(this);
        pcmStreamChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "com.lianke.pcm.stream");
        pcmStreamChannel.setStreamHandler(this);

        BeepPlayer.shared().init(flutterPluginBinding.getApplicationContext().getAssets(), flutterPluginBinding.getFlutterAssets());
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
        else if ("setUpPlayer".equals(method)) {
            int sampleRateInHz = call.argument("sampleRateInHz");
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                PCMPlayer player = new PCMPlayer();
                player.setUp(sampleRateInHz);
                players.put(playerId, player);
            }
            result.success(true);
        } else if ("startPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                players.get(playerId).start();
                result.success(players.get(playerId).isPlaying());
            }
        } else if ("pausePlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                players.get(playerId).pause();
                result.success(true);
            }
        } else if ("isPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                result.success(players.get(playerId).isPlaying());
            }
        } else if ("stopPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(false);
            } else {
                players.get(playerId).stop();
                result.success(true);
                players.remove(playerId);
            }
        } else if ("clearPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (players.containsKey(playerId)) {
                players.get(playerId).clear();
            }
            result.success(true);
        } else if ("remainingFrames".equals(method)) {
            String playerId = call.argument("playerId");
            if (!players.containsKey(playerId)) {
                result.success(0);
            } else {
                result.success(players.get(playerId).remainingFrames());
            }
        } else if ("feedPlaying".equals(method)) {
            String playerId = call.argument("playerId");
            if (players.containsKey(playerId)) {
                byte[] data = call.argument("data");
                players.get(playerId).feed(data);
            }
            result.success(true);
        } else if ("hotRestart".equals(method)) {
            PCMRecorder.shared().stop();
            clearAllPlayer();
            result.success(true);
        } else if ("loadSound".equals(method)) {
            String path = call.argument("soundPath");
            new Thread(() -> {
                boolean success = BeepPlayer.shared().load(path);
                uiHandler.post(() -> result.success(success));
            }).start();
        } else if ("playSound".equals(method)) {
            String path = call.argument("soundPath");
            Double volume = call.argument("volume");
            int loop = call.argument("loop");
            result.success(BeepPlayer.shared().play(path, volume.floatValue(), loop));
        } else if ("stopSound".equals(method)) {
            String path = call.argument("soundPath");
            BeepPlayer.shared().stop(path);
            result.success(true);
        } else if ("isTelephoneCalling".equals(method)) {
            result.success(isTelephoneCalling());
        }
    }


    private boolean isTelephoneCalling() {
        AudioManager audioManager = (AudioManager) applicationContext.getSystemService(Context.AUDIO_SERVICE);
        return audioManager.getMode() == AudioManager.MODE_IN_CALL;
    }

    void clearAllPlayer() {
        for (PCMPlayer player : players.values()) {
            player.stop();
        }
        players.clear();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        PCMRecorder.shared().stop();
        clearAllPlayer();
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
