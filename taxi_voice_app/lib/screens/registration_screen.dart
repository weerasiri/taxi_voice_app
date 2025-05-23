import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/supabase_service.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _command = '';
  String _userName = '';
  bool _askingForName = false;
  final FlutterTts _tts = FlutterTts();
  final _supabaseService = SupabaseService();
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _setupTts();
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
    _speak(
        "Welcome to Taxi Voice. To get started, you need to register. Say 'register' to continue.");
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

  void _startListening() async {
    // Don't start listening if currently speaking
    if (_isSpeaking || _isRegistering) {
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

        if (_askingForName) {
          if (_command.isNotEmpty) {
            setState(() {
              _userName = _command;
              _askingForName = false;
              _isRegistering = true;
            });

            await _speak("Thank you, ${_userName}. I am registering you now.");

            // Register user
            final result = await _supabaseService.registerUser(_userName);

            setState(() {
              _isRegistering = false;
            });

            if (result['success']) {
              await _speak(result['message']);

              // Navigate to home screen after successful registration
              Navigator.pushReplacementNamed(context, '/home');
            } else {
              await _speak(
                  "Registration failed. ${result['message']}. Please try again.");

              // Reset and start over
              setState(() {
                _userName = '';
                _askingForName = false;
              });

              await _speak("Say 'register' to try again.");
            }
          }
        } else if (_command.toLowerCase().contains('register')) {
          await _speak("Great! Let's get you registered. What is your name?");
          setState(() {
            _askingForName = true;
            _command = '';
          });
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'REGISTER WITH VOICE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
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
                      // Registration icon
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
                                  : (_isRegistering
                                      ? Colors.green.withOpacity(0.2)
                                      : Colors.transparent)),
                          border: Border.all(
                            color: _isRegistering
                                ? Colors.green
                                : (_isSpeaking ? Colors.blue : Colors.amber),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _isRegistering
                                ? Icons.person_add
                                : (_isSpeaking ? Icons.volume_up : Icons.mic),
                            size: 80,
                            color: _isRegistering
                                ? Colors.green
                                : (_isSpeaking ? Colors.blue : Colors.amber),
                          ),
                        ),
                      ),
                      SizedBox(height: 40),

                      // Registration status
                      Text(
                        _getStatusText(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),

                      SizedBox(height: 20),

                      // Registration details
                      Container(
                        padding: EdgeInsets.all(16),
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            if (_userName.isNotEmpty)
                              Row(
                                children: [
                                  Text(
                                    "Name: ",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    _userName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            if (_userName.isEmpty)
                              Text(
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
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom instruction
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    Text(
                      'Say "register" to begin',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText() {
    if (_isRegistering) {
      return "Registering...";
    } else if (_isSpeaking) {
      return "Speaking...";
    } else if (_askingForName) {
      return "What is your name?";
    } else {
      return "Voice Registration";
    }
  }
}
