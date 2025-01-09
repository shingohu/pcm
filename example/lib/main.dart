import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PCMLib.hotRestart();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PCMPlayer pcmPlayer = PCMPlayer(sampleRateInHz: 8000);

  @override
  void initState() {
    super.initState();
    loadBeep();
  }

  void loadBeep() {
    BeepPlayer.load("assets/hear_start.aac");
    BeepPlayer.load("assets/hear_end.aac");
    BeepPlayer.load("assets/blecn.aac");
    BeepPlayer.load("assets/blediscn.aac");
  }

  @override
  Widget build(BuildContext context) {
    return OKToast(
      child: MaterialApp(
        home: Builder(builder: (context) {
          return Scaffold(
            appBar: AppBar(),
            body: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                child: Column(
                  children: [
                    TextButton(
                        onPressed: () async {
                          PCMRecorder.useRecordOnMobilePlatform(false);
                          pcmPlayer.setUp(sampleRateInHz: 8000);
                          bool success =
                              await PCMRecorder.requestRecordPermission();
                          int start = DateTime.now().millisecondsSinceEpoch;
                          int i = 0;
                          BeepPlayer.play("assets/hear_start.aac");
                          PCMRecorder.start(
                              preFrameSize: 320,
                              echoCancel: true,
                              autoGain: true,
                              noiseSuppress: false,
                              onData: (data) {
                                if (i == 0) {
                                  i = 1;
                                  print(
                                      "第一帧耗时:${DateTime.now().millisecondsSinceEpoch - start}");
                                }
                                if (data != null) {
                                  pcmPlayer.play();
                                  pcmPlayer.feed(data);
                                }
                              });
                        },
                        child: Text("开始录音")),
                    TextButton(
                        onPressed: () async {
                          await PCMRecorder.stop();
                          pcmPlayer.release();
                        },
                        child: Text("结束录音")),
                    TextButton(
                        onPressed: () async {
                          BeepPlayer.play("assets/hear_start.aac");
                          //BeepPlayer.play("assets/hear_start.wav");
                          // BeepPlayer.play("assets/hear_end.wav");
                          // BeepPlayer.play("assets/blecn.mp3");
                        },
                        child: Text("播放Beep")),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
