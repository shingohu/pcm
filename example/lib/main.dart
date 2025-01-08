import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
                          PCMRecorder.start(
                              preFrameSize: 160,
                              echoCancel: true,
                              autoGain: true,
                              noiseSuppress: true,
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
