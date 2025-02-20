import 'package:flutter/material.dart';
import 'package:flutter_recorder/flutter_recorder.dart';
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
  PCMPlayer player = PCMPlayer();

  final recorder = Recorder.instance;

  @override
  void initState() {
    recorder.init(sampleRate: 8000);
    recorder.uint8ListStream.listen(onAudio);
    super.initState();
  }

  void onAudio(AudioDataContainer container) {
    print(DateTime.now().millisecondsSinceEpoch);
    player.play();
    player.feed(container.rawData);
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
                        // recorder.startStreamingData();
                        // print(DateTime.now().millisecondsSinceEpoch);
                        // recorder.start();
                        List<int> list = [];
                        PCMRecorder.start(
                            echoCancel: false,
                            onData: (data) {
                              //print(DateTime.now().millisecondsSinceEpoch);
                              if (data != null) {
                                list.addAll(data);
                                if (list.length >= 16000) {
                                  player.play();
                                  player.feed(Uint8List.fromList(list));
                                  list.clear();
                                }
                              } else {
                                player.play();
                              }
                            });
                      },
                      child: Text('开始录音')),
                  TextButton(
                      onPressed: () {
                        PCMRecorder.stop();
                        recorder.stop();
                        recorder.stopStreamingData();
                      },
                      child: Text('结束录音')),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
