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

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(0.315, 32.582), // Kampala coordinates
    zoom: 13.0, // Safer zoom to prevent surface overload
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDestinationFromSMS();
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
      body: _mapReady
          ? GoogleMap(
              initialCameraPosition: _initialPosition,
              myLocationEnabled: true,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _destination != null
                  ? {
                      Marker(
                        markerId: const MarkerId('destination'),
                        position: _destination!,
                        infoWindow: const InfoWindow(title: "Emergency Location"),
                      )
                    }
                  : {},
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}
