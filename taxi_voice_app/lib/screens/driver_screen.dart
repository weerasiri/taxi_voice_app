import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/driver_service.dart';
import '../services/socket_service.dart';

class DriverScreen extends StatefulWidget {
  @override
  _DriverScreenState createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _command = '';
  final FlutterTts _tts = FlutterTts();
  final DriverService _driverService = DriverService();
  final SocketService _socketService = SocketService();

  // Ride details
  String _rideId = '';
  String _pickup = '';
  String _destination = '';
  String _userName = '';
  bool _rideStarted = false;
  bool _rideCompleted = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    // Slight delay to allow the arguments to be processed
    Future.delayed(Duration.zero, () {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        setState(() {
          _rideId = args['rideId'] ?? '';
          _pickup = args['pickup'] ?? '';
          _destination = args['destination'] ?? '';
          _userName = args['userName'] ?? '';
        });
      }
      _initializeVoiceControl();
    });
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
            if (!_isListening && !_rideCompleted) _startListening();
          });
        }
      },
    );

    if (available) {
      // Speak driver details first
      String message = "You are driving to pick up $_userName.";
      if (_pickup.isNotEmpty) {
        message += " Pickup location is $_pickup.";
      }
      if (_destination.isNotEmpty) {
        message += " Destination is $_destination.";
      }
      await _speak(message);
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
    if (_isListening || _rideCompleted) return;

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
                Navigator.pushReplacementNamed(context, '/cancel');
              } else if (command.contains('send') &&
                  command.contains('message')) {
                await _speak("Sending a voice message.");
                Navigator.pushNamed(context, '/message');
              } else if (command.contains('start') &&
                  command.contains('ride') &&
                  !_rideStarted) {
                await _speak("Starting the ride.");
                setState(() => _rideStarted = true);
                _startTrip();
              } else if (command.contains('complete') &&
                  command.contains('ride') &&
                  _rideStarted &&
                  !_rideCompleted) {
                await _speak("Completing the ride.");
                _completeTrip();
              } else if ((command.contains('navigate') ||
                      command.contains('directions')) &&
                  !_rideStarted) {
                await _speak("Providing directions to pickup location.");
                // Implement actual navigation logic here
              } else if (command.isNotEmpty && !_rideStarted) {
                await _speak(
                  "Available commands: Start ride, Navigate to pickup, Send message, or Cancel ride.",
                );
              } else if (command.isNotEmpty &&
                  _rideStarted &&
                  !_rideCompleted) {
                await _speak(
                  "Available commands: Complete ride, Send message, or Cancel ride.",
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
      if (!_rideCompleted) _startListening(); // Try to restart listening
    }
  }

  // Function to simulate trip starting
  void _startTrip() async {
    await _speak("Your ride with $_userName is starting now.");
    // Implement actual trip tracking here if needed
    setState(() {
      _rideStarted = true;
    });
  }

  // Function to complete the trip
  void _completeTrip() async {
    try {
      if (_rideId.isNotEmpty) {
        final driverData = await _driverService.getCurrentDriver();
        if (driverData != null) {
          await _driverService.completeRide(_rideId, driverData['id']);

          setState(() {
            _rideCompleted = true;
          });

          await _speak(
              "Your trip has been completed. Thank you for using our service.");

          // Navigate to payment screen after a short delay
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(context, '/payment');
          });
        }
      }
    } catch (e) {
      print('Error completing ride: $e');
      await _speak(
          "There was an error completing your ride. Please try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_rideStarted ? "Active Ride" : "Driver Info")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(
              _rideStarted ? Icons.directions_car_filled : Icons.directions_car,
              size: 100,
              color: Colors.amber,
            ),
            SizedBox(height: 20),
            Text(
              _rideStarted ? "Ride in progress" : "Pickup: $_pickup",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              _rideStarted
                  ? "Destination: $_destination"
                  : "Passenger: $_userName",
              style: TextStyle(fontSize: 22),
            ),
            if (!_rideStarted && _destination.isNotEmpty)
              Text("Destination: $_destination",
                  style: TextStyle(fontSize: 22)),
            SizedBox(height: 30),
            Text(
              _rideStarted
                  ? 'Say "Complete ride" to complete the ride or "Send message" to send a voice message.'
                  : 'Say "Start ride" to begin the trip, "Navigate to pickup" for directions, or "Cancel ride" to cancel.',
              style: TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 30),
            Text(
              'Last command: $_command',
              style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: 30),
            if (!_rideStarted)
              ElevatedButton(
                onPressed: _startTrip,
                child: Text('Start Ride'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            if (_rideStarted && !_rideCompleted)
              ElevatedButton(
                onPressed: _completeTrip,
                child: Text('Complete Ride'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
