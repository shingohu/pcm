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
        soundPool.setOnLoadCompleteListener(new SoundPool.OnLoadCompleteListener() {
            @Override
            public void onLoadComplete(SoundPool soundPool, int sampleId, int status) {
                if (status != 0) {
                    Log.e("[BeepPlayer]", "sound load error" + sampleId);
                } else {
                    soundPool.play(sampleId, 0, 0, sampleId, 0, 2);
                }
            }
        });
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
            int soundId = soundPool.load(fileDescriptor, 1);
            soundMap.put(filaPath, soundId);
        } catch (IOException e) {
            e.printStackTrace();
        }
        return false;
    }

    public boolean play(String filePath) {
        if (soundMap.containsKey(filePath)) {
            return soundPool.play(soundMap.get(filePath), 1, 1, 1000, 0, 1) != 0;
        } else {
            Log.e("[BeepPlayer]", "the " + filePath + " is not loaded");
        }
        return false;
    }

    public void stop(String filePath) {
        if (soundMap.containsKey(filePath)) {
            soundPool.stop(soundMap.get(filePath));
        }
    }

    private SoundPool soundPool = new SoundPool.Builder().setMaxStreams(10)
            .setAudioAttributes(new AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .build())
            .build();


}
