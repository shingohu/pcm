package com.lianke.pcm;


import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.SoundPool;
import android.util.Log;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

///播放低延时短暂的声音 使用soundpool
public class BeepPlayer {

    private static final BeepPlayer instance = new BeepPlayer();

    private BeepPlayer() {

    }

    public static BeepPlayer shared() {
        return instance;
    }

    /**
     *
     */
    private Map<String, Integer> soundMap = new HashMap<>();

    private AssetManager assetManager;
    private FlutterPlugin.FlutterAssets flutterAssets;


    public void init(AssetManager assetManager, FlutterPlugin.FlutterAssets flutterAssets) {
        this.assetManager = assetManager;
        this.flutterAssets = flutterAssets;
    }


    public boolean load(String filaPath) {
        try {
            if (soundMap.containsKey(filaPath)) {
                return true;
            }
            String assetPath = flutterAssets.getAssetFilePathByName(filaPath);
            AssetFileDescriptor fileDescriptor = assetManager.openFd(assetPath);
            int soundId = soundPool.load(fileDescriptor, Integer.MAX_VALUE);
            soundMap.put(filaPath, soundId);
            fileDescriptor.close();
            return true;
        } catch (IOException e) {
            e.printStackTrace();
        }
        return false;
    }

    public boolean play(String filePath, float volume, int loop) {
        if (soundMap.containsKey(filePath)) {
            return soundPool.play(soundMap.get(filePath), volume, volume, 1000, loop, 1) != 0;
        } else {
            Log.e("[BeepPlayer]", "the " + filePath + " is not loaded");
        }
        return false;
    }

    public boolean loadAndPlay(String filePath, float volume, int loop) {
        try {
            soundPool.setOnLoadCompleteListener((soundPool, sampleId, status) -> {
                if (status != 0) {
                    Log.e("[BeepPlayer]", sampleId + " sound file load error " + status);
                } else {
                    soundPool.play(sampleId, volume, volume, 1000, loop, 1);
                }
            });
            String assetPath = flutterAssets.getAssetFilePathByName(filePath);
            AssetFileDescriptor fileDescriptor = assetManager.openFd(assetPath);
            soundPool.load(fileDescriptor, Integer.MAX_VALUE);
            fileDescriptor.close();
            return false;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return true;
    }

    public void stop(String filePath) {
        if (soundMap.containsKey(filePath)) {
            soundPool.stop(soundMap.get(filePath));
        }
    }

    private SoundPool soundPool = new SoundPool.Builder().setMaxStreams(10)
            .setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .build())
            .build();


}
