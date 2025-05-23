import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  SocketService._internal();

  // Socket.io server URL (adjust to match your dashboard server)
  static const String _serverUrl =
      'http://10.0.2.2:5000'; // Use this for Android emulator
  // Use 'http://localhost:5000' for iOS simulator or web
  // Use your actual IP address for physical devices

  IO.Socket? _socket;
  final ValueNotifier<List<Map<String, dynamic>>> rideRequests =
      ValueNotifier<List<Map<String, dynamic>>>([]);
  final ValueNotifier<String> driverStatus = ValueNotifier<String>('offline');
  final SupabaseService _supabaseService = SupabaseService();

  Timer? _reconnectTimer;
  bool _manuallyDisconnected = false;

  // Get socket instance (for direct event listening)
  IO.Socket? get socket => _socket;

  // Initialize socket connection with retry mechanism
  void initializeSocket(String clientId) {
    try {
      _manuallyDisconnected = false;

      // Clean up any existing socket
      if (_socket != null) {
        _socket?.disconnect();
        _socket?.dispose();
        _socket = null;
      }

      final isDriver = clientId.contains('driver');

      print(
          'Initializing socket as: ${isDriver ? 'DRIVER' : 'CLIENT'} with ID: $clientId');

      _socket = IO.io(
          _serverUrl,
          IO.OptionBuilder()
              .setTransports(['websocket'])
              .disableAutoConnect()
              .setQuery({
                'clientId': clientId,
                'type': isDriver ? 'driver' : 'client'
              })
              .setReconnectionAttempts(5)
              .setReconnectionDelay(5000) // 5 seconds
              .build());

      _socket?.connect();

      _socket?.onConnect((_) {
        print('Socket connected successfully with ID: ${_socket?.id}');
        driverStatus.value = 'online';

        // Emit client connected event
        if (isDriver) {
          _socket?.emit('driverConnected', {'driverId': clientId});
        } else {
          _socket?.emit('clientConnected', {'clientId': clientId});
        }

        // Cancel any reconnection timer
        _reconnectTimer?.cancel();
      });

      _socket?.onConnectError((data) {
        print('Socket connection error: $data');
        _startReconnectTimer(clientId);
      });

      _socket?.onError((data) {
        print('Socket error: $data');
      });

      _socket?.onDisconnect((_) {
        print('Socket disconnected');
        driverStatus.value = 'offline';

        if (!_manuallyDisconnected) {
          _startReconnectTimer(clientId);
        }
      });

      _socket?.onReconnect((_) {
        print('Socket reconnected');
        driverStatus.value = 'online';
      });

      // Listen for ride requests (driver only)
      if (isDriver) {
        _socket?.on('rideRequest', (data) {
          print('Ride request received: $data');
          if (data != null) {
            final List<Map<String, dynamic>> currentRequests =
                List.from(rideRequests.value);

            // Convert to Map if it's not already
            Map<String, dynamic> rideMap;
            if (data is Map) {
              rideMap = Map<String, dynamic>.from(data);
            } else if (data is String) {
              rideMap = jsonDecode(data);
            } else {
              print(
                  'Unknown data format for ride request: ${data.runtimeType}');
              return;
            }

            // Check if this ride already exists in the list
            final existingIndex = currentRequests.indexWhere((r) =>
                (r['id'] == rideMap['id']) ||
                (r['_id'] != null && r['_id'] == rideMap['id']));

            if (existingIndex >= 0) {
              // Update existing ride
              currentRequests[existingIndex] = rideMap;
            } else {
              // Add new ride
              currentRequests.add(rideMap);
            }

            rideRequests.value = currentRequests;
          }
        });
      }

      // Listen for ride acceptance updates (for both drivers and clients)
      _socket?.on('rideAccepted', (data) {
        print('Ride accepted event received: $data');
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
        final String driverId = acceptData['driverId'] ?? '';

        if (isDriver && driverId != clientId) {
          // If this is a driver but not the accepting driver, remove the ride
          _removeRideRequest(rideId);
        }
      });
    } catch (e) {
      print('Socket initialization error: $e');
      _startReconnectTimer(clientId);
    }
  }

  // Start reconnection timer
  void _startReconnectTimer(String clientId) {
    if (_reconnectTimer != null) {
      _reconnectTimer?.cancel();
    }

    if (!_manuallyDisconnected) {
      _reconnectTimer = Timer(Duration(seconds: 10), () {
        print('Attempting to reconnect socket...');
        initializeSocket(clientId);
      });
    }
  }

  // Remove a ride request from the list
  void _removeRideRequest(String rideId) {
    final List<Map<String, dynamic>> currentRequests =
        List.from(rideRequests.value);
    currentRequests.removeWhere((ride) =>
        ride['id'] == rideId || (ride['_id'] != null && ride['_id'] == rideId));
    rideRequests.value = currentRequests;
  }

  // Accept a ride
  void acceptRide(Map<String, dynamic> rideData, String driverId) {
    final String rideId = rideData['id'] ?? '';
    if (rideId.isEmpty) {
      print('Cannot accept ride: missing ride ID');
      return;
    }

    if (_socket != null && _socket!.connected) {
      print('Accepting ride via Socket.io: $rideId by driver: $driverId');
      _socket!.emit('acceptRide', {
        'rideId': rideId,
        'driverId': driverId,
        'driverName': rideData['driverName'] ?? 'Driver',
        'vehicleDetails': rideData['vehicleDetails'] ?? {}
      });

      // Update local state
      _removeRideRequest(rideId);
    } else {
      print(
          'Socket not connected - using Supabase directly for ride acceptance');
      // The driver_service will handle the Supabase update
    }
  }

  // Decline a ride
  void declineRide(String rideId, String driverId) {
    if (rideId.isEmpty) {
      print('Cannot decline ride: missing ride ID');
      return;
    }

    if (_socket != null && _socket!.connected) {
      print('Declining ride via Socket.io: $rideId by driver: $driverId');
      _socket!.emit('declineRide', {'rideId': rideId, 'driverId': driverId});

      // Update local state
      _removeRideRequest(rideId);
    } else {
      print('Socket not connected - cannot decline ride');
    }
  }

  // Update driver availability status
  void updateDriverStatus(String driverId, bool isAvailable) {
    if (_socket != null && _socket!.connected) {
      print(
          'Updating driver status via Socket.io: $driverId to: ${isAvailable ? 'available' : 'unavailable'}');
      _socket!.emit('updateDriverStatus',
          {'driverId': driverId, 'isAvailable': isAvailable});
    }

    driverStatus.value = isAvailable ? 'available' : 'busy';

    // Always update in Supabase even if socket fails
    _updateDriverStatusInDatabase(driverId, isAvailable);
  }

  // Update driver status in database as backup
  Future<void> _updateDriverStatusInDatabase(
      String driverId, bool isAvailable) async {
    try {
      await _supabaseService.client
          .from('drivers')
          .update({'is_available': isAvailable}).eq('id', driverId);

      print('Driver status updated in database: $isAvailable');
    } catch (e) {
      print('Error updating driver status in database: $e');
    }
  }

  // Send a ride request (for client)
  void sendRideRequest(Map<String, dynamic> rideData) {
    if (_socket != null && _socket!.connected) {
      print('Emitting ride request via Socket.io: ${rideData['id']}');
      _socket!.emit('newRideRequest', rideData);
    } else {
      print('Socket not connected - cannot send ride request via Socket.io');
      print('Ride already created in Supabase with ID: ${rideData['id']}');
      // The ride is already created in Supabase from the booking_screen,
      // so the drivers can still find it through the database
    }
  }

  // Check if a ride is accepted directly from Supabase (fallback when socket fails)
  Future<Map<String, dynamic>?> checkRideStatus(String rideId) async {
    try {
      print('Checking ride status in Supabase for ride: $rideId');
      final response = await _supabaseService.client
          .from('rides')
          .select('*, drivers(*)')
          .eq('id', rideId)
          .single();

      print('Ride status check result: ${response?['status']}');
      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error checking ride status: $e');
      return null;
    }
  }

  // Poll for ride status changes (useful when socket connection fails)
  Future<void> startRideStatusPolling(
      String rideId, Function(Map<String, dynamic>) onStatusChanged) async {
    print('Starting ride status polling for ride: $rideId');

    Timer.periodic(Duration(seconds: 5), (timer) async {
      final rideData = await checkRideStatus(rideId);

      if (rideData != null) {
        print('Polled ride status: ${rideData['status']}');
        onStatusChanged(rideData);

        // If the ride is no longer in 'requested' status, stop polling
        if (rideData['status'] != 'requested') {
          print('Ride no longer in requested status, stopping polling');
          timer.cancel();
        }
      }
    });
  }

  // Disconnect socket
  void disconnect() {
    _manuallyDisconnected = true;
    _reconnectTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    driverStatus.value = 'offline';
    print('Socket manually disconnected');
  }

  // Check if socket is connected
  bool get isConnected => _socket?.connected ?? false;
}
