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


    ///音频数据缓冲区,这里不能用ArrayList
    private final List<byte[]> buffers = new LinkedList<>();

    ///读取缓冲区的下标
    private int readBufferIndex = 0;
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
            int mBufferSize = (AudioTrack.getMinBufferSize(sampleRateInHz,
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
            mPlayer.release();
            mPlayer = null;
            readBufferIndex = 0;
            buffers.clear();
            Log.e(TAG, "结束播放");
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
        if (mAudioPlayingRunner != null) {
            return;
        }
        setToStop = false;
        mPlayer.play();
        Log.e(TAG, "开始播放");
        mAudioPlayingRunner = new Thread(() -> {
            ///设置优先级
            Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO);
            while (!setToStop && !Thread.interrupted()) {
                if (buffers.size() > readBufferIndex) {
                    if (mPlayer != null) {
                        byte[] data = buffers.get(readBufferIndex);
                        int length = data.length;
                        mPlayer.write(data, 0, length);
                        readBufferIndex++;
                    }
                }
            }
            release();
        });
        mAudioPlayingRunner.start();
    }


    ///立刻停止播放
    public synchronized void stop() {
        if (mPlayer != null) {
            if (!setToStop) {
                setToStop = true;
                stopPlayingRunner();
                mPlayer.stop();
            } else {
                release();
            }
        }
    }

}
