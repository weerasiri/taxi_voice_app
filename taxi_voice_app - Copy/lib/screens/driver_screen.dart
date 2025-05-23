import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class DriverScreen extends StatefulWidget {
  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = '';
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeVoiceControl();
  }

  Future<void> _initializeVoiceControl() async {
    // Initialize TTS settings
    await _initTts();

    // Initialize speech recognition
    bool available = await _speech.initialize(
      onError: (error) => print('Speech recognition error: $error'),
      onStatus: (status) {
        print('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
          // Restart listening after a short delay
          Future.delayed(Duration(milliseconds: 500), () {
            if (!_isListening) _startListening();
          });
        }
      },
    );

    if (available) {
      // Speak driver details first
      await _speak(
        "Your driver is on the way. His name is John. Car number ABC-1234.",
      );
      // Start listening immediately after speaking
      _startListening();
    } else {
      await _speak("Speech recognition is not available on this device.");
    }
  }

  // Initialize TTS settings
  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.9); // Slightly faster but still clear
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // Function to speak a message
  Future<void> _speak(String message) async {
    try {
      if (_isListening) {
        await _speech.stop();
        setState(() => _isListening = false);
      }
      print('Speaking: $message');
      await _tts.speak(message);
      await _tts.awaitSpeakCompletion(true);
    } catch (e) {
      print('TTS Error: $e');
    }
  }

  // Function to start speech recognition
  void _startListening() async {
    if (_isListening) return;

    try {
      if (await _speech.hasPermission) {
        setState(() => _isListening = true);
        print('Starting to listen...');

        await _speech.listen(
          onResult: (result) async {
            print(
                'Got result: ${result.recognizedWords} (${result.finalResult ? 'final' : 'partial'})');

            if (result.finalResult) {
              setState(() => _command = result.recognizedWords);

              // Convert to lowercase for better matching
              String command = result.recognizedWords.toLowerCase();

              if (command.contains('cancel') && command.contains('ride')) {
                await _speak("Cancelling your ride.");
                Navigator.pushNamed(context, '/cancel');
              } else if (command.contains('send') &&
                  command.contains('message')) {
                await _speak("Sending a voice message.");
                Navigator.pushNamed(context, '/message');
              } else if (command.isNotEmpty) {
                await _speak(
                  "I didn't catch that. Please say either Cancel ride or Send message.",
                );
              }
            }
          },
          listenFor: Duration(seconds: 10),
          pauseFor: Duration(seconds: 5),
          partialResults: true,
          listenMode: stt.ListenMode.confirmation,
          cancelOnError: false,
          onDevice: true, // Try to use on-device recognition if available
        );
      } else {
        print('No microphone permission');
        await _speak(
            "Please enable microphone permission in your phone settings.");
      }
    } catch (e) {
      print('Listen error: $e');
      setState(() => _isListening = false);
      _startListening(); // Try to restart listening
    }
  }

  // Function to simulate trip starting and ending
  void _startTrip() async {
    await _speak("Your driver has arrived. The trip is starting now.");
    // Simulate showing route tracking (you can replace this with a map widget)
    setState(() {
      // Trigger the UI to show tracking
    });

    // Simulate trip ending after some time
    Future.delayed(Duration(seconds: 30), () async {
      await _speak("Your trip has ended. Proceeding to payment.");
      // Show payment options or navigate to payment screen
      Navigator.pushNamed(context, '/payment');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Driver Info")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(Icons.directions_car, size: 100, color: Colors.amber),
            SizedBox(height: 20),
            Text("Driver: John", style: TextStyle(fontSize: 24)),
            Text("Car Number: ABC-1234", style: TextStyle(fontSize: 22)),
            Text("ETA: 5 minutes", style: TextStyle(fontSize: 22)),
            SizedBox(height: 30),
            Text(
              'Say "Cancel ride" to cancel the ride or "Send message" to send a voice message.',
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 30),
            Text(
              'Command: $_command',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
