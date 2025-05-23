import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/booking_screen.dart';
import 'screens/driver_screen.dart';
import 'screens/voice_message_screen.dart';
import 'screens/cancel_screen.dart';
import 'screens/sos_screen.dart';
import 'screens/payment_screen.dart';

void main() => runApp(MyApp());

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
      home: HomeScreen(),
      routes: {
        '/booking': (context) => BookingScreen(),
        '/driver': (context) => DriverScreen(),
        '/message': (context) => VoiceMessageScreen(),
        '/cancel': (context) => CancelScreen(),
        '/sos': (context) => SosScreen(),
        '/payment': (context) => PaymentScreen(),
      },
    );
  }
}
