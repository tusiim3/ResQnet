import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/api_config.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current GPS location
  static Future<LatLng?> getCurrentGPSLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      print('Error getting GPS location: $e');
      return null;
    }
  }

  // Move camera to user's location
  static Future<void> centerMapOnUserLocation(GoogleMapController controller) async {
    LatLng? userLocation = await getCurrentGPSLocation();
    if (userLocation != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: userLocation,
            zoom: 16.0, // Good zoom level for user location
          ),
        ),
      );
    }
  }

  // Save real-time location from helmet
  Future<void> saveLocation({
    required double latitude,
    required double longitude,
    required String helmetId,
    String? address,
    double? speed,
    double? heading,
    Map<String, dynamic>? safetyData,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('locations').add({
      'userId': userId,
      'helmetId': helmetId,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'speed': speed,
      'heading': heading,
      'safetyData': safetyData,
      'timestamp': FieldValue.serverTimestamp(),
      'isActive': true,
      'isEmergency': false,
    });

    // update user's current location
    await _db.collection('users').doc(userId).update({
      'currentLocation': {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      }
    });
  }

  // Get user's current location
  Future<Map<String, dynamic>?> getCurrentLocation(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    if (doc.exists && doc.data()?['currentLocation'] != null) {
      return doc.data()?['currentLocation'] as Map<String, dynamic>;
    }
    return null;
  }

  // Get location history for emergency tracking
  Stream<QuerySnapshot> getLocationHistory(String userId, {int limit = 100}) {
    return _db
        .collection('emergency_locations')
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots();
  }

  // Save emergency location when crash is detected
  Future<void> saveEmergencyLocation({
    required double latitude,
    required double longitude,
    required String helmetId,
    required String alertType,
    String? additionalInfo,
    Map<String, dynamic>? crashData,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _db.collection('emergency_locations').add({
      'userId': userId,
      'helmetId': helmetId,
      'latitude': latitude,
      'longitude': longitude,
      'alertType': alertType, // i was thinking that we have diff alerts; crash, panic, low_battery, etc.
      'additionalInfo': additionalInfo,
      'crashData': crashData,
      'timestamp': FieldValue.serverTimestamp(),
      'isEmergency': true,
      'isResolved': false,
      'responseTime': null,
    });
  }

  // Get emergency locations for monitoring dashboard
  Stream<QuerySnapshot> getEmergencyLocations() {
    return _db
        .collection('emergency_locations')
        .where('isResolved', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // Mark emergency as resolved
  Future<void> resolveEmergency(String emergencyId) async {
    await _db.collection('emergency_locations').doc(emergencyId).update({
      'isResolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get nearby riders
  Future<List<Map<String, dynamic>>> getNearbyRiders({
    required double latitude,
    required double longitude,
    double radiusKm = 5.0,
  }) async {
    // Guys we might have to use GeoFirestore for better calculations. I've left these simplified ones as place holders
    final snapshot = await _db
        .collection('users')
        .where('currentLocation', isNotEqualTo: null)
        .get();

    List<Map<String, dynamic>> nearbyRiders = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final currentLocation = data['currentLocation'] as Map<String, dynamic>?;

      if (currentLocation != null) {
        final riderLat = currentLocation['latitude'] as double;
        final riderLng = currentLocation['longitude'] as double;

        // Calculate distance
        final distance = _calculateDistance(latitude, longitude, riderLat, riderLng);

        if (distance <= radiusKm) {
          nearbyRiders.add({
            'userId': doc.id,
            'username': data['username'] ?? 'Unknown',
            'latitude': riderLat,
            'longitude': riderLng,
            'distance': distance,
          });
        }
      }
    }

    return nearbyRiders;
  }

  // Find nearest hospitals based on emergency location (returns multiple hospitals)
  static Future<List<Map<String, dynamic>>> findNearestHospitals(
    double emergencyLat, 
    double emergencyLng,
    {int limit = 3}
  ) async {
    try {
      final String apiKey = ApiConfig.googleMapsApiKey;
      final String url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
          '?location=$emergencyLat,$emergencyLng'
          '&radius=10000' // 10km radius
          '&type=hospital'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        if (results.isEmpty) {
          print('No hospitals found nearby');
          return [];
        }

        // Process and sort hospitals by distance
        final hospitals = await Future.wait(results.take(limit).map((place) async {
          final geometry = place['geometry'];
          final location = geometry['location'];
          final lat = location['lat'].toDouble();
          final lng = location['lng'].toDouble();

          double distance = _calculateDistanceStatic(
            emergencyLat,
            emergencyLng,
            lat,
            lng,
          );

          // Get additional details for the hospital
          String? phoneNumber = await _getPlacePhone(place['place_id'], apiKey);
          
          return {
            'name': place['name'] ?? 'Unknown Hospital',
            'latitude': lat,
            'longitude': lng,
            'phone': phoneNumber ?? 'Phone not available',
            'emergency': phoneNumber ?? '911', // Default emergency number
            'distance': distance,
            'address': place['vicinity'] ?? 'Address not available',
            'rating': place['rating']?.toDouble() ?? 0.0,
            'place_id': place['place_id'],
          };
        }));

        // Sort hospitals by distance (nearest first)
        hospitals.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
        return hospitals;
      } else {
        print('Error fetching hospitals: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Error finding nearest hospitals: $e');
      return [];
    }
  }

  // Keep the original single hospital finder for backward compatibility
  static Future<Map<String, dynamic>?> findNearestHospital(double emergencyLat, double emergencyLng) async {
    final hospitals = await findNearestHospitals(emergencyLat, emergencyLng, limit: 1);
    return hospitals.isNotEmpty ? hospitals.first : null;
  }

  // Get phone number for a specific place
  static Future<String?> _getPlacePhone(String placeId, String apiKey) async {
    try {
      final String url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=formatted_phone_number'
          '&key=$apiKey';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final result = data['result'];
        return result['formatted_phone_number'] as String?;
      }
    } catch (e) {
      print('Error getting place phone: $e');
    }
    return null;
  }

  // Static version of distance calculation for use in static methods
  static double _calculateDistanceStatic(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    final double dLat = _toRadiansStatic(lat2 - lat1);
    final double dLng = _toRadiansStatic(lng2 - lng1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadiansStatic(lat1)) * cos(_toRadiansStatic(lat2)) *
                sin(dLng / 2) * sin(dLng / 2);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadiansStatic(double degrees) {
    return degrees * (pi / 180);
  }

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
}