package com.lianke.pcm.player;

import static android.media.AudioTrack.PERFORMANCE_MODE_LOW_LATENCY;
import static android.media.AudioTrack.PLAYSTATE_PLAYING;

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


    private final ByteArrayOutputStream buffers1 = new ByteArrayOutputStream();
    private final LinkedList<byte[]> buffers2 = new LinkedList<>();
    ///读取缓冲区的下标
    private int readBufferIndex = 0;
    private boolean useMethod1 = false;
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
            resetBuffer();
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
                if (pcm != null && pcm.length != 0) {
                    if (useMethod1) {
                        buffers1.write(pcm);
                    } else {
                        buffers2.add(pcm);
                    }
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
        if (mPlayer.getPlayState() != PLAYSTATE_PLAYING) {
            mPlayer.play();
        }
        mAudioPlayingRunner = new Thread(() -> {
            ///设置优先级
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
            print(TAG, "开始播放");
            if (useMethod1) {
                int readLength = mBufferSize;
                while (isPlaying && !Thread.interrupted()) {
                    int size = buffers1.size();
                    byte[] data = new byte[0];
                    if (size - readBufferIndex >= readLength) {
                        data = subByte(buffers1.toByteArray(), readBufferIndex, readLength);
                    }
                    if (mPlayer != null && data.length > 0) {
                        int length = mPlayer.write(data, 0, data.length, AudioTrack.WRITE_NON_BLOCKING);
                        readBufferIndex += length;
                    }
                }
            } else {
                while (isPlaying && !Thread.interrupted()) {
                    if (buffers2.size() > readBufferIndex) {
                        if (mPlayer != null) {
                            byte[] data = buffers2.get(readBufferIndex);
                            if (data != null) {
                                int readLength = data.length;
                                int length = mPlayer.write(data, 0, readLength, AudioTrack.WRITE_BLOCKING);
                            }
                            readBufferIndex++;
                        }
                    }
                }
            }
            if (isRelease) {
                release();
            } else {
                resetBuffer();
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
                // mPlayer.stop();
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
            resetBuffer();
            print(TAG, "销毁播放器");
        }
    }

    private void resetBuffer() {
        buffers1.reset();
        buffers2.clear();
        readBufferIndex = 0;
        if (mPlayer != null) {
            mPlayer.play();
        }
    }

    public synchronized int unPlayLength() {
        if (useMethod1) {
            int size = buffers1.size() - readBufferIndex;
            return Math.max(size, 0);
        } else {
            try {
                int size = buffers2.size();
                int index = readBufferIndex;
                int i = size - index;
                if (i > 0) {
                    int count = 0;
                    List<byte[]> datas = buffers2.subList(index, size);
                    for (int k = 0; k < datas.size(); k++) {
                        count += datas.get(k).length;
                    }
                    return count;
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
            return 0;
        }
    }


    private static void print(String tag, String msg) {
        if (BuildConfig.DEBUG) {
            Log.e(tag, msg);
        }
    }

}
