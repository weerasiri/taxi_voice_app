import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/driver_service.dart';
import '../services/socket_service.dart';
import '../services/supabase_service.dart';
import 'dart:async';

class DriverDashboard extends StatefulWidget {
  @override
  _DriverDashboardState createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final DriverService _driverService = DriverService();
  final SocketService _socketService = SocketService();
  final SupabaseService _supabaseService = SupabaseService();
  final FlutterTts _tts = FlutterTts();

  Map<String, dynamic>? _driverData;
  bool _isLoading = true;
  String _driverId = '';
  String _userId = '';
  bool _isDriverAvailable = false;

  @override
  void initState() {
    super.initState();
    _initializeDriverDashboard();

    // Set up a timer to periodically fetch ride requests from Supabase
    Timer.periodic(Duration(seconds: 15), (timer) {
      if (mounted) {
        _fetchPendingRideRequests();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  Future<void> _initializeDriverDashboard() async {
    try {
      // Get current user
      final userData = await _supabaseService.getCurrentUser();
      if (userData == null) {
        // Navigate to login if not logged in
        Navigator.pushReplacementNamed(context, '/register');
        return;
      }

      _userId = userData['id'];

      // Check if user is a driver
      final driverStatus = await _driverService.checkDriverStatus(_userId);

      if (driverStatus['isDriver'] == true) {
        // User is a driver
        setState(() {
          _driverData = driverStatus['driver'];
          _driverId = _driverData!['id'].toString();
          _isDriverAvailable = _driverData!['is_available'] ?? false;
          _isLoading = false;
        });

        // Initialize socket connection with the driver ID
        _socketService.initializeSocket('driver-${_driverId}');

        // Fetch initial ride requests
        _fetchPendingRideRequests();

        await _speak(
            "Driver dashboard initialized. Your status is ${_isDriverAvailable ? 'available' : 'unavailable'}.");
      } else {
        // User is not a driver, show registration form
        setState(() {
          _isLoading = false;
        });
        _showDriverRegistrationDialog();
      }
    } catch (e) {
      print('Error initializing driver dashboard: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error initializing driver dashboard: $e')),
      );
    }
  }

  // Show dialog to register as a driver
  void _showDriverRegistrationDialog() {
    final _vehicleController = TextEditingController();
    final _licenseController = TextEditingController();
    final _emailController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Driver Registration'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'e.g., driver@example.com',
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _vehicleController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Information',
                  hintText: 'e.g., Toyota Camry, Black, 2020',
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _licenseController,
                decoration: InputDecoration(
                  labelText: 'License Number',
                  hintText: 'e.g., DL123456789',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = _emailController.text.trim();
              final vehicleInfo = _vehicleController.text.trim();
              final licenseNumber = _licenseController.text.trim();

              if (email.isEmpty ||
                  vehicleInfo.isEmpty ||
                  licenseNumber.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill in all fields')),
                );
                return;
              }

              Navigator.pop(context);
              setState(() {
                _isLoading = true;
              });

              try {
                final userData = await _supabaseService.getCurrentUser();
                final result = await _driverService.registerAsDriver(
                  userId: _userId,
                  name: userData!['name'] ?? 'Driver',
                  phone: userData['phone'] ?? '',
                  vehicleInfo: vehicleInfo,
                  licenseNumber: licenseNumber,
                  email: email,
                );

                if (result['success']) {
                  setState(() {
                    _driverData = result['driver'];
                    _driverId = _driverData!['id'].toString();
                    _isDriverAvailable = _driverData!['is_available'] ?? false;
                    _isLoading = false;
                  });

                  // Initialize socket connection
                  _socketService.initializeSocket('driver-${_driverId}');
                  await _speak(
                      "Registration successful. Welcome to the driver dashboard.");
                } else {
                  setState(() {
                    _isLoading = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'])),
                  );
                }
              } catch (e) {
                setState(() {
                  _isLoading = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Registration failed: $e')),
                );
              }
            },
            child: Text('Register'),
          ),
        ],
      ),
    );
  }

  // Toggle driver availability
  void _toggleAvailability() async {
    final bool newAvailability = !_isDriverAvailable;

    setState(() {
      _isDriverAvailable = newAvailability;
    });

    try {
      final result = await _driverService.updateAvailability(
          _driverId, _isDriverAvailable);

      if (result['success']) {
        // Update socket status
        _socketService.updateDriverStatus(_driverId, _isDriverAvailable);

        await _speak(
            "You are now ${_isDriverAvailable ? 'available' : 'unavailable'} for ride requests.");

        // If becoming available, fetch open ride requests
        if (_isDriverAvailable) {
          _fetchPendingRideRequests();
        }
      } else {
        // Revert on failure
        setState(() {
          _isDriverAvailable = !newAvailability;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Failed to update availability: ${result['message']}')),
        );
      }
    } catch (e) {
      print('Error updating availability: $e');
      // Revert on error
      setState(() {
        _isDriverAvailable = !newAvailability;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update availability')),
      );
    }
  }

  // Accept a ride request
  void _acceptRide(Map<String, dynamic> ride) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get driver data to include in the notification
      final driverData = await _driverService.getCurrentDriver();

      if (driverData == null) {
        throw Exception('Driver data not found');
      }

      final String rideId = ride['id'] ?? '';
      if (rideId.isEmpty) {
        throw Exception('Invalid ride ID');
      }

      print('Accepting ride: $rideId');

      // Update on server using the driver service
      final result = await _driverService.acceptRide(rideId, _driverId);

      if (!result['success']) {
        throw Exception(result['message']);
      }

      // Notify through socket if connected
      _socketService.acceptRide({
        'id': rideId,
        'driverName': driverData['name'] ?? 'Driver',
        'vehicleDetails': driverData['vehicle_details'] ?? {}
      }, _driverId);

      // Notify driver
      await _speak("Ride accepted. Navigate to the pickup location.");

      setState(() {
        _isLoading = false;
        _isDriverAvailable = false; // Mark driver as unavailable
      });

      // Navigate to driver screen
      Navigator.pushNamed(
        context,
        '/driver',
        arguments: {
          'rideId': rideId,
          'pickup': ride['pickup_location'] ?? 'Unknown location',
          'destination': ride['destination'] ?? 'Unknown destination',
          'userName': ride['user_name'] ?? 'Passenger',
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error accepting ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to accept ride: $e')),
      );
    }
  }

  // Decline a ride request
  void _declineRide(String rideId) {
    if (rideId.isEmpty) {
      print('Cannot decline ride: Invalid ride ID');
      return;
    }

    print('Declining ride: $rideId');
    _socketService.declineRide(rideId, _driverId);

    // Remove from UI immediately
    final requests =
        List<Map<String, dynamic>>.from(_socketService.rideRequests.value);
    requests.removeWhere(
        (r) => r['id'] == rideId || (r['_id'] != null && r['_id'] == rideId));
    _socketService.rideRequests.value = requests;
  }

  // Add this function after _initializeDriverDashboard to fetch open ride requests directly from Supabase
  Future<void> _fetchPendingRideRequests() async {
    if (_isDriverAvailable && _driverId.isNotEmpty) {
      try {
        print('Fetching pending ride requests from Supabase');

        final response = await _supabaseService.client
            .from('rides')
            .select('*')
            .eq('status', 'requested')
            .order('request_time', ascending: false);

        final rideRequests = response as List<dynamic>;

        if (rideRequests.isNotEmpty) {
          print('Found ${rideRequests.length} pending ride requests');

          // Add to the socket service's ride request list
          final List<Map<String, dynamic>> currentRequests =
              List.from(_socketService.rideRequests.value);

          // Remove duplicates and add new rides
          for (final ride in rideRequests) {
            final Map<String, dynamic> rideMap =
                Map<String, dynamic>.from(ride);
            final existingIndex = currentRequests.indexWhere((r) =>
                r['id'] == rideMap['id'] ||
                (r['_id'] != null && r['_id'] == rideMap['id']));

            if (existingIndex < 0) {
              // Add ride to the list if not already present
              currentRequests.add(rideMap);
            }
          }

          // Update the notifier
          _socketService.rideRequests.value = currentRequests;
        }
      } catch (e) {
        print('Error fetching ride requests: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Driver Dashboard'),
        actions: [
          if (_driverData != null)
            Switch(
              value: _isDriverAvailable,
              onChanged: (_) => _toggleAvailability(),
              activeColor: Colors.amber,
              activeTrackColor: Colors.amberAccent.withOpacity(0.5),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.amber))
          : _driverData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('You are not registered as a driver'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _showDriverRegistrationDialog,
                        child: Text('Register as Driver'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Driver info card
                    Card(
                      margin: EdgeInsets.all(16),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Driver Status',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _isDriverAvailable
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _isDriverAvailable
                                        ? 'Available'
                                        : 'Unavailable',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text('Name: ${_driverData!['name']}'),
                            Text(
                                'Vehicle: ${_driverData!['vehicle_details'] != null ? _driverData!['vehicle_details']['model'] : 'N/A'}'),
                            Text('License: ${_driverData!['license_number']}'),
                          ],
                        ),
                      ),
                    ),

                    // Ride requests
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Ride Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    // Ride requests list
                    Expanded(
                      child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                        valueListenable: _socketService.rideRequests,
                        builder: (context, requests, child) {
                          if (!_isDriverAvailable) {
                            return Center(
                              child: Text(
                                'You are currently unavailable',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }

                          if (requests.isEmpty) {
                            return Center(
                              child: Text(
                                'No ride requests available',
                                style: TextStyle(fontSize: 16),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final ride = requests[index];
                              return Card(
                                margin: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pickup: ${ride['pickup_location']}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                          'Destination: ${ride['destination']}'),
                                      Text('Passenger: ${ride['user_name']}'),
                                      SizedBox(height: 16),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _declineRide(ride['id']),
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor: Colors.red,
                                              ),
                                              child: Text('Decline'),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _acceptRide(ride),
                                              child: Text('Accept'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }
}
