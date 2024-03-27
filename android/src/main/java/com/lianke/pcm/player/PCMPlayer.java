package com.lianke.pcm.player;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.media.PlaybackParams;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import com.lianke.pcm.adpcm.Adpcm;
import com.lianke.pcm.recorder.PCMRecorder;


import java.util.LinkedList;
import java.util.List;


public class PCMPlayer {

    private final static String TAG = "PCMPlayer";

    //=======================AudioTrack Default Settings=======================
    ///STREAM_VOICE_CALL 播放时默认声音从听筒出
    private static final int STREAM_VOICE_CALL = AudioManager.STREAM_VOICE_CALL;
    private static final int STREAM_MUSIC = AudioManager.STREAM_MUSIC;

    private static final int DEFAULT_SAMPLING_RATE = 8000;//模拟器仅支持从麦克风输入8kHz采样率
    private static final int DEFAULT_CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_MONO;
    private static final int DEFAULT_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;


    private static final PCMPlayer instance = new PCMPlayer();

    private PCMPlayer() {

    }

    public static PCMPlayer shared() {
        return instance;
    }


    private volatile AudioTrack mPlayer;


    ///音频数据缓冲区
    private final List<byte[]> buffers = new LinkedList<>();

    ///读取缓冲区的下标
    private volatile int readBufferIndex = 0;
    private Thread mAudioPlayingRunner = null;
    private volatile boolean setToStop = true;

    ///是否正在播放
    public boolean isPlaying() {
        return !setToStop;
    }


    public boolean hasInit() {
        return mPlayer != null;
    }

    public void init(int sampleRateInHz, boolean voiceCall) {
        if (mPlayer == null) {
            int mBufferSize = AudioTrack.getMinBufferSize(sampleRateInHz,
                    DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT);


            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mPlayer = new AudioTrack.Builder()
                        .setAudioAttributes(new AudioAttributes.Builder()
                                .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                                .setUsage(voiceCall ? AudioAttributes.USAGE_VOICE_COMMUNICATION : AudioAttributes.USAGE_MEDIA)
                                .setLegacyStreamType(voiceCall ? STREAM_VOICE_CALL : STREAM_MUSIC)
                                .build())
                        .setTransferMode(AudioTrack.MODE_STREAM)
                        .setAudioFormat(new AudioFormat.Builder()
                                .setSampleRate(sampleRateInHz)
                                .setEncoding(DEFAULT_AUDIO_FORMAT)
                                .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                .build())
                        .setBufferSizeInBytes(mBufferSize)
                        .build();
            } else {
                mPlayer = new AudioTrack(voiceCall ? STREAM_VOICE_CALL : STREAM_MUSIC,
                        sampleRateInHz, //sample rate
                        DEFAULT_CHANNEL_CONFIG, //1 channel
                        DEFAULT_AUDIO_FORMAT, // 16-bit
                        mBufferSize,
                        AudioTrack.MODE_STREAM
                );
            }
            this.readBufferIndex = 0;
            this.buffers.clear();
        }
    }


    public AudioDeviceInfo getRoutedDevice() {
        if (mPlayer != null && mPlayer.getRoutedDevice() != null) {
            return mPlayer.getRoutedDevice();
        }
        return null;
    }

    public void play(byte[] pcm) {
        if (mPlayer != null) {
            buffers.add(pcm);
            startPlayingRunner();
        }
    }


    ///重置播放参数
    private synchronized void release() {
        if (mPlayer != null) {
            stopPlayingRunner();
            setToStop = true;
            mPlayer.pause();
            mPlayer.flush();
            mPlayer.release();
            mPlayer = null;
            Log.e(TAG, "结束播放");
        }
    }

    private synchronized void stopPlayingRunner() {
        if (mAudioPlayingRunner != null) {
            if (!mAudioPlayingRunner.isInterrupted()) {
                mAudioPlayingRunner.interrupt();
                mAudioPlayingRunner = null;
            }
        }
    }

    private synchronized void startPlayingRunner() {
        if (mAudioPlayingRunner != null) {
            return;
        }
        setToStop = false;
        mPlayer.play();
       // Log.e(TAG, "开始播放");
        mAudioPlayingRunner = new Thread(() -> {
            ///设置优先级
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
            while (true) {
                if (mPlayer == null) {
                    // Log.e(TAG, "播放器已经销毁,退出播放");
                    return;
                }
                synchronized (this.buffers) {
                    if (buffers.size() > readBufferIndex) {
                        if (mPlayer != null && !setToStop) {
                            byte[] data = buffers.get(readBufferIndex);
                            mPlayer.write(data, 0, data.length);
                            readBufferIndex++;
                        }
                    } else if (setToStop) {
                        release();
                        return;
                    } else {
                        ///没有数据的时候就播放一个1ms的静音数据
                        ///华为手机上需要录音和播放都开启才能通过SCO录音播放
                        if (mPlayer != null && !setToStop) {
                            if (mPlayer.getStreamType() == AudioManager.STREAM_VOICE_CALL) {
                                int length = 80 / 5;
                                mPlayer.write(new byte[length], 0, length);
                            }
                        }
                    }
                }
            }
        });
        mAudioPlayingRunner.start();
    }


    ///停止播放,不会立刻停止,会等待全部播放完成
    public synchronized void stop() {
        setToStop = true;
    }


    ///立刻停止播放
    public synchronized void stopNow() {
        try {
            release();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

}
