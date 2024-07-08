// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:oktoast/oktoast.dart';
// import 'package:pcm/pcm.dart';
// import 'package:webrtc_aecm/webrtc_aecm.dart';
//
// ///webrct aecm demo
// class WebrtcAECMDemoPage extends StatefulWidget {
//   const WebrtcAECMDemoPage({super.key});
//
//   @override
//   State<WebrtcAECMDemoPage> createState() => _WebrtcAECMDemoPageState();
// }
//
// class _WebrtcAECMDemoPageState extends State<WebrtcAECMDemoPage> {
//   WebrtcAECM webrtcAECM = WebrtcAECM();
//
//   @override
//   void initState() {
//     super.initState();
//   }
//
//   @override
//   void dispose() {
//     webrtcAECM.release();
//     PCMRecorder.release();
//     PCMPlayer.release();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("输出测试"),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             TextButton(
//                 onPressed: () {
//                   startRecord();
//                 },
//                 child: Text("开始录音")),
//             TextButton(
//                 onPressed: () {
//                   stopRecord();
//                 },
//                 child: Text("结束录音")),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Future<void> startRecord() async {
//     bool hasPermission = await PCMRecorder.requestRecordPermission();
//     if (hasPermission) {
//       await requestAudioFocus();
//       webrtcAECM.init(8000);
//       webrtcAECM.setConfig();
//       PCMRecorder.start(
//           preFrameSize: 160,
//           audioSource: AudioSource.MIC,
//           onData: (audio) async {
//             if (audio != null) {
//               audio = webrtcAECM.process(audio, deleyMS: 100);
//               webrtcAECM.bufferFarEnd(audio);
//               PCMPlayer.start(audio, voiceCall: false);
//             }
//           });
//     } else {
//       showToast("没有录音权限");
//     }
//   }
//
//   Future<void> requestAudioFocus() async {
//     if (Platform.isIOS) {
//       await AudioManager.setPlayAndRecordSession(defaultToSpeaker: true);
//     }
//   }
//
//   Future<void> abandonAudioFocus() async {
//     AudioManager.abandonAudioFocus();
//   }
//
//   Future<void> stopRecord() async {
//     await PCMRecorder.stop();
//     await PCMPlayer.stop();
//     await abandonAudioFocus();
//   }
// }
