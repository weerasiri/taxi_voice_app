import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class PaymentScreen extends StatelessWidget {
  final FlutterTts _tts = FlutterTts();

  Future<void> _speak(String message) async {
    await _tts.speak(message);
    await _tts.awaitSpeakCompletion(true); // Wait until TTS finishes speaking
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payment")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text("Trip Payment", style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text("Total: \Rs.##.##", style: TextStyle(fontSize: 22)),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                await _speak(
                  "The payment of fifteen dollars has been processed. Thank you for your ride.",
                );
                // Handle payment processing logic here
                Navigator.pop(context);
              },
              child: Text('Pay Now'),
            ),
          ],
        ),
      ),
    );
  }
}
