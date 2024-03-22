import 'dart:typed_data';

/**
 * 把adpcm转成pcm
 */
class ADPCM2PCM {
/* Intel ADPCM step variation table */
  static final List<int> _indexTable = [
    -1,
    -1,
    -1,
    -1,
    2,
    4,
    6,
    8,
    -1,
    -1,
    -1,
    -1,
    2,
    4,
    6,
    8,
  ];
  static final List _stepsizeTable = [
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    16,
    17,
    19,
    21,
    23,
    25,
    28,
    31,
    34,
    37,
    41,
    45,
    50,
    55,
    60,
    66,
    73,
    80,
    88,
    97,
    107,
    118,
    130,
    143,
    157,
    173,
    190,
    209,
    230,
    253,
    279,
    307,
    337,
    371,
    408,
    449,
    494,
    544,
    598,
    658,
    724,
    796,
    876,
    963,
    1060,
    1166,
    1282,
    1411,
    1552,
    1707,
    1878,
    2066,
    2272,
    2499,
    2749,
    3024,
    3327,
    3660,
    4026,
    4428,
    4871,
    5358,
    5894,
    6484,
    7132,
    7845,
    8630,
    9493,
    10442,
    11487,
    12635,
    13899,
    15289,
    16818,
    18500,
    20350,
    22385,
    24623,
    27086,
    29794,
    32767
  ];
  int _g_deindex = 0;
  int _g_devalpred = 0;

  Uint8List start(Uint8List adpcmData) {
    int sign; /* Current adpcm sign bit */
    int delta; /* Current adpcm output value */
    int step; /* Stepsize */
    int valpred; /* Predicted value */
    int vpdiff; /* Current change to valpred */
    int index; /* Current step change index */
    int inputbuffer = 0; /* place to keep next 4-bit value */
    int bufferstep = 0; /* toggle between inputbuffer/input */
    int indatai = 0;
    int len = adpcmData.length * 2;
    List<int> out = new List.generate(len * 2, (index) => 0);
    int outi = 0;
    valpred = _g_devalpred;
    index = _g_deindex;
    step = _stepsizeTable[index];
    for (; len > 0; len--) {
      /* Step 1 - get the delta value */
      if (0 == bufferstep) {
        inputbuffer = adpcmData[indatai++];
        delta = (inputbuffer >> 4) & 0xf;
        bufferstep = 1;
      } else {
        delta = (inputbuffer) & 0xf;
        bufferstep = 0;
      }
      /* Step 2 - Find new index value (for later) */
      index += _indexTable[delta];
      if (index < 0) index = 0;
      if (index > 88) index = 88;

      /* Step 3 - Separate sign and magnitude */
      sign = delta & 8;
      delta = delta & 7;

      /* Step 4 - Compute difference and new predicted value */
      /*
        ** Computes 'vpdiff = (delta+0.5)*step/4', but see comment
        ** in adpcm_coder.
        */
      vpdiff = step >> 3;
      if (delta & 4 != 0) vpdiff += step;
      if (delta & 2 != 0) vpdiff += step >> 1;
      if (delta & 1 != 0) vpdiff += step >> 2;

      if (sign != 0)
        valpred -= vpdiff;
      else
        valpred += vpdiff;

      /* Step 5 - clamp output value */
      if (valpred > 32767)
        valpred = 32767;
      else if (valpred < -32768) valpred = -32768;

      /* Step 6 - Update step value */
      step = _stepsizeTable[index];

      /* Step 7 - Output value */
      out[outi++] = valpred & 0xFF;
      out[outi++] = (valpred >> 8) & 0xFF;
    }
    _g_devalpred = valpred;
    _g_deindex = index;
    return Uint8List.fromList(out);
  }

  ///重置状态
  ///当编解码结束后必须重置
  void stop() {
    _g_devalpred = 0;
    _g_devalpred = 0;
  }
}

///把PCM转成adpcm
class PCM2ADPCM {
/* Intel ADPCM step variation table */
  static final List<int> _indexTable = [
    -1,
    -1,
    -1,
    -1,
    2,
    4,
    6,
    8,
    -1,
    -1,
    -1,
    -1,
    2,
    4,
    6,
    8,
  ];
  static final List _stepsizeTable = [
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    16,
    17,
    19,
    21,
    23,
    25,
    28,
    31,
    34,
    37,
    41,
    45,
    50,
    55,
    60,
    66,
    73,
    80,
    88,
    97,
    107,
    118,
    130,
    143,
    157,
    173,
    190,
    209,
    230,
    253,
    279,
    307,
    337,
    371,
    408,
    449,
    494,
    544,
    598,
    658,
    724,
    796,
    876,
    963,
    1060,
    1166,
    1282,
    1411,
    1552,
    1707,
    1878,
    2066,
    2272,
    2499,
    2749,
    3024,
    3327,
    3660,
    4026,
    4428,
    4871,
    5358,
    5894,
    6484,
    7132,
    7845,
    8630,
    9493,
    10442,
    11487,
    12635,
    13899,
    15289,
    16818,
    18500,
    20350,
    22385,
    24623,
    27086,
    29794,
    32767
  ];

  int _g_enindex = 0;
  int _g_envalpred = 0;

  ///重置状态
  ///当编解码结束后必须重置
  void stop() {
    _g_enindex = 0;
    _g_envalpred = 0;
  }

  /**
   * 开始编码
   */
  Uint8List start(Uint8List pcmData) {
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

    Int16List shorts = Int16List(pcmData.length ~/ 2);
    for (int i = 0; i < shorts.length; i++) {
      shorts[i] = (pcmData[i * 2] & 0xff | ((pcmData[i * 2 + 1] & 0xff) << 8));
    }
    int len = shorts.length;
    List<int> outdata = List.generate(len ~/ 2, (index) => 0);

    valpred = _g_envalpred;
    index = _g_enindex;
    step = _stepsizeTable[index];
    bufferstep = 1;
    int i = 0;
    int outp = 0;

    for (; len > 0; len--) {
      val = shorts[i++];

      diff = val - valpred;
      sign = (diff < 0) ? 8 : 0;
      if (sign != 0) diff = (-diff);

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
      else if (valpred < -32768) valpred = -32768;

      delta |= sign;

      index += _indexTable[delta];
      if (index < 0) index = 0;
      if (index > 88) index = 88;
      step = _stepsizeTable[index];

      if (0 != bufferstep) {
        outputbuffer = (delta << 4) & 0xf0;
      } else {
        outdata[outp++] = ((delta & 0x0f) | outputbuffer);
      }
      bufferstep = (0 == bufferstep) ? 1 : 0;
    }

    if (0 == bufferstep) {
      outp++;
      if (outp < outdata.length) {
        outdata[outp] = outputbuffer;
      }
    }

    _g_envalpred = valpred;
    _g_enindex = index;
    return Uint8List.fromList(outdata);
  }
}
