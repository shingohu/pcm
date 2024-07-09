package com.lianke.pcm.recorder;


import android.annotation.SuppressLint;
import android.media.AudioFormat;
import android.media.AudioRecord;
import android.media.MediaRecorder;
import android.media.audiofx.AcousticEchoCanceler;
import android.media.audiofx.AudioEffect;
import android.media.audiofx.AutomaticGainControl;
import android.media.audiofx.NoiseSuppressor;
import android.os.Build;
import android.util.Log;
import android.os.Process;

import com.lianke.BuildConfig;


/**
 * 音频录制
 */
public class PCMRecorder {
    private final static String TAG = "PCMRecorder";
    //=======================AudioRecord Default Settings=======================
    private static final int DEFAULT_AUDIO_SOURCE = MediaRecorder.AudioSource.MIC;
    private static final int VOICE_COMMUNICATION = MediaRecorder.AudioSource.VOICE_COMMUNICATION;
    public static final int DEFAULT_SAMPLING_RATE = 8000;//模拟器仅支持从麦克风输入8kHz采样率
    public static final int DEFAULT_CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO;
    public static final int DEFAULT_AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT;

    private static final PCMRecorder instance = new PCMRecorder();

    private PCMRecorder() {
    }

    public static PCMRecorder shared() {
        return instance;
    }

    private AudioRecord mAudioRecord = null;
    //是否正在录音
    private boolean isRecording = false;
    private boolean isRelease = true;

    private int PRE_READ_LENGTH = 320;

    private Thread mAudioHandleRunner = null;
    private RecordListener recordListener;


    public void setRecordListener(RecordListener recordListener) {
        this.recordListener = recordListener;
    }

    /**
     * 初始化录音器
     *
     * @param sampleRateInHz 采样率
     * @param perFrameSize   每帧读取大小
     * @return 初始化是否成功
     */
    public boolean init(int sampleRateInHz, int perFrameSize, int audioSource) {
        if (mAudioRecord == null) {
            int bufferSize = AudioRecord.getMinBufferSize(sampleRateInHz,
                    DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT);
            this.PRE_READ_LENGTH = perFrameSize;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mAudioRecord = new AudioRecord.Builder()
                        .setAudioFormat(new AudioFormat.Builder()
                                .setSampleRate(sampleRateInHz)
                                .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                .setEncoding(DEFAULT_AUDIO_FORMAT)
                                .build())
                        .setAudioSource(audioSource)
                        .setBufferSizeInBytes(bufferSize)
                        .build();
            } else {
                mAudioRecord = new AudioRecord(audioSource,
                        sampleRateInHz, DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT,
                        bufferSize);
            }
            isRelease = false;
            if (mAudioRecord.getState() == AudioRecord.STATE_INITIALIZED) {
                int audioSessionId = mAudioRecord.getAudioSessionId();
                enableAEC(audioSessionId);
                enableNS(audioSessionId);
                enableAGC(audioSessionId);
                return true;
            }
            mAudioRecord = null;
            return false;
        }

        return true;
    }

    public boolean isRecording() {
        return isRecording;
    }

    public boolean start() {
        try {
            if (isRecording) {
                return true;
            }
            if (mAudioRecord != null) {
                isRecording = true;
                mAudioRecord.startRecording();
                startRecordingRunner();
            } else {
                Log.e(TAG, "启动录音失败");
            }
        } catch (Exception e) {
            e.printStackTrace();
            Log.e(TAG, "启动录音失败");
            release();
        }
        return isRecording;
    }

    ///启动录音线程
    private void startRecordingRunner() {
        mAudioHandleRunner = new Thread() {
            @Override
            public void run() {
                ///设置优先级
                Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO);
                byte[] pcmBuffer = new byte[PRE_READ_LENGTH];
                while (isRecording && !Thread.interrupted()) {
                    if (mAudioRecord.getRecordingState() == AudioRecord.RECORDSTATE_RECORDING) {
                        int readSize = mAudioRecord.read(pcmBuffer, 0, PRE_READ_LENGTH);
                        if (readSize > 0) {
                            if (readSize >= PRE_READ_LENGTH) {
                                if (recordListener != null) {
                                    recordListener.onAudioProcess(pcmBuffer);
                                }
                            }
                        }
                    }
                }
                if (recordListener != null) {
                    recordListener.onAudioProcess(null);
                }
                if (isRelease) {
                    release();
                }
            }
        };
        mAudioHandleRunner.start();
    }


    private void stopRecordingRunner() {
        if (mAudioHandleRunner != null && !mAudioHandleRunner.isInterrupted()) {
            mAudioHandleRunner.interrupt();
        }
        mAudioHandleRunner = null;
    }

    public synchronized void stop() {
        if (mAudioRecord != null) {
            if (isRecording) {
                isRecording = false;
                mAudioRecord.stop();
                stopRecordingRunner();
            }
        }
    }


    public synchronized void release() {
        this.isRelease = true;
        if (isRecording) {
            stop();
        } else if (mAudioRecord != null) {
            mAudioRecord.release();
            mAudioRecord = null;
        }
    }


    @SuppressLint("NewApi")
    private static void enableAEC(int audioSessionId) {
        if (AcousticEchoCanceler.isAvailable()) {
            AcousticEchoCanceler acousticEchoCanceler = AcousticEchoCanceler
                    .create(audioSessionId);
            if (acousticEchoCanceler != null) {
                int resultCode = acousticEchoCanceler.setEnabled(true);
                if (AudioEffect.SUCCESS == resultCode) {
                }
            }
        }
    }

    /**
     * 判断噪音抑制是否可用
     */
    @SuppressLint("NewApi")
    private static void enableNS(int audioSessionId) {
        if (NoiseSuppressor.isAvailable()) {
            NoiseSuppressor noiseSuppressor = NoiseSuppressor
                    .create(audioSessionId);
            if (noiseSuppressor != null) {
                int resultCode = noiseSuppressor.setEnabled(true);
                if (AudioEffect.SUCCESS == resultCode) {
                }
            }
        }
    }

    /**
     * 判断自动增益是否可用
     */
    @SuppressLint("NewApi")
    private static void enableAGC(int audioSessionId) {
        if (AutomaticGainControl.isAvailable()) {
            AutomaticGainControl agc = AutomaticGainControl
                    .create(audioSessionId);
            if (agc != null) {
                int resultCode = agc.setEnabled(true);
                if (AudioEffect.SUCCESS == resultCode) {
                }
            }
        }
    }
}
