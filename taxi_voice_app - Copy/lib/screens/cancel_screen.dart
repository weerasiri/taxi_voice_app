import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CancelScreen extends StatefulWidget {
  @override
  State<CancelScreen> createState() => _CancelScreenState();
}

class _CancelScreenState extends State<CancelScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speak("Your ride has been canceled.");
  }

  Future<void> _speak(String msg) async {
    await _tts.speak(msg);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cancel Ride")),
      body: Center(
        child: Text("Ride Canceled", style: TextStyle(fontSize: 24)),
      ),
    );
  }
}
