package com.lianke.pcm.adpcm;


public class Adpcm {
    private static String TAG = "AdPcm";
    private static final int stepsizeTable[] = {7, 8, 9, 10, 11, 12, 13, 14,
            16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73,
            80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279,
            307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963,
            1060, 1166, 1282, 1411, 1552, 1707, 1878, 2066, 2272, 2499, 2749,
            3024, 3327, 3660, 4026, 4428, 4871, 5358, 5894, 6484, 7132, 7845,
            8630, 9493, 10442, 11487, 12635, 13899, 15289, 16818, 18500, 20350,
            22385, 24623, 27086, 29794, 32767};

    private static final int indexTable[] = {-1, -1, -1, -1, 2, 4, 6, 8, -1,
            -1, -1, -1, 2, 4, 6, 8,};
    int g_enindex = 0;
    int g_envalpred = 0;
    int g_deindex = 0;
    int g_devalpred = 0;


    public byte[] encode(short[] indata) {
        int val;
        int sign;
        int delta;
        int diff;
        int step;
        int valpred;
        int vpdiff;
        int index;
        int outputbuffer = 0;
        int bufferstep;

        int len = indata.length;

        byte[] outdata = new byte[len / 2];

        valpred = g_envalpred;
        index = g_enindex;
        step = stepsizeTable[index];
        bufferstep = 1;
        int i = 0;
        int outp = 0;

        for (; len > 0; len--) {
            val = indata[i++];
            diff = val - valpred;
            sign = (diff < 0) ? 8 : 0;
            if (sign != 0)
                diff = (-diff);
            delta = 0;
            vpdiff = (step >> 3);
            if (diff >= step) {
                delta = 4;
                diff -= step;
                vpdiff += step;
            }
            step >>= 1;
            if (diff >= step) {
                delta |= 2;
                diff -= step;
                vpdiff += step;
            }
            step >>= 1;
            if (diff >= step) {
                delta |= 1;
                vpdiff += step;
            }

            if (sign != 0)
                valpred -= vpdiff;
            else
                valpred += vpdiff;

            if (valpred > 32767)
                valpred = 32767;
            else if (valpred < -32768)
                valpred = -32768;

            delta |= sign;

            index += indexTable[delta];
            if (index < 0)
                index = 0;
            if (index > 88)
                index = 88;
            step = stepsizeTable[index];


            if (0 != bufferstep) {
                outputbuffer = (delta << 4) & 0xf0;
            } else {
                outdata[outp++] = (byte) ((delta & 0x0f) | outputbuffer);
            }
            bufferstep = (0 == bufferstep) ? 1 : 0;
        }


        if (0 == bufferstep) {
            outp++;
            if (outp < outdata.length) {
                outdata[outp] = (byte) outputbuffer;
            }
        }

        g_envalpred = valpred;
        g_enindex = index;
        return outdata;
    }


    public short[] decode(byte[] input) {
        int sign;
        int delta;
        int step;
        int valpred;
        int vpdiff;
        int index;
        int inputbuffer = 0;
        int bufferstep;
        int outp = 0;


        short[] output = new short[input.length * 2];

        int len = input.length * 2;

        valpred = g_devalpred;
        index = g_deindex;
        step = stepsizeTable[index];
        bufferstep = 0;


        int inpI = 0;
        for (; len > 0; len--) {
            if (0 == bufferstep) {
                inputbuffer = input[inpI++];
                delta = (inputbuffer >> 4) & 0xf;
                bufferstep = 1;
            } else {
                delta = inputbuffer & 0xf;
                bufferstep = 0;
            }


            index += indexTable[delta];
            if (index < 0)
                index = 0;
            if (index > 88)
                index = 88;


            sign = delta & 8;
            delta = delta & 7;


            vpdiff = step >> 3;
            if ((delta & 4) != 0)
                vpdiff += step;
            if ((delta & 2) != 0)
                vpdiff += step >> 1;
            if ((delta & 1) != 0)
                vpdiff += step >> 2;

            if (0 != sign)
                valpred -= vpdiff;
            else
                valpred += vpdiff;


            if (valpred > 32767)
                valpred = 32767;
            else if (valpred < -32768)
                valpred = -32768;

            step = stepsizeTable[index];
            output[outp++] = (short) valpred;
        }
        g_devalpred = valpred;
        g_deindex = index;
        return output;
    }


    void reset() {
        g_enindex = 0;
        g_deindex = 0;
        g_devalpred = 0;
        g_envalpred = 0;
    }


}
