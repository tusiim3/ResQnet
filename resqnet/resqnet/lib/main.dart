import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';  // Fixed import line
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/Login_Screen.dart'; // Ensure this import path is correct
import 'screens/home_screen.dart';
import 'services/sms_service.dart';
import 'services/push_notification_service.dart';
import 'services/navigation_service.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize push notifications
  await PushNotificationService.initialize();

  SmsService.initSmsListener();

  // Initialize SMS services
  bool smsPermissionCurrentlyGranted = false; // Default or check here if needed
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('isDarkTheme') ?? false;

  runApp(MyApp(isDarkTheme: isDark, smsPermissionGranted: smsPermissionCurrentlyGranted));
}

class MyApp extends StatelessWidget {
  final bool isDarkTheme;
  final bool smsPermissionGranted; // Added this parameter

  const MyApp({super.key, required this.isDarkTheme, required this.smsPermissionGranted});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NavigationService.navigatorKey,
      // Consider setting themeMode based on isDarkTheme here
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      initialRoute: '/login',
      routes: {
        '/login': (context) => LoginScreen(
          toggleTheme: (bool isDark) {
            // This toggleTheme function currently does nothing in MyApp.
            // You might want to pass it down to LoginScreen to actually change the theme.
            // For now, it's a placeholder.
          },
          isDarkTheme: isDarkTheme,
          smsPermissionGranted: smsPermissionGranted,
        ),
        '/home': (context) {
          final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
          final tabIndex = args?['tabIndex'] as int?;
          return HomeScreen(
            toggleTheme: (bool isDark) {
              // Handle theme toggle
            },
            isDarkTheme: isDarkTheme,
            initialTabIndex: tabIndex ?? 0,
          );
        },
      },
    );
  }
}
