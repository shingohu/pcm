package com.lianke.pcm;

import android.util.Log;


public class Util {

    public static boolean enableLog = true;

    /// 打印日志
    public static void print(String msg) {
        if (enableLog) {
            Log.d("[PCM]" + "[" + System.currentTimeMillis() + "] ", msg);
        }
    }

}
