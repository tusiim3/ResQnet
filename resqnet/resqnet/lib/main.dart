import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Fixed import line
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/Login_Screen.dart'; // Ensure this import path is correct
import 'screens/home_screen.dart';
import 'services/sms_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  SmsService.initSmsListener();

  // Initialize SMS services
  bool smsPermissionCurrentlyGranted = false; // Default or check here if needed

  // Check for existing user session
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;

  // Check if user should be auto-logged in
  final userService = UserService();
  final isValidSession = await userService.isValidSession();

  runApp(MyApp(isDarkTheme: isDark, smsPermissionGranted: smsPermissionCurrentlyGranted, shouldAutoLogin : isValidSession));
}

class MyApp extends StatelessWidget {
  final bool isDarkTheme;
  final bool smsPermissionGranted; // Added this parameter
  final bool shouldAutoLogin;

  const MyApp({super.key, required this.isDarkTheme, required this.smsPermissionGranted, required this.shouldAutoLogin});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ResQnet',
      // Consider setting themeMode based on isDarkTheme here
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: shouldAutoLogin 
        ? HomeScreen(
            toggleTheme: (bool isDark) {
              // Handle theme toggle 
            },
            isDarkTheme: isDarkTheme,
          )
        : LoginScreen(
            toggleTheme: (bool isDark) {
              // Handle theme toggle 
            },
            isDarkTheme: isDarkTheme,
            smsPermissionGranted: smsPermissionGranted,
          ),
    );
  }
}