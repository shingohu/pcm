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
              ),
            ),
          );
        }),
      ),
    );
  }
}
