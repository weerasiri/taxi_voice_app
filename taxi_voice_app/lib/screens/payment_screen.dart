import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/supabase_service.dart';

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final FlutterTts _tts = FlutterTts();
  final SupabaseService _supabaseService = SupabaseService();

  double _fare = 0.0;
  String _rideId = '';
  String _startTime = '';
  String _endTime = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initTts();

    // Slight delay to allow the arguments to be processed
    Future.delayed(Duration.zero, () {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _rideId = args['rideId'] ?? '';
        _fetchRideDetails();
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5); // Slower speech rate for better clarity
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _fetchRideDetails() async {
    if (_rideId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final rideData = await _supabaseService.client
          .from('rides')
          .select('*')
          .eq('id', _rideId)
          .single();

      if (rideData != null) {
        _startTime = rideData['pickup_time'] ?? '';
        _endTime = rideData['completion_time'] ?? '';

        // Calculate fare based on ride duration
        _calculateFare(_startTime, _endTime);
      }
    } catch (e) {
      print('Error fetching ride details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateFare(String startTimeStr, String endTimeStr) {
    try {
      if (startTimeStr.isEmpty || endTimeStr.isEmpty) {
        setState(() => _fare = 150.0); // Default fare if times are missing
        return;
      }

      final startTime = DateTime.parse(startTimeStr);
      final endTime = DateTime.parse(endTimeStr);

      // Calculate duration in minutes
      final durationMinutes = endTime.difference(startTime).inMinutes;

      // Base fare + per minute rate
      final baseFare = 100.0;
      final perMinuteRate = 5.0;

      double calculatedFare = baseFare + (durationMinutes * perMinuteRate);

      // Ensure minimum fare
      calculatedFare = calculatedFare < 150.0 ? 150.0 : calculatedFare;

      setState(() => _fare = calculatedFare);
    } catch (e) {
      print('Error calculating fare: $e');
      setState(() => _fare = 150.0); // Default fare on error
    }
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
    await _tts.awaitSpeakCompletion(true); // Wait until TTS finishes speaking
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payment")),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.payment,
                    size: 80,
                    color: Colors.amber,
                  ),
                  SizedBox(height: 20),
                  Text("Trip Payment",
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  SizedBox(height: 30),
                  Text("Total Fare", style: TextStyle(fontSize: 20)),
                  SizedBox(height: 10),
                  Text("Rs. ${_fare.toStringAsFixed(2)}",
                      style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800)),
                  SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: () async {
                      await _speak(
                        "The payment of ${_fare.toStringAsFixed(0)} rupees has been processed. Thank you for your ride.",
                      );
                      // Handle payment processing logic here
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Text('Pay Now', style: TextStyle(fontSize: 18)),
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
    _tts.stop();
    super.dispose();
  }
}
