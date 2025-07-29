import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../services/location_service.dart'; // Ensure this path is correct
import '../services/route_service.dart';

class MapScreen extends StatefulWidget {
  final Function(bool) toggleTheme;
  final bool isDarkTheme;
  final LatLng? emergencyLocation; // Emergency location for navigation
  final String? emergencyDescription; // Description of the emergency

  const MapScreen({
    super.key,
    required this.toggleTheme,
    required this.isDarkTheme,
    this.emergencyLocation,
    this.emergencyDescription,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  final Completer<GoogleMapController> _controller = Completer();
  LatLng? _emergencyLocation; // Emergency location for navigation
  LatLng? _userLocation;
  bool _mapReady = false;
  bool _isLoading = true;
  String? _error;
  
  // Navigation/routing variables
  RouteData? _currentRoute;
  bool _isNavigating = false;
  Timer? _navigationTimer;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

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
    // Check if this is navigation mode
    if (widget.emergencyLocation != null) {
      _isNavigating = true;
      _emergencyLocation = widget.emergencyLocation;
    }
    
    // Get user location and load map data
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _initializeMap();
        
        // If navigating, start route calculation
        if (_isNavigating && _userLocation != null && _emergencyLocation != null) {
          await _calculateAndDrawRoute();
          _startNavigationTracking();
        }
        
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

    // Set map ready immediately - no need to wait for SMS data
    setState(() {
      _mapReady = true;
    });
  }

  // Helper to create markers from emergency data (from LocationService's stream)
  // This will be used for both SMS destination and live emergencies.
  Marker _createEmergencyMarker(
    String id,
    LatLng position,
    String title,
    String snippet,
    BitmapDescriptor icon,
  ) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
        onTap: () {
          // You can add logic here to navigate to a detail screen or show a bottom sheet
          print('Tapped on marker: $id');
        },
      ),
      icon: icon,
    );
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
                          _initializeMap(); // Re-attempt map initialization
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _mapReady // Only display map if it's ready after initial setup
                  ? Stack(
                      children: [
                        // Main map
                        StreamBuilder<List<Map<String, dynamic>>>(
                          // Listen to the stream of active emergencies
                      stream: LocationService.getAllActiveEmergencies(),
                      builder: (context, snapshot) {
                        // Start with an empty set of markers
                        Set<Marker> currentMarkers = {};

                        // Add streamed emergency markers
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          for (var emergency in snapshot.data!) {
                            currentMarkers.add(
                              _createEmergencyMarker(
                                'emergency_${emergency['id']}', // Unique ID for streamed markers
                                LatLng(emergency['latitude']?.toDouble() ?? 0.0, emergency['longitude']?.toDouble() ?? 0.0),
                                'Emergency: ${emergency['riderName']} (${emergency['timeElapsed']})',
                                emergency['additionalInfo'] ?? 'Tap for details',
                                BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Consistent with SMS marker
                              ),
                            );
                          }
                        } else if (snapshot.connectionState == ConnectionState.waiting) {
                          // Optionally show a small loading indicator on the map if stream is still waiting
                          // For a class project, you might skip this for simplicity
                          print('Waiting for emergency data...');
                        } else if (snapshot.hasError) {
                          // Handle stream errors (e.g., Firestore permission denied)
                          print('Error loading emergencies: ${snapshot.error}');
                          // Could display a small toast or message on the map
                        }

                        // The GoogleMap widget now receives its markers from the StreamBuilder's snapshot
                        return GoogleMap(
                          initialCameraPosition: _initialPosition,
                          myLocationEnabled: !_isNavigating, // Hide default location when navigating
                          myLocationButtonEnabled: !_isNavigating,
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
                          // Combine emergency markers with navigation markers
                          markers: _isNavigating 
                              ? {...currentMarkers, ..._markers}
                              : currentMarkers,
                          // Add route polylines when navigating
                          polylines: _isNavigating ? _polylines : {},
                        );
                      },
                    ),
                    
                    // Navigation UI overlay
                    if (_isNavigating && _currentRoute != null)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.navigation, color: Color(0xFF2ECC71)),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Navigating to Emergency',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      setState(() {
                                        _isNavigating = false;
                                        _currentRoute = null;
                                        _polylines.clear();
                                        _markers.clear();
                                      });
                                      _navigationTimer?.cancel();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      Text(
                                        _currentRoute!.distance,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2ECC71),
                                        ),
                                      ),
                                      const Text('Distance'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        _currentRoute!.duration,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF3498DB),
                                        ),
                                      ),
                                      const Text('Duration'),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      Text(
                                        RouteService.getETA(_currentRoute!.durationValue),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFE74C3C),
                                        ),
                                      ),
                                      const Text('ETA'),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                )
                  : const Center(
                      child: Text('Map not ready'),
                    ),
    );
  }

  // Calculate and draw route from user location to destination
  Future<void> _calculateAndDrawRoute() async {
    if (_userLocation == null || _emergencyLocation == null) {
      print('Cannot calculate route: missing location data');
      return;
    }

    try {
      print('Calculating route from $_userLocation to $_emergencyLocation');
      
      // Check if destination is very close (less than 50 meters)
      final double distance = _calculateDistance(_userLocation!, _emergencyLocation!);
      print('Distance to emergency: ${(distance * 1000).toStringAsFixed(0)} meters');
      
      if (distance < 0.05) { // Less than 50 meters
        print('Destination very close, showing markers only');
        setState(() {
          // For very close destinations, just show markers without route
          _markers = {
            Marker(
              markerId: const MarkerId('origin'),
              position: _userLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: _emergencyLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Emergency Location',
                snippet: widget.emergencyDescription ?? 'Emergency Alert - Very Close!',
              ),
            ),
          };
          _polylines = {}; // No route line for very close destinations
        });
        
        // Center camera between the two points with high zoom
        try {
          final GoogleMapController controller = await _controller.future.timeout(
            const Duration(seconds: 3),
          );
          
          final LatLng centerPoint = LatLng(
            (_userLocation!.latitude + _emergencyLocation!.latitude) / 2,
            (_userLocation!.longitude + _emergencyLocation!.longitude) / 2,
          );
          
          await controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: centerPoint,
                zoom: 19.0, // Very high zoom for close destinations
              ),
            ),
          );
        } catch (e) {
          print('Error positioning camera for close destination: $e');
        }
        return;
      }
      
      final routeData = await RouteService.getRoute(
        origin: _userLocation!,
        destination: _emergencyLocation!,
        travelMode: 'driving',
      );

      if (routeData != null) {
        setState(() {
          _currentRoute = routeData;
          
          // Create polyline for the route
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routeData.points,
              color: const Color(0xFF2ECC71), // Green route color
              width: 5,
              patterns: [],
            ),
          };

          // Create markers for origin and destination
          _markers = {
            Marker(
              markerId: const MarkerId('origin'),
              position: _userLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: _emergencyLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Emergency Location',
                snippet: widget.emergencyDescription ?? 'Emergency Alert',
              ),
            ),
          };
        });

        // Adjust camera to show the entire route
        await _fitRouteToBounds(routeData.bounds);
        
        print('Route calculated: ${routeData.distance}, ${routeData.duration}');
      } else {
        print('Failed to calculate route - RouteService returned null');
        // Still show markers even if route calculation fails
        setState(() {
          _markers = {
            Marker(
              markerId: const MarkerId('origin'),
              position: _userLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: _emergencyLocation!,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: InfoWindow(
                title: 'Emergency Location',
                snippet: widget.emergencyDescription ?? 'Emergency Alert',
              ),
            ),
          };
        });
      }
    } catch (e) {
      print('Error calculating route: $e');
      // Show markers even if route calculation fails
      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: _userLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
            infoWindow: const InfoWindow(title: 'Your Location'),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: _emergencyLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Emergency Location',
              snippet: widget.emergencyDescription ?? 'Emergency Alert',
            ),
          ),
        };
      });
    }
  }

  // Fit the route to map bounds
  Future<void> _fitRouteToBounds(LatLngBounds bounds) async {
    try {
      // Check if map controller is ready before proceeding
      if (!_controller.isCompleted) {
        print('Map controller not ready, waiting...');
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_controller.isCompleted) {
          print('Map controller still not ready after delay');
          return;
        }
      }

      final GoogleMapController controller = await _controller.future.timeout(
        const Duration(seconds: 5), // Reduced timeout
        onTimeout: () {
          throw TimeoutException('Map controller timeout after 5 seconds');
        },
      );
      
      // Calculate distance between bounds to check if they're too close
      final double distance = _calculateDistance(
        LatLng(bounds.southwest.latitude, bounds.southwest.longitude),
        LatLng(bounds.northeast.latitude, bounds.northeast.longitude),
      );
      
      // If coordinates are very close (less than 100m), use a fixed zoom instead
      if (distance < 0.1) { // Less than 100 meters
        print('Destination very close, using fixed zoom instead of bounds');
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(
                (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
                (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
              ),
              zoom: 18.0, // High zoom for very close destinations
            ),
          ),
        );
      } else {
        // Add padding around the route for normal distances
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 100.0),
        );
      }
      
      print('Camera adjusted successfully for route bounds');
    } catch (e) {
      print('Error fitting route to bounds: $e');
      // If bounds fitting fails, just center on destination with appropriate zoom
      try {
        final GoogleMapController controller = await _controller.future.timeout(
          const Duration(seconds: 3),
        );
        
        // Calculate distance to emergency to determine appropriate zoom
        final double distanceToEmergency = _userLocation != null 
            ? _calculateDistance(_userLocation!, _emergencyLocation!)
            : 1.0;
            
        // Choose zoom level based on distance
        double zoomLevel = 15.0;
        if (distanceToEmergency < 0.1) { // Less than 100m
          zoomLevel = 18.0;
        } else if (distanceToEmergency < 0.5) { // Less than 500m
          zoomLevel = 16.0;
        } else if (distanceToEmergency < 2.0) { // Less than 2km
          zoomLevel = 14.0;
        } else {
          zoomLevel = 12.0;
        }
        
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _emergencyLocation!,
              zoom: zoomLevel,
            ),
          ),
        );
        
        print('Fallback camera centering successful with zoom $zoomLevel');
      } catch (e2) {
        print('Error in fallback camera positioning: $e2');
      }
    }
  }

  // Start navigation tracking with periodic route recalculation
  void _startNavigationTracking() {
    _navigationTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_userLocation != null && _emergencyLocation != null) {
        // Get current location
        final currentLocation = await LocationService.getCurrentGPSLocation();
        if (currentLocation != null) {
          final newLocation = LatLng(currentLocation.latitude, currentLocation.longitude);
          
          // Check if user has moved significantly (more than 50 meters)
          final distanceMoved = _calculateDistance(_userLocation!, newLocation);
          
          if (distanceMoved > 0.05) { // 50 meters
            setState(() {
              _userLocation = newLocation;
            });
            
            // Recalculate route if user went off course
            await _calculateAndDrawRoute();
            print('Route recalculated due to location change');
          }
        }
      }
    });
  }

  // Calculate distance between two points in kilometers
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371; // Earth radius in kilometers
    
    final double lat1Rad = point1.latitude * (pi / 180);
    final double lat2Rad = point2.latitude * (pi / 180);
    final double deltaLatRad = (point2.latitude - point1.latitude) * (pi / 180);
    final double deltaLngRad = (point2.longitude - point1.longitude) * (pi / 180);
    
    final double a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final double c = 2 * asin(sqrt(a));
    
    return earthRadius * c;
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }
}
