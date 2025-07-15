import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'nearby_rider_alert_service.dart';
import 'maps_service.dart';

class EmergencyService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NearbyRiderAlertService _nearbyRiderService = NearbyRiderAlertService();

  // Create emergency alert (triggered by Smart Boda Helmet crash detection)
  Future<String?> createEmergencyAlert({
    required String alertType, // 'crash', 'panic' (only these are supported by hardware)
    required double latitude,
    required double longitude,
    required String helmetId,
    String? description,
    String? severity, // 'low', 'medium', 'high', 'critical'
    Map<String, dynamic>? sensorData, // MPU6050 impact data only
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return null;

    final docRef = await _db.collection('emergency_alerts').add({
      'userId': userId,
      'helmetId': helmetId,
      'alertType': alertType,
      'location': {
        'latitude': latitude,
        'longitude': longitude,
      },
      'description': description,
      'severity': severity ?? 'medium',
      'sensorData': sensorData,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'active', // 'active', 'acknowledged', 'resolved', 'false_alarm'
      'responseTime': null,
      'responderId': null,
      'isResolved': false,
      'emergencyContacts': [],
      'notifications': [],
    });

    // Automatically notify emergency contacts
    await _notifyEmergencyContacts(docRef.id, userId, alertType, latitude, longitude);

    // Alert nearby riders about the emergency
    await _nearbyRiderService.alertNearbyRiders(
      emergencyAlertId: docRef.id,
      latitude: latitude,
      longitude: longitude,
      alertType: alertType,
      emergencyDescription: description,
    );

    return docRef.id;
  }

  // Get active emergency alerts
  Stream<QuerySnapshot> getActiveEmergencyAlerts() {
    return _db
        .collection('emergency_alerts')
        .where('status', whereIn: ['active', 'acknowledged'])
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Get user's emergency history
  Stream<QuerySnapshot> getUserEmergencyHistory(String userId) {
    return _db
        .collection('emergency_alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Update emergency alert status
  Future<void> updateAlertStatus({
    required String alertId,
    required String status,
    String? responderId,
    String? response,
  }) async {
    final updateData = {
      'status': status,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    if (responderId != null) {
      updateData['responderId'] = responderId;
      updateData['responseTime'] = FieldValue.serverTimestamp();
    }

    if (response != null) {
      updateData['response'] = response;
    }

    if (status == 'resolved') {
      updateData['isResolved'] = true;
      updateData['resolvedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('emergency_alerts').doc(alertId).update(updateData);
  }

  // Add emergency contact
  Future<void> addEmergencyContact({
    required String name,
    required String phoneNumber,
    required String relationship,
    String? email,
    bool isPrimary = false,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('emergency_contacts').add({
      'userId': userId,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'relationship': relationship,
      'isPrimary': isPrimary,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get user's emergency contacts
  Stream<QuerySnapshot> getEmergencyContacts(String userId) {
    return _db
        .collection('emergency_contacts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('isPrimary', descending: true)
        .snapshots();
  }

  // Notify emergency contacts (private method)
  Future<void> _notifyEmergencyContacts(
      String alertId,
      String userId,
      String alertType,
      double latitude,
      double longitude,
      ) async {
    // Get user's emergency contacts
    final contactsSnapshot = await _db
        .collection('emergency_contacts')
        .where('userId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .get();

    List<String> notifiedContacts = [];

    for (var contactDoc in contactsSnapshot.docs) {
      final contactData = contactDoc.data();
      final phoneNumber = contactData['phoneNumber'] as String;
      final name = contactData['name'] as String;

      // Create notification record
      await _db.collection('notifications').add({
        'alertId': alertId,
        'userId': userId,
        'contactId': contactDoc.id,
        'contactName': name,
        'contactPhone': phoneNumber,
        'alertType': alertType,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'message': _generateEmergencyMessage(alertType, name),
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // 'pending', 'sent', 'failed'
      });

      notifiedContacts.add(contactDoc.id);
    }

    // Update alert with notified contacts
    await _db.collection('emergency_alerts').doc(alertId).update({
      'emergencyContacts': notifiedContacts,
    });
  }

  // Generate emergency message
  String _generateEmergencyMessage(String alertType, String contactName) {
    switch (alertType) {
      case 'crash':
        return 'EMERGENCY: $contactName may have been in a motorcycle accident. Location and emergency services have been notified. Please check on them immediately.';
      case 'panic':
        return 'ALERT: $contactName has triggered a panic alarm on their smart helmet. Please contact them immediately to check their safety.';
      default:
        return 'ALERT: $contactName has triggered an emergency alert on their smart helmet. Please check on their safety.';
    }
  }

  // Get nearby emergency services using Google Maps API
  Future<List<Map<String, dynamic>>> getNearbyEmergencyServices({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  }) async {
    // Use real Google Maps API instead of mock data
    return await MapsService.findNearbyEmergencyServices(
      latitude,
      longitude,
      radius: (radiusKm * 1000).toInt(), // Convert km to meters
      serviceTypes: ['hospital', 'police'], // Emergency services only
    );
  }

  // Create manual emergency alert (panic button)
  Future<String?> createPanicAlert({
    required double latitude,
    required double longitude,
    required String helmetId,
    String? description,
  }) async {
    return createEmergencyAlert(
      alertType: 'panic',
      latitude: latitude,
      longitude: longitude,
      helmetId: helmetId,
      description: description,
      severity: 'high',
    );
  }

  // Test emergency system
  Future<void> testEmergencySystem() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('emergency_alerts').add({
      'userId': userId,
      'helmetId': 'TEST_HELMET',
      'alertType': 'test',
      'location': {
        'latitude': 0.0,
        'longitude': 0.0,
      },
      'description': 'Emergency system test',
      'severity': 'low',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'resolved',
      'isResolved': true,
      'isTest': true,
    });
  }

  // Get emergency statistics for user
  Future<Map<String, dynamic>> getEmergencyStatistics(String userId) async {
    final snapshot = await _db
        .collection('emergency_alerts')
        .where('userId', isEqualTo: userId)
        .where('isTest', isNotEqualTo: true)
        .get();

    Map<String, int> alertsByType = {};
    int resolvedCount = 0;
    int falseAlarmCount = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final alertType = data['alertType'] as String;
      final status = data['status'] as String;

      alertsByType[alertType] = (alertsByType[alertType] ?? 0) + 1;

      if (status == 'resolved') resolvedCount++;
      if (status == 'false_alarm') falseAlarmCount++;
    }

    return {
      'totalAlerts': snapshot.docs.length,
      'alertsByType': alertsByType,
      'resolvedAlerts': resolvedCount,
      'falseAlarms': falseAlarmCount,
      'activeAlerts': snapshot.docs.length - resolvedCount - falseAlarmCount,
    };
  }
}
