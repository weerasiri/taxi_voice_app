import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverService {
  static final DriverService _instance = DriverService._internal();

  factory DriverService() {
    return _instance;
  }

  DriverService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Check if the user is registered as a driver
  Future<Map<String, dynamic>> checkDriverStatus(String userId) async {
    try {
      final data = await _supabaseService.client
          .from('drivers')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        await _saveDriverLocally(data);
        return {
          'isDriver': true,
          'driver': data,
        };
      } else {
        return {
          'isDriver': false,
          'driver': null,
        };
      }
    } catch (e) {
      print('Error checking driver status: $e');
      return {
        'isDriver': false,
        'error': e.toString(),
      };
    }
  }

  // Register as a driver
  Future<Map<String, dynamic>> registerAsDriver({
    required String userId,
    required String name,
    required String phone,
    required String vehicleInfo,
    required String licenseNumber,
    required String email,
  }) async {
    try {
      // Check if already registered
      final checkResult = await checkDriverStatus(userId);
      if (checkResult['isDriver'] == true) {
        return {
          'success': true,
          'message': 'Already registered as a driver',
          'driver': checkResult['driver'],
        };
      }

      // Register new driver
      final newDriver = await _supabaseService.client
          .from('drivers')
          .insert({
            'user_id': userId,
            'name': name,
            'phone': phone,
            'license_number': licenseNumber,
            'vehicle_details': {
              'model': vehicleInfo,
              'type': 'Car',
              'year': '2023'
            },
            'is_available': true,
            'current_location': null,
            'rating': 5.0,
            'total_rides': 0,
            'email': email,
            'password':
                'password123', // Placeholder password - would use proper auth in real app
          })
          .select()
          .single();

      await _saveDriverLocally(newDriver);

      return {
        'success': true,
        'message': 'Driver registration successful',
        'driver': newDriver,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Driver registration failed: ${e.toString()}',
      };
    }
  }

  // Update driver's availability
  Future<Map<String, dynamic>> updateAvailability(
      String driverId, bool isAvailable) async {
    try {
      await _supabaseService.client.from('drivers').update({
        'is_available': isAvailable,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', driverId);

      // Also update locally
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool('driver_is_available', isAvailable);

      return {
        'success': true,
        'message': 'Availability updated',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to update availability: ${e.toString()}',
      };
    }
  }

  // Accept a ride request
  Future<Map<String, dynamic>> acceptRide(
      String rideId, String driverId) async {
    try {
      await _supabaseService.client.from('rides').update({
        'driver_id': driverId,
        'status': 'accepted',
        'pickup_time': DateTime.now().toIso8601String(),
      }).eq('id', rideId);

      // Also update driver availability
      await updateAvailability(driverId, false);

      return {
        'success': true,
        'message': 'Ride accepted',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to accept ride: ${e.toString()}',
      };
    }
  }

  // Complete a ride
  Future<Map<String, dynamic>> completeRide(
      String rideId, String driverId) async {
    try {
      await _supabaseService.client.from('rides').update({
        'status': 'completed',
        'completion_time': DateTime.now().toIso8601String(),
      }).eq('id', rideId);

      // Update driver availability
      await updateAvailability(driverId, true);

      return {
        'success': true,
        'message': 'Ride completed',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to complete ride: ${e.toString()}',
      };
    }
  }

  // Get current driver info
  Future<Map<String, dynamic>?> getCurrentDriver() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString('driver_id');

    if (driverId == null) return null;

    return {
      'id': driverId,
      'name': prefs.getString('driver_name') ?? '',
      'phone': prefs.getString('driver_phone') ?? '',
      'vehicle_details': {
        'model': prefs.getString('driver_vehicle_model') ?? '',
        'type': 'Car',
        'year': '2023'
      },
      'license_number': prefs.getString('driver_license_number') ?? '',
      'is_available': prefs.getBool('driver_is_available') ?? false,
      'email': prefs.getString('driver_email') ?? '',
    };
  }

  // Save driver info locally
  Future<void> _saveDriverLocally(Map<String, dynamic> driver) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('driver_id', driver['id'].toString());
    prefs.setString('driver_name', driver['name'] ?? '');
    prefs.setString('driver_phone', driver['phone'] ?? '');
    prefs.setString('driver_email', driver['email'] ?? '');

    // Handle vehicle details which is now a JSON object
    if (driver['vehicle_details'] != null) {
      final vehicleDetails = driver['vehicle_details'];
      prefs.setString('driver_vehicle_model', vehicleDetails['model'] ?? '');
    }

    prefs.setString('driver_license_number', driver['license_number'] ?? '');
    prefs.setBool('driver_is_available', driver['is_available'] ?? false);
  }
}
