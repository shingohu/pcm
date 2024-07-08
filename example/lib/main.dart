import 'package:flutter/material.dart';
import 'package:oktoast/oktoast.dart';
import 'package:pcm/pcm.dart';
import 'package:pcm_example/audio_output_demo.dart';

import 'webrtc_agc_demo.dart';
import 'webrtc_ns_demo.dart';

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
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (ctx) {
                            return AudioOutputDemoPage();
                          }));
                        },
                        child: Text("音频输出设备测试")),
                    TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (ctx) {
                            return WebrtcNSDemoPage();
                          }));
                        },
                        child: Text("降噪测试")),
                    TextButton(
                        onPressed: () {
                          Navigator.of(context)
                              .push(MaterialPageRoute(builder: (ctx) {
                            return WebrtcAGCDemoPage();
                          }));
                        },
                        child: Text("自动增益测试")),
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
