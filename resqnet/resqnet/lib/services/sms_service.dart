import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'location_service.dart';
import '../config/api_config.dart';

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
      // Fetch the document directly using the UID
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        // Get the hardware contact from the user's data
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
      onBackgroundMessage: backgroundMessageHandler, // Now top-level
      listenInBackground: true, // Ensure background listening
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

  // Reverse geocoding to get address from emergency location coordinates
  static Future<String> _getAddressFromCoordinates(double emergencyLat, double emergencyLng) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      final String url = 'https://maps.googleapis.com/maps/api/geocode/json'
          '?latlng=$emergencyLat,$emergencyLng'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        if (results.isNotEmpty) {
          return results[0]['formatted_address'] as String;
        }
      }
    } catch (e) {
      print('Error getting address from emergency location: $e');
    }
    
    // Fallback if reverse geocoding fails
    return 'Unknown emergency location';
  }

  // Handle emergency
  static Future<void> _handleEmergencyRequest(String sender) async {
    try {
      // Get emergency location GPS position
      final position = await _getCurrentPosition();
      
      // Find nearest hospital from emergency location
      final hospital = await LocationService.findNearestHospital(
        position.latitude, 
        position.longitude
      );
      
      // Get readable address from emergency location coordinates
      final address = await _getAddressFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      // Format the emergency message
      String emergencyMessage = 'Emergency at: $address (${position.latitude}, ${position.longitude})';
      
      if (hospital != null) {
        emergencyMessage += ', Contact: ${hospital['name']}, ${hospital['emergency']}';
      } else {
        emergencyMessage += ', Contact: No nearby hospital found, call 911';
      }
      
      // Send formatted emergency SMS
      await sendSms(sender, emergencyMessage);
      
      print('Emergency SMS sent: $emergencyMessage');
      final response = 'Emergency response started. Location: '
          'Lat: ${position.latitude}, Lng: ${position.longitude}';

      await sendSms(sender, response);
    } catch (e) {
      print('Error handling emergency: $e');
      // Send basic response if everything fails
      await sendSms(sender, 'Emergency detected - Unable to get location details');
    }
  }

  // Get current device location
  static Future<Position> _getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}
