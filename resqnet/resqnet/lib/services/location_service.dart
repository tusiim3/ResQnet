import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

  // Save real-time location from helmet - Simplified for class project
  Future<void> saveLocation({
    required double latitude,
    required double longitude,
  }) async {
    // Check if user is authenticated with Firebase (for permissions)
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      // Get the original user document ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final originalUserId = prefs.getString('original_user_id');
      
      if (originalUserId == null) {
        print('No original user ID found');
        return;
      }

      // Update user's current location in the existing user document
      await _db.collection('users').doc(originalUserId).set({
        'currentLocation': {
          'latitude': latitude,
          'longitude': longitude,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  // Update user presence and location when app opens
  Future<void> updateUserPresence() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      // Get the original user document ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final originalUserId = prefs.getString('original_user_id');
      
      if (originalUserId == null) {
        print('No original user ID found for presence update');
        return;
      }

      // Get current GPS location
      final location = await getCurrentGPSLocation();
      
      Map<String, dynamic> updateData = {
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': true,
      };

      // If we got GPS location, update it too
      if (location != null) {
        updateData['currentLocation'] = {
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        };
      }

      await _db.collection('users').doc(originalUserId).set(updateData, SetOptions(merge: true));
    } catch (e) {
      print('Error updating user presence: $e');
    }
  }

  // Mark user as offline
  Future<void> markUserOffline() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      await _db.collection('users').doc(userId).set({
        'lastSeen': FieldValue.serverTimestamp(),
        'isOnline': false,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error marking user offline: $e');
    }
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

  // Save emergency location when crash is detected - Simplified for class project
  Future<void> saveEmergencyLocation({
    required double latitude,
    required double longitude,
    String? additionalInfo,
    Map<String, dynamic>? crashData,
  }) async {
    // Use the original user ID from SharedPreferences instead of Firebase Auth UID
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('original_user_id');
    
    if (userId == null) {
      print('No original user ID found for emergency alert');
      return;
    }

    await _db.collection('emergency_locations').add({
      'userId': userId,
      'latitude': latitude,
      'longitude': longitude,
      'additionalInfo': additionalInfo,
      'crashData': crashData,
      'timestamp': FieldValue.serverTimestamp(),
      'isEmergency': true,
      'isResolved': false,
      'responseTime': null,
      'riderUsername': 'Rider', // Using generic name for simplicity
    });
    
    print('Emergency alert created for user: $userId');
  }

  // Get all active emergencies for map display
  static Stream<List<Map<String, dynamic>>> getAllActiveEmergencies() {
    return FirebaseFirestore.instance
        .collection('emergency_locations')
        .where('isResolved', isEqualTo: false)
        .orderBy('timestamp', descending: true)
        .snapshots() // This is the key change: now listening for real-time updates!
        .asyncMap((querySnapshot) async { // Use asyncMap to process each snapshot asynchronously
          List<Map<String, dynamic>> emergencies = [];

          for (var doc in querySnapshot.docs) {
            final data = doc.data();
            
            // Get user details for the emergency - now more efficient due to 'riderUsername' denormalization
            String riderName = 'Unknown Rider';
            if (data.containsKey('riderUsername')) {
              riderName = data['riderUsername'];
            } else {
              // Fallback to fetching user data if 'riderUsername' wasn't denormalized (less efficient)
              // In a production app, you'd aim to avoid this fallback entirely.
              try {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(data['userId'])
                    .get();
                
                if (userDoc.exists) {
                  riderName = userDoc.data()?['username'] ?? userDoc.data()?['name'] ?? 'Unknown Rider';
                }
              } catch (e) {
                print('Error getting rider name: $e');
              }
            }

            // Calculate time elapsed
            String timeElapsed = 'Unknown time';
            if (data['timestamp'] != null) {
              final emergencyTime = (data['timestamp'] as Timestamp).toDate();
              final now = DateTime.now();
              final difference = now.difference(emergencyTime);
              
              if (difference.inMinutes < 60) {
                timeElapsed = '${difference.inMinutes} mins ago';
              } else if (difference.inHours < 24) {
                timeElapsed = '${difference.inHours} hours ago';
              } else {
                timeElapsed = '${difference.inDays} days ago';
              }
            }

            emergencies.add({
              'id': doc.id,
              'latitude': data['latitude']?.toDouble() ?? 0.0,
              'longitude': data['longitude']?.toDouble() ?? 0.0,
              'riderName': riderName,
              'alertType': 'Emergency', // Set to Emergency since all are emergencies
              'timeElapsed': timeElapsed,
              'additionalInfo': data['additionalInfo'] ?? '',
              'helmetId': data['helmetId'] ?? 'Unknown',
              'timestamp': data['timestamp'],
            });
          }
          return emergencies; // Return the list of emergencies
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
    double radiusKm = 5.0, // Default radius for nearby search
  }) async {
    try {
      // Get all users with current location - Simplified for class project
      final usersSnapshot = await _db.collection('users')
          .where('currentLocation', isNotEqualTo: null)
          .get();

      List<Map<String, dynamic>> nearbyRiders = [];

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        final currentLocation = data['currentLocation'] as Map<String, dynamic>?;

        if (currentLocation != null) {
          final riderLat = currentLocation['latitude'] as double?;
          final riderLng = currentLocation['longitude'] as double?;

          if (riderLat != null && riderLng != null) {
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
      }

      nearbyRiders.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      return nearbyRiders;
    } catch (e) {
      print('Error getting nearby riders: $e');
      return [];
    }
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

          // Get additional details for the hospital (N+1 HTTP call here, fine for small limit)
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

  // Instance version of distance calculation
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
