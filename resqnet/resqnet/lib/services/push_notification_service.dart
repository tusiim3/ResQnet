import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'navigation_service.dart';

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  
  // Initialize Firebase if needed
  // await Firebase.initializeApp();
  
  // Show local notification when app is completely closed
  // The navigation will be handled when user taps the notification
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  
  static bool _isInitialized = false;

  // Initialize the notification service
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Request notification permission
    await Permission.notification.request();

    // Request Firebase Messaging permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else {
      print('User declined or has not accepted notification permission');
    }

    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // Combined initialization settings
    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // Initialize the plugin
    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification opened from background/terminated state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpened);

    // Get and save FCM token
    await _saveDeviceToken();

    _isInitialized = true;
  }

  // Save FCM token to Firestore for the current user
  static Future<void> _saveDeviceToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        // Use SharedPreferences to get the original user ID
        final prefs = await SharedPreferences.getInstance();
        final originalUserId = prefs.getString('original_user_id');
        
        if (originalUserId != null) {
          await _db.collection('users').doc(originalUserId).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('FCM Token saved for user $originalUserId: $token');
        } else {
          // Store token temporarily until user logs in
          await prefs.setString('pending_fcm_token', token);
          print('FCM Token stored temporarily until user logs in: $token');
        }
      }
    } catch (e) {
      print('Error saving FCM token: $e');
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      final prefs = await SharedPreferences.getInstance();
      final originalUserId = prefs.getString('original_user_id');
      
      if (originalUserId != null) {
        await _db.collection('users').doc(originalUserId).update({
          'fcmToken': newToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        print('FCM Token refreshed for user $originalUserId: $newToken');
      } else {
        // Store refreshed token temporarily until user logs in
        await prefs.setString('pending_fcm_token', newToken);
        print('FCM Token refreshed and stored temporarily: $newToken');
      }
    });
  }

  // Call this method after user login to save any pending FCM token
  static Future<void> saveTokenForLoggedInUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendingToken = prefs.getString('pending_fcm_token');
      
      if (pendingToken != null) {
        await _db.collection('users').doc(userId).update({
          'fcmToken': pendingToken,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        
        // Remove the pending token
        await prefs.remove('pending_fcm_token');
        print('Pending FCM Token saved for logged in user $userId: $pendingToken');
      } else {
        // Get current token if no pending token
        final token = await _firebaseMessaging.getToken();
        if (token != null) {
          await _db.collection('users').doc(userId).update({
            'fcmToken': token,
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          });
          print('Current FCM Token saved for logged in user $userId: $token');
        }
      }
    } catch (e) {
      print('Error saving FCM token for logged in user: $e');
    }
  }

  // Handle foreground messages
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    // Show local notification when app is in foreground
    await _showLocalNotification(message);
  }

  // Handle notification opened from background
  static Future<void> _handleNotificationOpened(RemoteMessage message) async {
    print('Notification opened from background: ${message.messageId}');
    
    // Navigate to alert feed screen when notification is opened from background
    try {
      NavigationService.navigateToAlertFeed();
      print('Navigating to alert feed screen from background');
    } catch (e) {
      print('Error navigating to alert feed from background: $e');
    }
  }

  // Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('Notification tapped: ${response.payload}');
    
    // Navigate to alert feed screen when emergency notification is tapped
    try {
      NavigationService.navigateToAlertFeed();
      print('Navigating to alert feed screen');
    } catch (e) {
      print('Error navigating to alert feed: $e');
    }
  }

  // Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'emergency_channel',
      'Emergency Alerts',
      channelDescription: 'Emergency alerts for nearby riders',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFFE74C3C),
      enableVibration: true,
      playSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      message.hashCode,
      message.notification?.title ?? 'Emergency Alert',
      message.notification?.body ?? 'A nearby rider needs help!',
      platformChannelSpecifics,
      payload: message.data.toString(),
    );
  }

  // Show emergency alert notification
  static Future<void> showEmergencyAlert({
    required String title,
    required String body,
    required String location,
    required String distance,
    String? alertId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'emergency_alerts',
      'Emergency Alerts',
      channelDescription: 'Notifications for nearby emergency alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      // Custom sound can be added here
      color: const Color(0xFFE74C3C), // Red color for emergency
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Emergency Alert',
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Generate unique ID for the notification
    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: alertId, // Pass alert ID as payload
    );

    print('Emergency notification sent: $title');
  }

  // Show a simple notification
  static Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'general_notifications',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _notificationsPlugin.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  // Cancel specific notification
  static Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  // Check if notifications are enabled
  static Future<bool> areNotificationsEnabled() async {
    final status = await Permission.notification.status;
    return status == PermissionStatus.granted;
  }

  // Request notification permission
  static Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status == PermissionStatus.granted;
  }
}
