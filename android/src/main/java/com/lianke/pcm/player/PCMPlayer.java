package com.lianke.pcm.player;

import static android.media.AudioTrack.PERFORMANCE_MODE_LOW_LATENCY;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import com.lianke.BuildConfig;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
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


    private final ByteArrayOutputStream buffers = new ByteArrayOutputStream();
    ///读取缓冲区的下标
    private int readBufferIndex = 0;
    private int mBufferSize = 0;
    private Thread mAudioPlayingRunner = null;
    private volatile boolean isPlaying = false;
    private volatile boolean isRelease = true;

    ///是否正在播放
    public boolean isPlaying() {
        return isPlaying;
    }


    public boolean hasInit() {
        return mPlayer != null;
    }

    public void init(int sampleRateInHz, boolean voiceCall) {
        if (mPlayer == null) {
            mBufferSize = (AudioTrack.getMinBufferSize(sampleRateInHz,
                    DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT));
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    mPlayer = new AudioTrack.Builder()
                            .setAudioAttributes(new AudioAttributes.Builder()
                                    .setContentType(voiceCall ? AudioAttributes.CONTENT_TYPE_SPEECH : AudioAttributes.CONTENT_TYPE_MUSIC)
                                    .setUsage(voiceCall ? AudioAttributes.USAGE_VOICE_COMMUNICATION : AudioAttributes.USAGE_MEDIA)
                                    .setLegacyStreamType(voiceCall ? STREAM_VOICE_CALL : STREAM_MUSIC)
                                    .build())
                            .setTransferMode(AudioTrack.MODE_STREAM)
                            .setAudioFormat(new AudioFormat.Builder()
                                    .setSampleRate(sampleRateInHz)
                                    .setEncoding(DEFAULT_AUDIO_FORMAT)
                                    .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                    .build())
                            .setPerformanceMode(PERFORMANCE_MODE_LOW_LATENCY)
                            .setBufferSizeInBytes(mBufferSize)
                            .build();
                } else {
                    mPlayer = new AudioTrack.Builder()
                            .setAudioAttributes(new AudioAttributes.Builder()
                                    .setContentType(voiceCall ? AudioAttributes.CONTENT_TYPE_SPEECH : AudioAttributes.CONTENT_TYPE_MUSIC)
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
                }
            } else {
                mPlayer = new AudioTrack(voiceCall ? STREAM_VOICE_CALL : STREAM_MUSIC,
                        sampleRateInHz, //sample rate
                        DEFAULT_CHANNEL_CONFIG, //1 channel
                        DEFAULT_AUDIO_FORMAT, // 16-bit
                        mBufferSize,
                        AudioTrack.MODE_STREAM
                );
            }
            this.isRelease = false;
            this.readBufferIndex = 0;
            this.buffers.reset();
        }
    }


    public AudioDeviceInfo getPreferredDevice() {
        if (mPlayer != null) {
            return mPlayer.getPreferredDevice();
        }
        return null;
    }

    public AudioDeviceInfo getRoutedDevice() {
        if (mPlayer != null) {
            return mPlayer.getRoutedDevice();
        }
        return null;
    }

    public void setPreferredDevice(AudioDeviceInfo device) {
        if (mPlayer != null) {
            mPlayer.setPreferredDevice(device);
        }
    }

    public void play(byte[] pcm) {
        if (mPlayer != null) {
            startPlayingRunner();
            try {
                if (pcm.length != 0) {
                    buffers.write(pcm);
                }
            } catch (IOException e) {
                e.printStackTrace();
            }
        }
    }


    private synchronized void stopPlayingRunner() {
        if (mAudioPlayingRunner != null) {
            if (!mAudioPlayingRunner.isInterrupted()) {
                mAudioPlayingRunner.interrupt();
            }
            mAudioPlayingRunner = null;
        }
    }

    private synchronized void startPlayingRunner() {
        if (mAudioPlayingRunner != null || isPlaying) {
            return;
        }
        isPlaying = true;
        mAudioPlayingRunner = new Thread(() -> {
            ///设置优先级
            mPlayer.play();
            print(TAG, "开始播放");
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
            int readLength = mBufferSize;
            while (isPlaying && !Thread.interrupted()) {
                if (buffers.size() >= readBufferIndex + readLength) {
                    if (mPlayer != null) {
                        int length = mPlayer.write(subByte(buffers.toByteArray(), readBufferIndex, readLength), 0, readLength, AudioTrack.WRITE_NON_BLOCKING);
                        readBufferIndex += length;
                    }
                }
            }
            if (isRelease) {
                release();
            } else {
                buffers.reset();
                readBufferIndex = 0;
                print(TAG, "停止播放");
            }
        });
        mAudioPlayingRunner.start();
    }

    private byte[] subByte(byte[] src, int off, int length) {
        byte[] b = new byte[length];
        System.arraycopy(src, off, b, 0, length);
        return b;
    }


    ///立刻停止播放
    public synchronized void stop() {
        if (mPlayer != null) {
            if (isPlaying) {
                isPlaying = false;
                stopPlayingRunner();
                mPlayer.pause();
                mPlayer.flush();
                mPlayer.stop();
            }
        }
    }


    ///销毁播放器
    public synchronized void release() {
        this.isRelease = true;
        if (isPlaying) {
            stop();
        } else if (mPlayer != null) {
            mPlayer.release();
            mPlayer = null;
            buffers.reset();
            readBufferIndex = 0;
            print(TAG, "销毁播放器");
        }
    }

    public synchronized int unPlayLength() {
        int size = buffers.size() - readBufferIndex;
        if (size < 0) {
            size = 0;
        }
        return size;
    }

    private static void print(String tag, String msg) {
        if (BuildConfig.DEBUG) {
            Log.e(tag, msg);
        }
    }

}
