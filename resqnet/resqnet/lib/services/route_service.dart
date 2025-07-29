import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class RouteService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/directions/json';
  static const String _apiKey = 'AIzaSyCGYjT7qcHOVr8NXJ0Y_d0dRRICLkMnan0'; // Your Google Maps API key

  // Get route between two points
  static Future<RouteData?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String travelMode = 'driving',
  }) async {
    try {
      final String url = '$_baseUrl?'
          'origin=${origin.latitude},${origin.longitude}&'
          'destination=${destination.latitude},${destination.longitude}&'
          'mode=$travelMode&'
          'key=$_apiKey';

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          // Extract polyline points
          final polylinePoints = PolylinePoints();
          final String encodedPolyline = route['overview_polyline']['points'];
          final List<PointLatLng> polylineCoordinates = 
              polylinePoints.decodePolyline(encodedPolyline);
          
          // Convert to LatLng
          final List<LatLng> routePoints = polylineCoordinates
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList();
          
          // Extract route information
          final leg = route['legs'][0];
          final String distance = leg['distance']['text'];
          final String duration = leg['duration']['text'];
          final int distanceValue = leg['distance']['value']; // in meters
          final int durationValue = leg['duration']['value']; // in seconds
          
          return RouteData(
            points: routePoints,
            distance: distance,
            duration: duration,
            distanceValue: distanceValue,
            durationValue: durationValue,
            bounds: _calculateBounds(routePoints),
          );
        }
      }
      
      print('Error getting route: ${response.body}');
      return null;
      
    } catch (e) {
      print('Error fetching route: $e');
      return null;
    }
  }

  // Calculate bounds for the route to fit the map view
  static LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // Get estimated time of arrival
  static String getETA(int durationInSeconds) {
    final now = DateTime.now();
    final eta = now.add(Duration(seconds: durationInSeconds));
    
    final hour = eta.hour;
    final minute = eta.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }
}

// Data class to hold route information
class RouteData {
  final List<LatLng> points;
  final String distance;
  final String duration;
  final int distanceValue;
  final int durationValue;
  final LatLngBounds bounds;

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    required this.distanceValue,
    required this.durationValue,
    required this.bounds,
  });
}
