package com.lianke.pcm.adpcm;

public class AdpcmUtil {

    static Adpcm encoder = new Adpcm();
    static Adpcm decoder = new Adpcm();


    public static byte[] startEncode(byte[] data) {
        short[] shorts = byteToShort(data);
        return encoder.encode(shorts);
    }

    ///注意需要释放编解码
    public static void endEncode() {
        encoder.reset();
    }

    public static byte[] startDecode(byte[] data) {
        return shortToByte(decoder.decode(data));
    }

    ///注意需要释放编解码
    public static void endDecode() {
        decoder.reset();
    }


    public static short[] byteToShort(byte[] data) {
        short[] shortValue = new short[data.length / 2];
        for (int i = 0; i < shortValue.length; i++) {
            int ss = ((data[i * 2] & 0xff) | ((data[i * 2 + 1] & 0xff) << 8));
            shortValue[i] = (short)(ss);
        }
        return shortValue;
    }


    public static byte[] shortToByte(short[] data) {
        byte[] byteValue = new byte[data.length * 2];
        for (int i = 0; i < data.length; i++) {
            byteValue[i * 2] = (byte) (data[i] & 0xff);
            byteValue[i * 2 + 1] = (byte) ((data[i] & 0xff00) >> 8);
        }
        return byteValue;
    }

}
