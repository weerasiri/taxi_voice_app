import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SosScreen extends StatelessWidget {
  final _tts = FlutterTts();

  SosScreen({super.key}) {
    _tts.speak("Emergency alert sent to your contact and driver.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Emergency SOS")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning, size: 100, color: Colors.red),
            SizedBox(height: 20),
            Text("SOS Activated", style: TextStyle(fontSize: 26)),
          ],
        ),
      ),
    );
  }
}
