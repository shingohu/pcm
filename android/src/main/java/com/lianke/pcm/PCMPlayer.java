package com.lianke.pcm;

import android.media.AudioAttributes;
import android.media.AudioDeviceInfo;
import android.media.AudioFormat;
import android.media.AudioManager;
import android.media.AudioTrack;
import android.os.Build;
import android.os.Process;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.LinkedBlockingQueue;


public class PCMPlayer {

    private final static String TAG = "PCMPlayer";

    //10ms 数据大小
    private int MAX_FRAMES_PER_BUFFER = 160;


    public static AudioDeviceInfo preferredDevice = null;

    //=======================AudioTrack Default Settings=======================
    private static final int STREAM_MUSIC = AudioManager.STREAM_MUSIC;

    private static final int DEFAULT_CHANNEL_CONFIG = AudioFormat.CHANNEL_OUT_MONO;
    private static final int DEFAULT_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;


    public PCMPlayer() {

    }

    private final LinkedBlockingQueue<byte[]> mSampleBuffer = new LinkedBlockingQueue<>();
    private volatile AudioTrack mPlayer;

    private Thread mAudioPlayingRunner = null;
    private volatile boolean isPlaying = false;


    /// 是否正在播放
    public boolean isPlaying() {
        return isPlaying;
    }


    public void setUp(int sampleRateInHz, int streamType) {
        if (mPlayer != null) {
            if (mPlayer.getSampleRate() != sampleRateInHz || mPlayer.getStreamType() != streamType) {
                stop();
            }
        }
        int samplesPer10ms = sampleRateInHz / 100;

        // 计算数据大小（字节数）
        MAX_FRAMES_PER_BUFFER = (samplesPer10ms * 16 * 1) / 8;

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
            mSamplesClear();
        }
        if (PCMPlayer.preferredDevice != null) {
            setPreferredDevice(PCMPlayer.preferredDevice);
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
                byte[] data;
                try {
                    // blocks indefinitely until new data
                    data = mSamplesTake();
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    continue;
                }
                if (data != null && mPlayer != null) {
                    mPlayer.write(data, 0, data.length);
                }
                //System.err.println("剩余:" + mSamplesRemainingFrames());
            }
        });
        mAudioPlayingRunner.setPriority(Thread.MAX_PRIORITY);
        mAudioPlayingRunner.start();
    }


    /// 结束播放
    public void stop() {
        if (mPlayer != null && isPlaying) {
            mPlayer.stop();
        }
        stopPlaybackThread();
        isPlaying = false;
        if (mPlayer != null) {
            mPlayer.release();
            mPlayer = null;
        }
        mSamplesClear();
    }


    /// 暂停播放
    public void pause() {
        stopPlaybackThread();
        if (mPlayer != null && isPlaying) {
            mPlayer.pause();
            mPlayer.flush();
        }
        isPlaying = false;
        mSamplesClear();
    }

    public void clear() {
        mSamplesClear();
    }

    public void start() {
        if (mPlayer != null && !isPlaying) {
            isPlaying = true;
            mPlayer.play();
            starPlaybackThread();
        }
    }


    public void feed(byte[] buffer) {
        if (mPlayer != null) {
            if (buffer.length > 0) {
                mSamplesPush(buffer);
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


    private void mSamplesClear() {
        mSampleBuffer.clear();
    }

    private byte[] mSamplesTake() throws InterruptedException {
        return mSampleBuffer.take();
    }

    private void mSamplesPush(byte[] buffer) {
        try {
            List<byte[]> got = split(buffer, MAX_FRAMES_PER_BUFFER);
            for (byte[] b : got) {
                mSampleBuffer.put(b);
            }
        } catch (InterruptedException e) {
            e.printStackTrace();
        }
    }

    private List<byte[]> split(byte[] buffer, int maxSize) {
        List<byte[]> chunks = new ArrayList<>();
        int offset = 0;
        while (offset < buffer.length) {
            int length = Math.min(buffer.length - offset, maxSize);
            byte[] b = new byte[length];
            System.arraycopy(buffer, offset, b, 0, length);
            chunks.add(b);
            offset += length;
        }
        return chunks;
    }


    private long mSamplesRemainingFrames() {
        long totalBytes = 0;
        for (byte[] bytes : mSampleBuffer) {
            totalBytes += bytes.length;
        }
        return totalBytes;
    }


    private void stopPlaybackThread() {
        if (mAudioPlayingRunner != null) {
            mAudioPlayingRunner.interrupt();
            try {
                mAudioPlayingRunner.join();
            } catch (InterruptedException e) {
                e.printStackTrace();
                Thread.currentThread().interrupt();
            }
            mAudioPlayingRunner = null;
        }
    }

    public void setPreferredDevice(AudioDeviceInfo audioDeviceInfo) {
        PCMPlayer.preferredDevice = audioDeviceInfo;
        if (mPlayer != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mPlayer.setPreferredDevice(audioDeviceInfo);
            }
        }
    }
}
