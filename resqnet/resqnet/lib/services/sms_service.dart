import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  // Add this method to your SmsService class
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
  // Getter for hardware contact
  static String? get hardwareContact => _trustedNumber;

  // Load trusted number from Firestore
  static Future<void> loadTrustedNumberFromFirestore() async {
    try {
      DocumentSnapshot configDoc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('app_config')
          .get();

      if (configDoc.exists) {
        _trustedNumber = configDoc.get('trustedPhoneNumber')?.toString();
      }
    } catch (e) {
      print('Error loading trusted number: $e');
    }
  }

  // Send SMS message
  static Future<bool> sendSms(String number, String message) async {
    try {
      await telephony.sendSms(to: number, message: message);
      return true;
    } catch (e) {
      print('Failed to send SMS: $e');
      return false;
    }
  }

  // Initialize SMS listener
  static void initSmsListener() {
    telephony.listenIncomingSms(
      onNewMessage: _handleIncomingSms,
      onBackgroundMessage: _backgroundMessageHandler,
    );
  }

  // Background message handler
  static Future<void> _backgroundMessageHandler(SmsMessage message) async {
    await _handleIncomingSms(message);
  }

  // Handle incoming messages
  static Future<void> _handleIncomingSms(SmsMessage message) async {
    if (_trustedNumber == null) {
      await loadTrustedNumberFromFirestore();
    }

    if (message.address == _trustedNumber && 
        message.body?.toLowerCase().contains('user needs help') == true) {
      await _handleEmergencyRequest(message.address!);
    }
  }

  static Future<void> _handleEmergencyRequest(String sender) async {
    try {
      final position = await _getCurrentPosition();
      // Add your emergency response logic here
      await sendSms(sender, 'Emergency response initiated');
    } catch (e) {
      print('Error handling emergency: $e');
    }
  }

  static Future<Position> _getCurrentPosition() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}