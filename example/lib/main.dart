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
  PCMPlayer player = PCMPlayer(enableAEC: true);

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
              child: Column(
                children: [
                  TextButton(
                      onPressed: () async {
                        List<int> list = [];
                        await PCMRecorder.requestRecordPermission();
                        PCMRecorder.start(
                            echoCancel: false,
                            onData: (data) {
                              if (data != null) {
                                list.addAll(data);
                                if (list.length >= 16000) {
                                  player.play();
                                  player.feed(Uint8List.fromList(list));
                                  list.clear();
                                }
                              }
                            });
                      },
                      child: Text('开始录音')),
                  TextButton(
                      onPressed: () {
                        PCMRecorder.stop();
                        player.stop();
                      },
                      child: Text('结束录音')),
                  TextButton(onPressed: () async {}, child: Text('测试')),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
