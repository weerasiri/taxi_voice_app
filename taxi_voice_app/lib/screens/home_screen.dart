import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'booking_screen.dart';
import 'cancel_screen.dart';
import '../services/supabase_service.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _triggerWordDetected = false;
  String _command = '';
  final FlutterTts _tts = FlutterTts();
  final _supabaseService = SupabaseService();
  Map<String, dynamic>? _currentUser;

  // Lists of keyword variations for command recognition
  final List<String> _bookingKeywords = [
    'book',
    'booking',
    'ride',
    'taxi',
    'car',
    'order',
    'need',
    'want',
    'take',
    'get',
    'request',
    'reserve',
    'hire',
    'call'
  ];

  final List<String> _cancelKeywords = [
    'cancel',
    'stop',
    'end',
    'abort',
    'terminate',
    'delete',
    'remove',
    'drop',
    'nevermind',
    'forget',
    'don\'t want',
    'don\'t need',
    'do not'
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _setupTts();
    _loadUserAndInitSpeech();
  }

  Future<void> _loadUserAndInitSpeech() async {
    final user = await _supabaseService.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
    _initSpeech();
  }

  void _setupTts() {
    _tts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
      // Stop listening while speaking to prevent feedback loop
      if (_isListening) {
        _speech.stop();
        setState(() {
          _isListening = false;
        });
      }
    });

    _tts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
      // Resume listening after speech is complete
      if (!_isListening) {
        Future.delayed(Duration(milliseconds: 300), () {
          _startListening();
        });
      }
    });
  }

  void _initSpeech() async {
    await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' && _isListening) {
          // Only restart listening if not currently speaking
          if (!_isSpeaking) {
            Future.delayed(Duration(milliseconds: 500), () {
              _startListening();
            });
          }
        }
      },
    );

    String welcomeMessage = "Welcome to Taxi Voice";
    if (_currentUser != null) {
      welcomeMessage += ", ${_currentUser!['name']}";
    }
    welcomeMessage += ". Say 'taxi' to begin.";

    _speak(welcomeMessage);
  }

  Future<void> _speak(String message) async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
      });
    }

    await _tts.speak(message);
  }

  // Check if the command contains any booking-related keywords
  bool _isBookingCommand(String command) {
    command = command.toLowerCase();

    // Simple booking commands should work
    if (command.contains('book')) {
      return true;
    }

    // First check for direct booking phrases
    if (command.contains('ride') ||
        command.contains('taxi') ||
        command.contains('car') ||
        command.contains('need') ||
        command.contains('want') ||
        command.contains('get') ||
        command.contains('order')) {
      return true;
    }

    // Check other booking keywords
    for (var keyword in _bookingKeywords) {
      if (command.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  // Check if the command contains any cancellation-related keywords
  bool _isCancelCommand(String command) {
    command = command.toLowerCase();

    // Simple cancel command
    if (command.contains('cancel')) {
      return true;
    }

    // Check for direct cancel phrases
    if (command.contains('stop') ||
        command.contains('end') ||
        command.contains('terminate')) {
      return true;
    }

    // Check other cancel keywords
    for (var keyword in _cancelKeywords) {
      if (command.contains(keyword)) {
        return true;
      }
    }

    return false;
  }

  void _startListening() async {
    // Don't start listening if currently speaking
    if (_isSpeaking) {
      return;
    }

    if (!_speech.isAvailable) {
      return;
    }

    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (val) async {
        // Don't process results if currently speaking
        if (_isSpeaking) {
          return;
        }

        setState(() {
          _command = val.recognizedWords;
        });

        if (!_triggerWordDetected) {
          // Check for trigger word
          if (_command.toLowerCase().contains('taxi')) {
            setState(() {
              _triggerWordDetected = true;
              _command = '';
            });

            String message = "Taxi activated. ";
            if (_currentUser != null) {
              message += "Hello ${_currentUser!['name']}. ";
            }
            message +=
                "How can I help you? Say 'book' for a ride or 'cancel' to cancel a ride.";

            await _speak(message);
          }
        } else {
          // Process commands after trigger word detected
          if (_isBookingCommand(_command)) {
            await _speak("Booking a ride for you now.");

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BookingScreen(
                  userName: _currentUser?['name'] ?? '',
                ),
              ),
            );
          } else if (_isCancelCommand(_command)) {
            await _speak("Cancelling your ride.");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CancelScreen()),
            );
          } else if (_command.toLowerCase().contains('logout')) {
            await _speak("Logging you out.");
            await _supabaseService.logout();
            Navigator.pushReplacementNamed(context, '/register');
          } else if (_command.isNotEmpty) {
            await _speak(
                "I didn't understand that. Please say 'book' for a ride or 'cancel' to cancel an existing ride.");
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Color(0xFF212121)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // App Bar
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'VOICE TAXI',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    if (_currentUser != null)
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: Colors.amber, size: 16),
                            SizedBox(width: 4),
                            Text(
                              _currentUser!['name'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Sound wave animation when listening
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300),
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Colors.amber.withOpacity(0.2)
                              : (_isSpeaking
                                  ? Colors.blue.withOpacity(0.2)
                                  : Colors.transparent),
                          border: Border.all(
                            color: _isSpeaking ? Colors.blue : Colors.amber,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _isSpeaking
                                ? Icons.volume_up
                                : (_triggerWordDetected
                                    ? Icons.taxi_alert
                                    : Icons.mic),
                            size: 80,
                            color: _isSpeaking ? Colors.blue : Colors.amber,
                          ),
                        ),
                      ),
                      SizedBox(height: 40),

                      // Status text
                      Text(
                        _isSpeaking
                            ? 'Speaking...'
                            : (_triggerWordDetected
                                ? 'Listening for commands...'
                                : 'Say "TAXI" to start'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 20),

                      // Speech recognition text
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _command.isEmpty
                              ? 'Waiting for voice input...'
                              : '"$_command"',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom instruction - voice guidance reference only
              SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
