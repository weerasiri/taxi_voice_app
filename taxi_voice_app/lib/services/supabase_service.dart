import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Supabase URL and anon key
  static const String _supabaseUrl = 'https://eailmxnogvmyjchomqzc.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVhaWxteG5vZ3ZteWpjaG9tcXpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc5ODQ5MjIsImV4cCI6MjA2MzU2MDkyMn0.6j5ghtfHmh4MCscYv1Ybdch7fzGbBsTHXBIY81DnTS0';

  late final SupabaseClient _client;

  Future<void> initialize() async {
    await Supabase.initialize(
      url: _supabaseUrl,
      anonKey: _supabaseAnonKey,
    );
    _client = Supabase.instance.client;
  }

  SupabaseClient get client => _client;

  // User registration with just name
  Future<Map<String, dynamic>> registerUser(String name) async {
    try {
      // Check if user already exists by name
      final existingUsers =
          await _client.from('users').select().eq('name', name).limit(1);

      if (existingUsers.isNotEmpty) {
        // User exists, return existing user
        final user = existingUsers[0];
        await _saveUserLocally(user);
        return {
          'success': true,
          'message': 'Welcome back, ${user['name']}',
          'user': user,
        };
      }

      // Create new user
      final newUser = await _client
          .from('users')
          .insert({
            'name': name,
            'phone': '', // Empty phone number
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      await _saveUserLocally(newUser);

      return {
        'success': true,
        'message': 'Registration successful',
        'user': newUser,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Registration failed: ${e.toString()}',
      };
    }
  }

  // Save user to local storage
  Future<void> _saveUserLocally(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('user_id', user['id'].toString());
    prefs.setString('user_name', user['name']);
    prefs.setString('user_phone', user['phone'] ?? '');
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('user_id');
  }

  // Get current user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('user_id');

    if (userId == null) return null;

    return {
      'id': userId,
      'name': prefs.getString('user_name') ?? '',
      'phone': prefs.getString('user_phone') ?? '',
    };
  }

  // Logout user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
  }
}
