import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceMessageScreen extends StatefulWidget {
  @override
  _VoiceMessageScreenState createState() => _VoiceMessageScreenState();
}

class _VoiceMessageScreenState extends State<VoiceMessageScreen> {
  late stt.SpeechToText _speech;
  String _message = "";
  final _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _tts.speak("Please say your message to the driver.");
  }

  void _startListening() async {
    await _speech.initialize();
    _speech.listen(
      onResult: (result) {
        setState(() => _message = result.recognizedWords);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Voice Message")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Your Message:", style: TextStyle(fontSize: 20)),
            SizedBox(height: 10),
            Text(_message, style: TextStyle(fontSize: 22)),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _startListening,
              child: Text("Start Speaking"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            ),
          ],
        ),
      ),
    );
  }
}
