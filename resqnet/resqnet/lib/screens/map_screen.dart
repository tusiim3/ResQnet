import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';

class MapScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;

  const MapScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkTheme,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _destination;
  LatLng? _userLocation;
  List<Map<String, dynamic>> _emergencies = [];
  Set<Marker> _markers = {};
  bool _mapReady = false;
  bool _isLoading = true;
  String? _error;

  // Use user's location as initial position, fallback to Kampala
  CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(0.315, 32.582), // Kampala coordinates (fallback)
    zoom: 12.0,
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Get user location and load map data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initializeMap();
        setState(() {
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _error = 'Failed to load map data: $e';
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _initializeMap() async {
    // Get user's current GPS location
    _userLocation = await LocationService.getCurrentGPSLocation();
    
    // If we got user location, update initial position
    if (_userLocation != null) {
      _initialPosition = CameraPosition(
        target: _userLocation!,
        zoom: 16.0, // Closer zoom for user location
      );
    }

    // Load destination from SMS
    await _loadDestinationFromSMS();
    
    // Load all active emergencies
    await _loadEmergencies();
    
    // Create markers for emergencies
    _createMarkers();
  }

  Future<void> _loadEmergencies() async {
    try {
      _emergencies = await LocationService.getAllActiveEmergencies();
    } catch (e) {
      print('Error loading emergencies: $e');
      _emergencies = [];
    }
  }

  void _createMarkers() {
    _markers.clear();

    // Add emergency markers (red)
    for (var emergency in _emergencies) {
      _markers.add(
        Marker(
          markerId: MarkerId('emergency_${emergency['id']}'),
          position: LatLng(emergency['latitude'], emergency['longitude']),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: '🚨 Emergency Alert',
            snippet: 'Rider: ${emergency['riderName']} • ${emergency['timeElapsed']}\nTap for details',
            onTap: () => _showEmergencyDetails(emergency),
          ),
        ),
      );
    }

    // Add destination marker if exists
    if (_destination != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          infoWindow: const InfoWindow(
            title: "Emergency Location",
            snippet: "Tap for more details",
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        ),
      );
    }
  }

  void _showEmergencyDetails(Map<String, dynamic> emergency) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Emergency Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('👤 Rider: ${emergency['riderName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('⏰ Time: ${emergency['timeElapsed']}'),
            const SizedBox(height: 8),
            Text('🏥 Helmet ID: ${emergency['helmetId']}'),
            if (emergency['additionalInfo'].isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('ℹ️ Info: ${emergency['additionalInfo']}'),
            ],
            const SizedBox(height: 12),
            const Text('📍 Location:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${emergency['latitude'].toStringAsFixed(6)}, ${emergency['longitude'].toStringAsFixed(6)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Could add navigation to emergency location here
            },
            child: const Text('Get Directions'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDestinationFromSMS() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMessage = prefs.getString('last_location_message');

    if (lastMessage != null) {
      final match = RegExp(r'^.+ - ([\-0-9.]+), ?([\-0-9.]+)$').firstMatch(lastMessage);
      if (match != null) {
        final lat = double.parse(match.group(1)!);
        final lng = double.parse(match.group(2)!);
        _destination = LatLng(lat, lng);
      }
    }

    setState(() {
      _mapReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // required for keep-alive
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map View'),
        actions: [
          IconButton(
            icon: Icon(widget.isDarkTheme ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: () => widget.toggleTheme(!widget.isDarkTheme),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading map...'),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _isLoading = true;
                          });
                          _loadDestinationFromSMS();
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _mapReady
                  ? GoogleMap(
                      initialCameraPosition: _initialPosition,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                      buildingsEnabled: false,
                      trafficEnabled: false,
                      onMapCreated: (GoogleMapController controller) async {
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                          
                          // Center map on user location once controller is ready
                          if (_userLocation != null) {
                            await controller.animateCamera(
                              CameraUpdate.newCameraPosition(
                                CameraPosition(
                                  target: _userLocation!,
                                  zoom: 16.0,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      markers: _markers,
                    )
                  : const Center(
                      child: Text('Map not ready'),
                    ),
    );
  }
}
