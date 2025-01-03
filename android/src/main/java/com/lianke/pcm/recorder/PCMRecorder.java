package com.lianke.pcm.recorder;

import static java.lang.Thread.MAX_PRIORITY;

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

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Arrays;


/**
 * 音频录制
 */
public class PCMRecorder {
    private final static String TAG = "PCMRecorder";
    //=======================AudioRecord Default Settings=======================
    private static final int AUDIO_SOURCE_MIC = MediaRecorder.AudioSource.MIC;
    private static final int AUDIO_SOURCE_VC = MediaRecorder.AudioSource.VOICE_COMMUNICATION;
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

    private int PRE_READ_LENGTH = 320;

    private Thread mAudioHandleRunner = null;
    private RecordListener recordListener;
    private ByteArrayOutputStream mSampleBuffer = new ByteArrayOutputStream();
    private int readBufferIndex = 0;

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
    public boolean init(int sampleRateInHz, int perFrameSize, boolean enableAEC) {
        if (mAudioRecord == null) {
            mSampleBuffer.reset();
            readBufferIndex = 0;
            int bufferSize = AudioRecord.getMinBufferSize(sampleRateInHz,
                    DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT);
            if (bufferSize < perFrameSize) {
                bufferSize = perFrameSize;
            }
            this.PRE_READ_LENGTH = perFrameSize;

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                mAudioRecord = new AudioRecord.Builder()
                        .setAudioFormat(new AudioFormat.Builder()
                                .setSampleRate(sampleRateInHz)
                                .setChannelMask(DEFAULT_CHANNEL_CONFIG)
                                .setEncoding(DEFAULT_AUDIO_FORMAT)
                                .build())
                        .setAudioSource(enableAEC ? AUDIO_SOURCE_VC : AUDIO_SOURCE_MIC)
                        .setBufferSizeInBytes(bufferSize)
                        .build();
            } else {
                mAudioRecord = new AudioRecord(enableAEC ? AUDIO_SOURCE_VC : AUDIO_SOURCE_MIC,
                        sampleRateInHz, DEFAULT_CHANNEL_CONFIG, DEFAULT_AUDIO_FORMAT,
                        bufferSize);
            }
            if (mAudioRecord.getState() == AudioRecord.STATE_INITIALIZED) {
                if (enableAEC) {
                    int audioSessionId = mAudioRecord.getAudioSessionId();
                    new Thread(() -> {
                        enableAEC(audioSessionId);
                        enableNS(audioSessionId);
                        enableAGC(audioSessionId);
                    }).start();
                }
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
                print("开始录音");
            } else {
                print("启动录音失败");
            }
        } catch (Exception e) {
            e.printStackTrace();
            print("启动录音失败");
            stop();
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
                int readLength = PRE_READ_LENGTH;
                byte[] pcmBuffer = new byte[readLength];
                while (isRecording && !Thread.interrupted() && mAudioRecord != null) {
                    int state = mAudioRecord.getRecordingState();
                    if (state != AudioRecord.RECORDSTATE_RECORDING) {
                        continue;
                    }
                    int readSize = mAudioRecord.read(pcmBuffer, 0, readLength);
                    if (readSize > 0) {
                        try {
                            mSampleBuffer.write(Arrays.copyOf(pcmBuffer, readSize));
                            while (mSampleBuffer.size() - readBufferIndex >= PRE_READ_LENGTH) {
                                int length = PRE_READ_LENGTH;
                                byte[] buffer = new byte[length];
                                System.arraycopy(mSampleBuffer.toByteArray(), readBufferIndex, buffer, 0, length);
                                readBufferIndex += length;
                                if (recordListener != null) {
                                    recordListener.onAudioProcess(buffer);
                                }
                            }
                        } catch (IOException e) {

                        }
                    }

                }
                if (recordListener != null) {
                    recordListener.onAudioProcess(null);
                }
            }
        };
        mAudioHandleRunner.setPriority(MAX_PRIORITY);
        mAudioHandleRunner.start();
    }


    private void stopRecordingRunner() {
        if (mAudioHandleRunner != null) {
            mAudioHandleRunner.interrupt();
            try {
                mAudioHandleRunner.join();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            mAudioHandleRunner = null;
        }


    }

    public synchronized void stop() {
        if (mAudioRecord != null) {
            isRecording = false;
            mAudioRecord.stop();
        }
        stopRecordingRunner();
        if (mAudioRecord != null) {
            isRecording = false;
            mAudioRecord.release();
            mAudioRecord = null;
            print("结束录音");
        }
        mSampleBuffer.reset();
        readBufferIndex = 0;
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

    private void print(String msg) {
        if (BuildConfig.DEBUG) {
            Log.d(TAG, msg);
        }
    }
}
