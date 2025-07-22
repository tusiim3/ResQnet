import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/sms_service.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Correct way to call static methods
  await SmsService.loadTrustedNumberFromFirestore();
  SmsService.initSmsListener();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;

  runApp(MyApp(isDarkTheme: isDark));
}

class MyApp extends StatelessWidget {
  final bool isDarkTheme;
  
  const MyApp({super.key, required this.isDarkTheme});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: LoginScreen(
        toggleTheme: (bool isDark) {},
        isDarkTheme: isDarkTheme,
      ),
    );
  }
}