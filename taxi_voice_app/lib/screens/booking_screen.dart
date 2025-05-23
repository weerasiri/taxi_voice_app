import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/supabase_service.dart';
import '../services/socket_service.dart';
import 'dart:convert';

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
  bool _isSearchingForDriver = false;
  bool _driverFound = false;
  final FlutterTts _tts = FlutterTts();
  final SupabaseService _supabaseService = SupabaseService();
  final SocketService _socketService = SocketService();
  String _userId = '';
  String _rideId = '';

  @override
  void initState() {
    super.initState();
    _initBooking();
  }

  Future<void> _initBooking() async {
    // Get current user ID
    final userData = await _supabaseService.getCurrentUser();
    if (userData != null) {
      _userId = userData['id'];
    }

    // Setup socket listeners for ride acceptance
    _setupSocketListeners();

    // Get location
    _getCurrentLocation();
  }

  void _setupSocketListeners() {
    // Initialize socket as a client
    if (_socketService.isConnected) {
      _socketService.disconnect();
    }

    // Use a client identifier
    final clientId = 'client-$_userId-${DateTime.now().millisecondsSinceEpoch}';
    print('Initializing socket as client with ID: $clientId');
    _socketService.initializeSocket(clientId);

    // Listen for ride acceptance
    if (_socketService.socket != null) {
      _socketService.socket!.on('rideAccepted', (data) {
        print('Ride accepted notification received: $data');

        // Convert data to Map if it's a string
        Map<String, dynamic> acceptData;
        if (data is Map) {
          acceptData = Map<String, dynamic>.from(data);
        } else if (data is String) {
          acceptData = jsonDecode(data);
        } else {
          print('Unknown data format for ride acceptance: ${data.runtimeType}');
          return;
        }

        final String rideId = acceptData['rideId'] ?? '';

        if (rideId.isNotEmpty && rideId == _rideId) {
          if (mounted) {
            setState(() {
              _driverFound = true;
              _isSearchingForDriver = false;
            });
          }

          // Get driver info
          final driverName = acceptData['driverName'] ?? 'Your driver';
          _speak(
              "$driverName has accepted your ride request and is on the way.");

          // Navigate to driver screen
          Future.delayed(Duration(seconds: 2), () {
            Navigator.pushReplacementNamed(
              context,
              '/driver',
              arguments: {
                'userName': widget.userName,
                'pickup': 'Your Current Location',
                'destination': 'Your Destination',
                'rideId': _rideId,
              },
            );
          });
        }
      });
    }
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

    if (mounted) {
      setState(() => _currentPosition = position);
    }

    String message = "Your location is set.";
    if (widget.userName.isNotEmpty) {
      message += " Hello ${widget.userName}.";
    }
    message += " Searching for drivers near you.";

    await _speak(message);

    // After getting location, create ride request and send to drivers
    _createRideRequest();
  }

  Future<void> _createRideRequest() async {
    if (_currentPosition == null) return;

    setState(() {
      _isSearchingForDriver = true;
    });

    try {
      // Create a ride in the database
      final rideData = await _supabaseService.client
          .from('rides')
          .insert({
            'user_id': _userId,
            'user_name': widget.userName,
            'user_phone': widget.phoneNumber,
            'pickup_location':
                'Current Location', // Would normally use geocoding here
            'pickup_lat': _currentPosition!.latitude,
            'pickup_lng': _currentPosition!.longitude,
            'destination': 'Destination', // Would normally be user input
            'status': 'requested',
            'pickup': {
              'lat': _currentPosition!.latitude,
              'lng': _currentPosition!.longitude,
              'address': 'Current Location'
            },
            'destination': {
              'lat': 0.0, // Placeholder
              'lng': 0.0, // Placeholder
              'address': 'Destination'
            },
            'request_time': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Save ride ID for reference
      _rideId = rideData['id'];

      print('Created ride with ID: $_rideId');

      // Emit ride request through the socket service
      Map<String, dynamic> rideRequestData = {
        'id': _rideId,
        'user_id': _userId,
        'user_name': widget.userName,
        'pickup_location':
            'Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}, Lng: ${_currentPosition!.longitude.toStringAsFixed(4)}',
        'destination': 'Destination',
        'timestamp': DateTime.now().toIso8601String(),
        'pickup': {
          'lat': _currentPosition!.latitude,
          'lng': _currentPosition!.longitude,
          'address': 'Current Location'
        },
        'destination': {
          'lat': 0.0, // Placeholder
          'lng': 0.0, // Placeholder
          'address': 'Destination'
        },
      };

      // Try to send via socket, but it's okay if it fails since we have the database record
      _socketService.sendRideRequest(rideRequestData);

      // Update UI to show searching for drivers
      if (mounted) {
        setState(() {
          _isSearchingForDriver = true;
        });
      }

      // Start polling for ride status changes in case socket connection fails
      _startRideStatusPolling();

      // After 30 seconds, if no driver found, show timeout message
      Future.delayed(Duration(seconds: 30), () {
        if (mounted && _isSearchingForDriver && !_driverFound) {
          setState(() {
            _isSearchingForDriver = false;
          });
          _speak("No drivers available at the moment. Please try again later.");
          Navigator.pushReplacementNamed(context, '/home');
        }
      });
    } catch (e) {
      print('Error creating ride request: $e');
      if (mounted) {
        setState(() {
          _isSearchingForDriver = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to search for drivers: $e')),
      );
    }
  }

  // Method to poll Supabase for ride status changes
  void _startRideStatusPolling() {
    if (_rideId.isEmpty) return;

    print('Starting ride status polling for ride ID: $_rideId');

    _socketService.startRideStatusPolling(_rideId, (rideData) {
      // Check if the ride status has changed to 'accepted'
      if (rideData['status'] == 'accepted' && mounted && !_driverFound) {
        print('Ride $_rideId accepted via Supabase polling');
        setState(() {
          _driverFound = true;
          _isSearchingForDriver = false;
        });

        // Get driver info from the ride data
        Map<String, dynamic>? driverData = rideData['drivers'];
        String driverName =
            driverData != null ? driverData['name'] : 'Your driver';

        _speak("$driverName has accepted your ride request and is on the way.");

        // Navigate to driver screen
        Future.delayed(Duration(seconds: 2), () {
          Navigator.pushReplacementNamed(
            context,
            '/driver',
            arguments: {
              'userName': widget.userName,
              'pickup': 'Your Current Location',
              'destination': 'Your Destination',
              'rideId': _rideId,
            },
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Searching for Driver")),
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
            : _isSearchingForDriver
                ? Column(
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
                      CircularProgressIndicator(color: Colors.amber),
                      SizedBox(height: 20),
                      Text(
                        "Searching for drivers near you...",
                        style: TextStyle(fontSize: 20),
                      ),
                      SizedBox(height: 20),
                      Text(
                        "Location:",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18),
                      ),
                      SizedBox(height: 10),
                      Text(
                        "Lat: ${_currentPosition!.latitude.toStringAsFixed(4)}\nLng: ${_currentPosition!.longitude.toStringAsFixed(4)}",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
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

  @override
  void dispose() {
    // Don't disconnect the socket as it's needed for the driver response
    super.dispose();
  }
}
