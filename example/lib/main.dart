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
                      onPressed: () {
                        PCMRecorder.start();
                      },
                      child: Text('开始录音')),
                  TextButton(
                      onPressed: () {
                        PCMRecorder.stop();
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
