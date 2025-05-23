import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BookingScreen extends StatefulWidget {
  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  Position? _currentPosition;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _speak(String msg) async {
    await _tts.speak(msg);
  }

  void _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) {
      await _speak("Location permission denied.");
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() => _currentPosition = position);
    await _speak(
      "Your location is set. Ride booked. Driver will be assigned shortly.",
    );
    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushNamed(
        context,
        '/driver',
      ); // Assuming you have a driver screen
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Confirm Pickup")),
      body: Center(
        child:
            _currentPosition == null
                ? CircularProgressIndicator()
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on, size: 60, color: Colors.amber),
                    Text(
                      "Location:\nLat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ),
      ),
    );
  }
}
