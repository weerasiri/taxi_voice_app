import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'booking_screen.dart';
import 'cancel_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = '';
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _speak("Welcome! Say 'Book a ride' or 'Cancel ride'.");
    _startListening();
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) async {
          setState(() {
            _command = val.recognizedWords;
          });

          if (_command.toLowerCase().contains('book')) {
            await _speak("Booking a ride for you now.");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BookingScreen()),
            );
          } else if (_command.toLowerCase().contains('cancel')) {
            await _speak("Cancelling your ride.");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CancelScreen()),
            );
          } else {
            await _speak("I didn't understand that. Please say again.");
          }
        },
      );
    } else {
      await _speak("Speech not available.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Taxi App - Voice Control')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 100, color: Colors.amber),
            SizedBox(height: 20),
            Text('Listening for commands...', style: TextStyle(fontSize: 22)),
            SizedBox(height: 20),
            Text(
              _command,
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
