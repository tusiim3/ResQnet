import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class NearbyRiderAlertService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Recommended alert radius
  static const double DEFAULT_ALERT_RADIUS_KM = 3.0;

  // Send emergency alert to nearby riders
  Future<List<String>> alertNearbyRiders({
    required String emergencyAlertId,
    required double latitude,
    required double longitude,
    required String alertType,
    String? emergencyDescription,
    double radiusKm = DEFAULT_ALERT_RADIUS_KM,
  }) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return [];

    // Get current user info
    final currentUserDoc = await _db.collection('users').doc(currentUserId).get();
    final currentUserData = currentUserDoc.data();
    final currentUserName = currentUserData?['username'] ?? 'A rider';

    // Find nearby riders
    final nearbyRiders = await _getNearbyActiveRiders(
      latitude: latitude,
      longitude: longitude,
      radiusKm: radiusKm,
      excludeUserId: currentUserId,
    );

    List<String> notifiedRiderIds = [];

    // Send alerts to each nearby rider
    for (var rider in nearbyRiders) {
      try {
        await _sendRiderAlert(
          targetRiderId: rider['userId'],
          emergencyAlertId: emergencyAlertId,
          emergencyLocation: {'latitude': latitude, 'longitude': longitude},
          alertType: alertType,
          emergencyUserName: currentUserName,
          description: emergencyDescription,
          distanceKm: rider['distance'],
        );
        notifiedRiderIds.add(rider['userId']);
      } catch (e) {
        print('Failed to alert rider ${rider['userId']}: $e');
      }
    }

    // Log the nearby alert activity
    await _logNearbyAlert(
      emergencyAlertId: emergencyAlertId,
      alertLocation: {'latitude': latitude, 'longitude': longitude},
      nearbyRidersCount: nearbyRiders.length,
      notifiedRidersCount: notifiedRiderIds.length,
      radiusKm: radiusKm,
    );

    return notifiedRiderIds;
  }

  // Get nearby active riders
  Future<List<Map<String, dynamic>>> _getNearbyActiveRiders({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String excludeUserId,
  }) async {
    // Get users who have been active in the last 30 minutes
    final thirtyMinutesAgo = DateTime.now().subtract(const Duration(minutes: 30));

    final snapshot = await _db
        .collection('users')
        .where('currentLocation', isNotEqualTo: null)
        .get();

    List<Map<String, dynamic>> nearbyRiders = [];

    for (var doc in snapshot.docs) {
      if (doc.id == excludeUserId) continue; // Don't alert the user in emergency

      final data = doc.data();
      final currentLocation = data['currentLocation'] as Map<String, dynamic>?;

      if (currentLocation != null) {
        final locationTimestamp = (currentLocation['timestamp'] as Timestamp?)?.toDate();

        // Check if location is recent (rider is active)
        if (locationTimestamp != null && locationTimestamp.isAfter(thirtyMinutesAgo)) {
          final riderLat = (currentLocation['latitude'] as num).toDouble();
          final riderLng = (currentLocation['longitude'] as num).toDouble();

          final distance = _calculateDistance(latitude, longitude, riderLat, riderLng);

          if (distance <= radiusKm) {
            nearbyRiders.add({
              'userId': doc.id,
              'username': data['username'] ?? 'Unknown',
              'latitude': riderLat,
              'longitude': riderLng,
              'distance': distance,
              'lastSeen': locationTimestamp,
              'phone': data['phone'],
              'fullName': data['fullName'],
            });
          }
        }
      }
    }

    // Sort by distance (closest first)
    nearbyRiders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));

    return nearbyRiders;
  }

  // Send alert to individual rider
  Future<void> _sendRiderAlert({
    required String targetRiderId,
    required String emergencyAlertId,
    required Map<String, double> emergencyLocation,
    required String alertType,
    required String emergencyUserName,
    String? description,
    required double distanceKm,
  }) async {
    await _db.collection('rider_alerts').add({
      'targetRiderId': targetRiderId,
      'emergencyAlertId': emergencyAlertId,
      'emergencyLocation': emergencyLocation,
      'alertType': alertType, // 'crash', 'panic', 'breakdown', etc.
      'emergencyUserName': emergencyUserName,
      'description': description,
      'distanceKm': distanceKm,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'sent', // 'sent', 'acknowledged', 'responding', 'ignored'
      'isRead': false,
      'responseTime': null,
      'actionTaken': null,
    });

    // Update rider's notification count
    await _db.collection('users').doc(targetRiderId).update({
      'unreadAlerts': FieldValue.increment(1),
      'lastAlertReceived': FieldValue.serverTimestamp(),
    });
  }

  // Log the nearby alert activity
  Future<void> _logNearbyAlert({
    required String emergencyAlertId,
    required Map<String, double> alertLocation,
    required int nearbyRidersCount,
    required int notifiedRidersCount,
    required double radiusKm,
  }) async {
    await _db.collection('nearby_alert_logs').add({
      'emergencyAlertId': emergencyAlertId,
      'alertLocation': alertLocation,
      'radiusKm': radiusKm,
      'nearbyRidersFound': nearbyRidersCount,
      'ridersNotified': notifiedRidersCount,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // Get alerts for a specific rider
  Stream<QuerySnapshot> getRiderAlerts(String riderId) {
    return _db
        .collection('rider_alerts')
        .where('targetRiderId', isEqualTo: riderId)
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }

  // Update rider alert status (when rider acknowledges or responds)
  Future<void> updateRiderAlertStatus({
    required String alertId,
    required String status, // 'acknowledged', 'responding', 'ignored'
    String? actionTaken,
  }) async {
    await _db.collection('rider_alerts').doc(alertId).update({
      'status': status,
      'actionTaken': actionTaken,
      'responseTime': FieldValue.serverTimestamp(),
      'isRead': true,
    });
  }

  // Mark alert as read
  Future<void> markAlertAsRead(String alertId, String riderId) async {
    await _db.collection('rider_alerts').doc(alertId).update({
      'isRead': true,
    });

    // Decrease unread count
    await _db.collection('users').doc(riderId).update({
      'unreadAlerts': FieldValue.increment(-1),
    });
  }

  // Get unread alert count for rider
  Future<int> getUnreadAlertCount(String riderId) async {
    final userDoc = await _db.collection('users').doc(riderId).get();
    return (userDoc.data()?['unreadAlerts'] as int?) ?? 0;
  }

  // Calculate distance between two points
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadians(lat2 - lat1);
    final double dLng = _toRadians(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
                sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // Get nearby alert statistics
  Future<Map<String, dynamic>> getNearbyAlertStats() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return {};

    // Alerts sent (emergencies where user was the one in trouble)
    final sentAlertsSnapshot = await _db
        .collection('nearby_alert_logs')
        .where('emergencyAlertId', isEqualTo: userId)
        .get();

    // Alerts received (emergencies where user was notified to help)
    final receivedAlertsSnapshot = await _db
        .collection('rider_alerts')
        .where('targetRiderId', isEqualTo: userId)
        .get();

    // Responses given (how many times user responded to help others)
    final responsesSnapshot = await _db
        .collection('rider_alerts')
        .where('targetRiderId', isEqualTo: userId)
        .where('status', isEqualTo: 'responding')
        .get();

    return {
      'emergenciesTriggered': sentAlertsSnapshot.docs.length,
      'alertsReceived': receivedAlertsSnapshot.docs.length,
      'timesResponded': responsesSnapshot.docs.length,
      'responseRate': receivedAlertsSnapshot.docs.isEmpty
          ? 0.0
          : (responsesSnapshot.docs.length / receivedAlertsSnapshot.docs.length * 100),
    };
  }
}
