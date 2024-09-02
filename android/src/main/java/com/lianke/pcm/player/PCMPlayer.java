package com.lianke.pcm.player;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
import android.os.Process;
import android.util.Log;

import com.lianke.BuildConfig;

import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.locks.Lock;
import java.util.concurrent.locks.ReentrantLock;


public class PCMPlayer {

    private final static String TAG = "PCMPlayer";

    private int MAX_FRAMES_PER_BUFFER = 80;

    //=======================AudioTrack Default Settings=======================
    private static final int STREAM_VOICE_CALL = AudioManager.STREAM_VOICE_CALL;
    private static final int STREAM_MUSIC = AudioManager.STREAM_MUSIC;

    private static final int DEFAULT_CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_MONO;
    private static final int DEFAULT_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;


    private static final PCMPlayer instance = new PCMPlayer();

    private PCMPlayer() {

    }


    public static PCMPlayer shared() {
        return instance;
    }

    private final Lock samplesLock = new ReentrantLock();
    private final LinkedList<ByteBuffer> mSampleBuffer = new LinkedList<>();

    private volatile AudioTrack mPlayer;

    private Thread mAudioPlayingRunner = null;
    private volatile boolean isPlaying = false;


    ///是否正在播放
    public boolean isPlaying() {
        return isPlaying;
    }

    public boolean hasInit() {
        return mPlayer != null;
    }

    private int playMuteTime = 0;
    private int playMuteTimeMax = 0;
    private int playMuteCount = 0;

    private AudioDeviceInfo mPreferredDevice = null;

    public void setPlayMuteTime(int playMuteTime) {
        this.playMuteTime = playMuteTime;
    }

    public void setPlayMuteTimeMax(int playMuteTimeMax) {
        this.playMuteTimeMax = playMuteTimeMax;
    }

