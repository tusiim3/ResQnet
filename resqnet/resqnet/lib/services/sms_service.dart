import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_service.dart';


class SmsService {
  static final Telephony telephony = Telephony.instance;
  static String? _trustedNumber;
  static String? _currentUserName;
  static String? _currentUserPhone;

  // Initialize with user data
  static void initUserData(String name, String phone) {
    _currentUserName = name;
    _currentUserPhone = phone;
  }

  // Send user contact info to hardware
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

  // Get trusted hardware number
  static String? get hardwareContact => _trustedNumber;

  // Load trusted number from Firestore
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

  // Send an SMS
  static Future<bool> sendSms(String number, String message) async {
    try {
      await telephony.sendSms(to: number, message: message);
      print("✅ SMS sent to $number");
      return true;
    } catch (e) {
      print('❌ Failed to send SMS: $e');
      return false;
    }
  }

  // Initialize SMS listener (foreground + background)
  static void initSmsListener() {
    telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: backgroundMessageHandler,
      listenInBackground: true,
    );
    print("📡 SMS listener initialized");
  }

  // Handle background message
  static Future<void> backgroundMessageHandler(SmsMessage message) async {
    await handleIncomingSmsExternally(message);
  }

  // Exposed method to handle incoming SMS from background handler
  static Future<void> handleIncomingSmsExternally(SmsMessage message) async {
    await _handleIncomingSms(message);
  }

  // Handle incoming messages
  static Future<void> _handleIncomingSms(SmsMessage message) async {
    print("📩 Incoming SMS from ${message.address}: ${message.body}");

    // for background handling
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

  // Get current device location
  static Future<Position> _getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Updated emergency request handler with coordinates
  static Future<void> _handleEmergencyRequest(String sender) async {
    try {
      // Get current position
      final position = await _getCurrentPosition();
      print("📍 Current position: ${position.latitude}, ${position.longitude}");

      // Save emergency to Firebase
      final locationService = LocationService();
      await locationService.saveEmergencyLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        additionalInfo: 'Emergency detected via SMS from hardware',
      );
      print('✅ Emergency saved to Firebase');

      // Find nearest hospitals (now getting 3)
      final hospitals = await LocationService.findNearestHospitals(
        position.latitude, 
        position.longitude,
        limit: 3
      );

      // Format the emergency message with coordinates
      String emergencyMessage = '$_currentUserName - ${position.latitude.toStringAsFixed(6)},${position.longitude.toStringAsFixed(6)}:\n';
      
      if (hospitals.isNotEmpty) {
        for (var hospital in hospitals) {
          emergencyMessage += '${hospital['name']} - ${hospital['emergency']}\n';
        }
      } else {
        emergencyMessage += 'No nearby hospitals found - call 911';
      }

      // Send formatted emergency SMS
      await sendSms(sender, emergencyMessage);
      print('✅ Emergency SMS sent successfully');
      
    } catch (e, stackTrace) {
      print('❌ Emergency handling failed: $e');
      print(stackTrace);
      await sendSms(sender, 'Emergency detected - Unable to get location details');
    }
  }
}