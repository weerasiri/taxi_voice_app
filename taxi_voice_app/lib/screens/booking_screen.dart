import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class BookingScreen extends StatefulWidget {
  final String userName;
  final String phoneNumber;

  const BookingScreen({
    Key? key,
    this.userName = '',
    this.phoneNumber = '',
  }) : super(key: key);

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

    String message = "Your location is set.";
    if (widget.userName.isNotEmpty) {
      message += " Hello ${widget.userName}.";
    }
    message += " Ride booked. Driver will be assigned shortly.";

    await _speak(message);

    Future.delayed(Duration(seconds: 2), () {
      Navigator.pushNamed(
        context,
        '/driver',
        arguments: {
          'userName': widget.userName,
          'latitude': _currentPosition?.latitude,
          'longitude': _currentPosition?.longitude,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Confirm Pickup")),
      body: Center(
        child: _currentPosition == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.amber),
                  SizedBox(height: 20),
                  Text(
                    "Getting your location...",
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.userName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Text(
                        "Rider: ${widget.userName}",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Icon(Icons.location_on, size: 60, color: Colors.amber),
                  SizedBox(height: 20),
                  Text(
                    "Location:",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(4)}",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
      ),
    );
  }
}