    public void setUp(int sampleRateInHz, boolean voiceCall) {
        int streamType = voiceCall ? STREAM_VOICE_CALL : STREAM_MUSIC;
        if (mPlayer != null) {
            if (mPlayer.getSampleRate() != sampleRateInHz || mPlayer.getStreamType() != streamType) {
                stop();
            }
        }
        if (mPlayer == null) {
            int mMinBufferSize = (AudioTrack.getMinBufferSize(sampleRateInHz,
                    DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT));
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    mPlayer = new AudioTrack.Builder()
                            .setAudioAttributes(new AudioAttributes.Builder()
                                    .setLegacyStreamType(streamType)
                                    .build())
                            .setTransferMode(AudioTrack.MODE_STREAM)
                            .setAudioFormat(new AudioFormat.Builder()
                                    .setSampleRate(sampleRateInHz)
                                    .setEncoding(DEFAULT_AUDIO_FORMAT)
                                    .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                    .build())
                            .setBufferSizeInBytes(mMinBufferSize)
                            .build();
                } else {
                    mPlayer = new AudioTrack.Builder()
                            .setAudioAttributes(new AudioAttributes.Builder()
                                    .setLegacyStreamType(streamType)
                                    .build())
                            .setTransferMode(AudioTrack.MODE_STREAM)
                            .setAudioFormat(new AudioFormat.Builder()
                                    .setSampleRate(sampleRateInHz)
                                    .setEncoding(DEFAULT_AUDIO_FORMAT)
                                    .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                    .build())
                            .setBufferSizeInBytes(mMinBufferSize)
                            .build();
                }
            } else {
                mPlayer = new AudioTrack(streamType,
                        sampleRateInHz, //sample rate
                        DEFAULT_CHANNEL_CONFIG, //1 channel
                        DEFAULT_AUDIO_FORMAT, // 16-bit
                        mMinBufferSize,
                        AudioTrack.MODE_STREAM
                );
            }
            if (mPreferredDevice != null) {
                mPlayer.setPreferredDevice(mPreferredDevice);
            }
            mSamplesClear();
        }
    }

    public AudioDeviceInfo getPreferredDevice() {
        if (mPlayer != null) {
            return mPlayer.getPreferredDevice();
        }
        return null;
    }

    public void setPreferredDevice(AudioDeviceInfo device) {
        if (mPlayer != null) {
            mPlayer.setPreferredDevice(device);
        } else {
            mPreferredDevice = device;
        }
    }


    private synchronized void starPlaybackThread() {
        if (mAudioPlayingRunner != null) {
            return;
        }
        if (mPlayer == null) {
            return;
        }
        mAudioPlayingRunner = new Thread(() -> {
            ///设置优先级
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
            while (isPlaying && !Thread.interrupted()) {
                if (!mSamplesIsEmpty()) {
                    playMuteCount = 0;
                    ByteBuffer data = mSamplesPop();
                    if (data != null) {
                        data = data.duplicate();
                    }
                    if (data != null && mPlayer != null) {
                        mPlayer.write(data, data.remaining(), AudioTrack.WRITE_BLOCKING);
                    }
                } else {
                    if (mPlayer != null && playMuteTime != 0 && playMuteCount * playMuteTime <= playMuteTimeMax) {
                        playMuteCount++;
                        int muteLength = mPlayer.getSampleRate() / 1000 * 2 * playMuteTime;
                        mPlayer.write(new byte[muteLength], 0, muteLength, AudioTrack.WRITE_NON_BLOCKING);
                    }
                }
            }
        });
        mAudioPlayingRunner.setPriority(Thread.MAX_PRIORITY);
        mAudioPlayingRunner.start();
    }

    public void stop() {
        if (mPlayer != null) {
            mPlayer.stop();
            isPlaying = false;
        }
        stopPlaybackThread();
        if (mPlayer != null) {
            mPlayer.release();
            mPlayer = null;
            print("结束播放");
        }
        playMuteCount = 0;
        mPreferredDevice = null;
        isPlaying = false;
        mSamplesClear();
    }

    public void clear() {
        if (mPlayer != null && isPlaying) {
            mPlayer.pause();
            mPlayer.flush();
            mPlayer.play();
        }
        mSamplesClear();
    }

    private void startPlay() {
        if (mPlayer != null && !isPlaying) {
            isPlaying = true;
            mPlayer.play();
            print("开始播放");
        }
    }


    public void feed(byte[] buffer) {
        if (mPlayer != null) {
            startPlay();
            if (buffer.length > 0) {
                mSamplesPush(buffer);
                starPlaybackThread();
            }
        }
    }

    private byte[] subByte(byte[] src, int off, int length) {
        byte[] b = new byte[length];
        System.arraycopy(src, off, b, 0, length);
        return b;
    }


    public synchronized long remainingFrames() {
        return mSamplesRemainingFrames();
    }


    private static void print(String msg) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, msg);
        }
    }

    private void mSamplesClear() {
        samplesLock.lock();
        mSampleBuffer.clear();
        samplesLock.unlock();
    }


    private ByteBuffer mSamplesPop() {
        samplesLock.lock();
        ByteBuffer out = mSampleBuffer.poll();
        samplesLock.unlock();
        return out;
    }

    private void mSamplesPush(byte[] buffer) {
        samplesLock.lock();
        List<ByteBuffer> got = split(buffer, MAX_FRAMES_PER_BUFFER);
        mSampleBuffer.addAll(got);
        samplesLock.unlock();
    }

    private List<ByteBuffer> split(byte[] buffer, int maxSize) {
        List<ByteBuffer> chunks = new ArrayList<>();
        int offset = 0;
        while (offset < buffer.length) {
            int length = Math.min(buffer.length - offset, maxSize);
            ByteBuffer b = ByteBuffer.allocate(length);
            b.put(buffer, offset, length);
            b.rewind();
            chunks.add(b);
            offset += length;
        }
        return chunks;
    }

    private boolean mSamplesIsEmpty() {
        samplesLock.lock();
        boolean out = mSampleBuffer.size() == 0;
        samplesLock.unlock();
        return out;
    }

    private long mSamplesRemainingFrames() {
        samplesLock.lock();
        long totalBytes = 0;
        for (ByteBuffer sampleBuffer : mSampleBuffer) {
            totalBytes += sampleBuffer.remaining();
        }
        samplesLock.unlock();
        return totalBytes;
    }


    private void stopPlaybackThread() {
        if (mAudioPlayingRunner != null) {
            mAudioPlayingRunner.interrupt();
            try {
                mAudioPlayingRunner.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            mAudioPlayingRunner = null;
        }
    }

}
