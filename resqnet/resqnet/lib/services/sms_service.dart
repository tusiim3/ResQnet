import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:permission_handler/permission_handler.dart';
import 'location_service.dart';
import 'nearby_rider_alert_service.dart';

// TOP-LEVEL FUNCTION FOR BACKGROUND HANDLING (MUST BE OUTSIDE CLASS)
@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  await SmsService.handleIncomingSmsExternally(message);
}

class SmsService {
  static final Telephony telephony = Telephony.instance;
  static String? _trustedNumber;
  static String? _currentUserName;
  static String? _currentUserPhone;

  // Initialize with user data (UNCHANGED)
  static void initUserData(String name, String phone) {
    _currentUserName = name;
    _currentUserPhone = phone;
  }

  // Send user contact info to hardware (UNCHANGED)
  static Future<bool> sendContactToHardware(String hardwareNumber) async {
    if (_currentUserName == null || _currentUserPhone == null) {
      throw 'User data not initialized';
    }

    try {
      await telephony.sendSms(
        to: hardwareNumber,
        message: '$_currentUserName - $_currentUserPhone',
      );
      return true;
    } catch (e) {
      throw 'Failed to send SMS to hardware: $e';
    }
  }

  // Get trusted hardware number (UNCHANGED)
  static String? get hardwareContact => _trustedNumber;

  // Load trusted number from Firestore (UNCHANGED)
  static Future<void> loadTrustedNumberForUser(String uid) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        _trustedNumber = userDoc.get('hardwareContact')?.toString();
        print("✅ User-specific trusted number loaded: $_trustedNumber");
      } else {
        print("⚠️ User document not found for UID: $uid");
      }
    } catch (e) {
      print('❌ Error loading trusted number for user $uid: $e');
    }
  }

  // Send an SMS (ADDED PERMISSION CHECK)
  static Future<bool> sendSms(String number, String message) async {
    try {
      if (!await _checkSmsPermissions()) {
        throw 'SMS permissions denied';
      }
      await telephony.sendSms(to: number, message: message);
      print("✅ SMS sent to $number");
      return true;
    } catch (e) {
      print('❌ Failed to send SMS: $e');
      return false;
    }
  }

  // Initialize SMS listener (UPDATED WITH PERMISSION CHECK)
  static Future<void> initSmsListener() async {
    if (!await _checkSmsPermissions()) {
      throw 'SMS permissions denied';
    }
    
    telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
    print("📡 SMS listener initialized");
  }

  // NEW: Check and request SMS permissions
  static Future<bool> _checkSmsPermissions() async {
    final status = await Permission.sms.status;
    if (status.isGranted) return true;
    
    final result = await Permission.sms.request();
    if (result.isGranted) return true;
    
    if (result.isPermanentlyDenied) {
      await openAppSettings();
    }
    return false;
  }

  // Exposed method to handle incoming SMS from background handler (UNCHANGED)
  static Future<void> handleIncomingSmsExternally(SmsMessage message) async {
    await _handleIncomingSms(message);
  }

  // Handle incoming messages (UNCHANGED)
  static Future<void> _handleIncomingSms(SmsMessage message) async {
    print("📩 Incoming SMS from ${message.address}: ${message.body}");

    if (_trustedNumber == null) {
      final prefs = await SharedPreferences.getInstance();
      _trustedNumber = prefs.getString('last_hardware_contact');
    }

    if (_trustedNumber == null) {
      print("⚠️ No trusted number available to check against.");
      return;
    }

    if (message.address == _trustedNumber &&
        message.body?.toLowerCase().contains('user needs help') == true) {
      print("🚨 Emergency SMS detected!");
      await _handleEmergencyRequest(message.address!);
    }
  }

  // Get current device location (UNCHANGED)
  static Future<Position> _getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Emergency request handler (UNCHANGED)
  static Future<void> _handleEmergencyRequest(String sender) async {
    try {
      final position = await _getCurrentPosition();
      print("📍 Current position: ${position.latitude}, ${position.longitude}");

      final hospitals = await LocationService.findNearestHospitals(
        position.latitude, 
        position.longitude,
        limit: 3
      );

      String emergencyMessage = '$_currentUserName - ${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}:\n';
      
      if (hospitals.isNotEmpty) {
        for (var hospital in hospitals) {
          emergencyMessage += '${hospital['name']} - ${hospital['emergency']}\n';
        }
      } else {
        emergencyMessage += 'No nearby hospitals found - call 911';
      }

      await sendSms(sender, emergencyMessage);
      print('✅ Emergency SMS sent successfully');

      final locationService = LocationService();
      await locationService.saveEmergencyLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        additionalInfo: 'Emergency detected via SMS from hardware',
      );
      print('✅ Emergency saved to Firebase');

      final nearbyAlertService = NearbyRiderAlertService();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final notifiedRiders = await nearbyAlertService.alertNearbyRiders(
          emergencyAlertId: user.uid,
          latitude: position.latitude,
          longitude: position.longitude,
          emergencyDescription: 'Crash detected by smart helmet hardware',
        );
        print('✅ Notified ${notifiedRiders.length} nearby riders');
      }
      
    } catch (e, stackTrace) {
      print('❌ Emergency handling failed: $e');
      print(stackTrace);
      await sendSms(sender, 'Emergency detected - Unable to get location details');
    }
  }
}