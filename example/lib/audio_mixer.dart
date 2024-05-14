import 'dart:typed_data';

///混音
///https://shumei52.top/index.php/archives/audio_mixer.html
class AudioMixer {
  AudioMixer._();

  ///音频列表混音
  static Uint8List? mix(List<Uint8List> audioList) {
    int length = audioList.length;
    if (length > 0) {
      if (length == 1) {
        return audioList.first;
      } else if (length > 1) {
        Uint8List temp = _newlc(audioList[0], audioList[1]);
        for (int k = 0; k < length - 2; k++) {
          temp = _newlc(temp, audioList[k + 2]);
        }
        return temp;
      }
    }
    return null;
  }

  ///newlc中两路混音算法
  ///C=A+B-(A*B/32767)
  static Uint8List _newlc(Uint8List b1, Uint8List b2) {
    List<int> sig_out = [];
    Int16List sig1 = _bytesToInt16List(b1);
    Int16List sig2 = _bytesToInt16List(b2);

    int length1 = sig1.length;
    int length2 = sig1.length;

    ///长度不一致则补0
    if (length1 < length2) {
      sig1.addAll(List.generate(length2 - length1, (index) => 0));
    } else if (length2 < length1) {
      sig2.addAll(List.generate(length1 - length2, (index) => 0));
    }

    for (int i = 0; i < sig1.length; i++) {
      if (sig1[i] < 0 && sig2[i] < 0) {
        sig_out.add(sig1[i] + sig2[i] - sig1[i] * sig2[i] ~/ -(32767));
      } else {
        sig_out.add(sig1[i] + sig2[i] - (sig1[i] * sig2[i] ~/ (32767)));
      }
    }
    return _int16ListToBytes(Int16List.fromList(sig_out));
  }

  static Int16List _bytesToInt16List(Uint8List bytes) {
    Int16List shorts = Int16List(bytes.length ~/ 2);
    for (int i = 0; i < shorts.length; i++) {
      shorts[i] = (bytes[i * 2] & 0xff | ((bytes[i * 2 + 1] & 0xff) << 8));
    }
    return shorts;
  }

  static Uint8List _int16ListToBytes(Int16List int16list) {
    Uint8List bytes = Uint8List(int16list.length * 2);
    for (int i = 0; i < int16list.length; i++) {
      bytes[i * 2] = int16list[i] & 0xff;
      bytes[i * 2 + 1] = (int16list[i] >> 8) & 0xff;
    }
    return bytes;
  }
}
