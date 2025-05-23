import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/voice_message_screen.dart';
import 'screens/cancel_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/registration_screen.dart';
import 'services/supabase_service.dart';
import 'driver/driver_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService().initialize();
    print('Supabase initialized successfully');
  } catch (e) {
    print('Error initializing Supabase: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Taxi for Visually Impaired',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.amber,
        textTheme: TextTheme(bodyLarge: TextStyle(fontSize: 20)),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: TextStyle(fontSize: 18),
          ),
        ),
      ),
      home: FutureBuilder<bool>(
        future: SupabaseService().isUserLoggedIn(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          final isLoggedIn = snapshot.data ?? false;
          return isLoggedIn ? HomeScreen() : RegistrationScreen();
        },
      ),
      routes: {
        '/home': (context) => HomeScreen(),
        '/register': (context) => RegistrationScreen(),
        '/booking': (context) => BookingScreen(),
        '/driver': (context) => DriverScreen(),
        '/message': (context) => VoiceMessageScreen(),
        '/cancel': (context) => CancelScreen(),
        '/sos': (context) => SosScreen(),
        '/payment': (context) => PaymentScreen(),
        '/driver_dashboard': (context) => DriverDashboard(),
      },
    );
  }
}
