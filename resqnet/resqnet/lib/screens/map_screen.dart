import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/location_service.dart';
import '../services/emergency_service.dart';
import '../services/nearby_rider_alert_service.dart';
import '../config/api_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  Position? _currentPosition;
  bool _isLoading = true;
  String _locationStatus = 'Getting location...';

  // Services
  final LocationService _locationService = LocationService();
  final EmergencyService _emergencyService = EmergencyService();
  final NearbyRiderAlertService _nearbyRiderService = NearbyRiderAlertService();

  // Map data
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};

  // Current user location
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(0.3476, 32.5825), // Kampala, Uganda
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    // Check API configuration
    if (!ApiConfig.isConfigured) {
      setState(() {
        _locationStatus = 'Google Maps API key not configured';
        _isLoading = false;
      });
      return;
    }

    // Request location permissions
    await _requestLocationPermissions();

    // Get current location
    await _getCurrentLocation();

    // Load emergency alerts on map
    await _loadEmergencyMarkers();

    // Load nearby responders
    await _loadNearbyResponders();

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _requestLocationPermissions() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();
    }

    if (status.isPermanentlyDenied) {
      setState(() {
        _locationStatus = 'Location permission denied. Please enable in settings.';
      });
      return;
    }

    if (status.isGranted) {
      setState(() {
        _locationStatus = 'Location permission granted';
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = 'Location services are disabled.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = 'Location permissions denied';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = 'Location permissions permanently denied';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _locationStatus = 'Location found';
      });

      // Save location to backend
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _locationService.saveLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          helmetId: 'HELMET_${user.uid.substring(0, 8)}',
        );
      }

      // Add current location marker
      _addCurrentLocationMarker();

    } catch (e) {
      setState(() {
        _locationStatus = 'Error getting location: $e';
      });
    }
  }

  void _addCurrentLocationMarker() {
    if (_currentPosition != null) {
      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId('current_location'),
            position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'You are here',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );

        // Add circle showing alert radius
        _circles.add(
          Circle(
            circleId: const CircleId('alert_radius'),
            center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            radius: NearbyRiderAlertService.DEFAULT_ALERT_RADIUS_KM * 1000, // Convert to meters
            fillColor: Colors.blue.withValues(alpha: 0.1),
            strokeColor: Colors.blue,
            strokeWidth: 2,
          ),
        );
      });
    }
  }

  Future<void> _loadEmergencyMarkers() async {
    try {
      final emergencyStream = _emergencyService.getActiveEmergencyAlerts();

      emergencyStream.listen((snapshot) {
        final Set<Marker> emergencyMarkers = {};

        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final location = data['location'] as Map<String, dynamic>;
          final latitude = (location['latitude'] as num).toDouble();
          final longitude = (location['longitude'] as num).toDouble();
          final alertType = data['alertType'] as String;

          emergencyMarkers.add(
            Marker(
              markerId: MarkerId('emergency_${doc.id}'),
              position: LatLng(latitude, longitude),
              infoWindow: InfoWindow(
                title: 'Emergency Alert',
                snippet: '${alertType.toUpperCase()} - Tap for details',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                alertType == 'crash' ? BitmapDescriptor.hueRed : BitmapDescriptor.hueOrange,
              ),
              onTap: () => _showEmergencyDetails(doc.id, data),
            ),
          );
        }

        setState(() {
          // Keep current location marker and add emergency markers
          _markers.removeWhere((marker) => marker.markerId.value.startsWith('emergency_'));
          _markers.addAll(emergencyMarkers);
        });
      });
    } catch (e) {
      print('Error loading emergency markers: $e');
    }
  }

  void _showEmergencyDetails(String alertId, Map<String, dynamic> alertData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildEmergencyDetailsSheet(alertId, alertData),
    );
  }

  Widget _buildEmergencyDetailsSheet(String alertId, Map<String, dynamic> alertData) {
    final alertType = alertData['alertType'] as String;
    final description = alertData['description'] as String?;
    final severity = alertData['severity'] as String;
    final timestamp = (alertData['timestamp'] as Timestamp).toDate();

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  alertType == 'crash' ? Icons.warning : Icons.info,
                  color: severity == 'critical' ? Colors.red : Colors.orange,
                  size: 30,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${alertType.toUpperCase()} Alert',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Severity: ${severity.toUpperCase()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: severity == 'critical' ? Colors.red : Colors.orange,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Time: ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 16),
            ),
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(
                'Description: $description',
                style: const TextStyle(fontSize: 16),
              ),
            ],
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _respondToEmergency(alertId),
                    icon: const Icon(Icons.directions_run),
                    label: const Text('I can help'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _callEmergencyServices(),
                    icon: const Icon(Icons.phone),
                    label: const Text('Call 999'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _respondToEmergency(String alertId) {
    // Update alert status that user is responding
    _nearbyRiderService.updateRiderAlertStatus(
      alertId: alertId,
      status: 'responding',
      actionTaken: 'User marked as responding to emergency',
    );

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you! Your response has been recorded.'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _callEmergencyServices() {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calling emergency services...'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2C3E50)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Live Map',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C3E50),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location, color: Color(0xFF4A90E2)),
            onPressed: () {
              _centerOnLocation();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4A90E2)),
            onPressed: () {
              _getCurrentLocation();
              _loadEmergencyMarkers();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Loading map...'),
          ],
        ),
      )
          : _currentPosition == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.location_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              _locationStatus,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getCurrentLocation,
              child: const Text('Retry'),
            ),
          ],
        ),
      )
          : GoogleMap(
        initialCameraPosition: CameraPosition(
          target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          zoom: 14.0,
        ),
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
        },
        markers: _markers,
        circles: _circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
      ),
      floatingActionButton: _currentPosition != null
          ? FloatingActionButton(
        onPressed: _triggerPanicAlert,
        backgroundColor: Colors.red,
        child: const Icon(Icons.warning, color: Colors.white),
      )
          : null,
    );
  }

  void _centerOnLocation() {
    if (_currentPosition != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            zoom: 16.0,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available'),
          backgroundColor: Color(0xFF4A90E2),
        ),
      );
    }
  }

  Future<void> _loadNearbyResponders() async {
    try {
      if (_currentPosition == null) return;

      // Listen to nearby riders/responders
      final nearbyRespondersStream = FirebaseFirestore.instance
          .collection('users')
          .where('isResponder', isEqualTo: true)
          .snapshots();

      nearbyRespondersStream.listen((snapshot) {
        final Set<Marker> responderMarkers = {};

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final latitude = data['latitude'] as double?;
          final longitude = data['longitude'] as double?;
          final name = data['name'] as String? ?? 'Responder';
          final isAvailable = data['isAvailable'] as bool? ?? false;

          if (latitude != null && longitude != null && isAvailable) {
            // Calculate distance from current position
            double distance = _calculateDistance(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              latitude,
              longitude,
            );

            // Only show responders within 5km
            if (distance <= 5.0) {
              responderMarkers.add(
                Marker(
                  markerId: MarkerId('responder_${doc.id}'),
                  position: LatLng(latitude, longitude),
                  infoWindow: InfoWindow(
                    title: name,
                    snippet: 'Available responder (${distance.toStringAsFixed(1)}km away)',
                  ),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),
              );
            }
          }
        }

        setState(() {
          // Remove old responder markers and add new ones
          _markers.removeWhere((marker) => marker.markerId.value.startsWith('responder_'));
          _markers.addAll(responderMarkers);
        });
      });
    } catch (e) {
      print('Error loading nearby responders: $e');
    }
  }

  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371; // km
    const double degToRad = 0.0174532925199433; // pi/180

    double dLat = (lat2 - lat1) * degToRad;
    double dLng = (lng2 - lng1) * degToRad;

    double a = (dLat / 2) * (dLat / 2) +
        (lat1 * degToRad) * (lat2 * degToRad) *
            (dLng / 2) * (dLng / 2);

    double c = 2 * (a * (1 - a)).abs();

    return earthRadius * c;
  }

  void _triggerPanicAlert() async {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location not available for panic alert'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Panic Alert'),
        content: const Text('This will send an emergency alert to nearby riders and your emergency contacts. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Send Alert', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _emergencyService.createPanicAlert(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        helmetId: 'HELMET_${FirebaseAuth.instance.currentUser?.uid.substring(0, 8)}',
        description: 'Manual panic alert triggered from app',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Panic alert sent! Help is on the way.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}