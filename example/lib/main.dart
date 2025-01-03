import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioManager.initialize();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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
                          await PCMRecorder.requestRecordPermission();
                          int start = DateTime.now().millisecondsSinceEpoch;
                          int i = 0;
                          PCMRecorder.start(
                              enableAEC: false,
                              preFrameSize: 160,
                              onData: (data) {
                                if (i == 0) {
                                  i = 1;
                                  print(
                                      "第一帧耗时:${DateTime.now().millisecondsSinceEpoch - start}");
                                }
                                if (data != null) {
                                  PCMPlayer.play(data);
                                }
                              });
                        },
                        child: Text("开始录音")),
                    TextButton(
                        onPressed: () async {
                          await PCMRecorder.stop();
                          await PCMPlayer.stop();
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
