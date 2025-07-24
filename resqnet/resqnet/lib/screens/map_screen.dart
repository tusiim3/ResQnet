import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _mapReady = false;
  bool _isLoading = true;
  String? _error;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.315, 32.582), // Kampala coordinates
    zoom: 12.0, // Reduced zoom for better performance
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Add delay to ensure proper initialization
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await _loadDestinationFromSMS();
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
                      mapToolbarEnabled: false, // Reduces rendering overhead
                      buildingsEnabled: false, // Reduces rendering complexity
                      trafficEnabled: false, // Reduces data usage and rendering
                      onMapCreated: (GoogleMapController controller) {
                        if (!_controller.isCompleted) {
                          _controller.complete(controller);
                        }
                      },
                      markers: _destination != null
                          ? {
                              Marker(
                                markerId: const MarkerId('destination'),
                                position: _destination!,
                                infoWindow: const InfoWindow(
                                  title: "Emergency Location",
                                  snippet: "Tap for more details",
                                ),
                                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                              )
                            }
                          : {},
                    )
                  : const Center(
                      child: Text('Map not ready'),
                    ),
    );
  }
}
