import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class MapsService {

  // Get address from coordinates
  static Future<String?> getAddressFromCoordinates(
      double latitude,
      double longitude
      ) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return null;
    }

    final url = '${ApiConfig.geocodingApi}?latlng=$latitude,$longitude&key=${ApiConfig.mapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          return data['results'][0]['formatted_address'];
        }
      }
    } catch (e) {
      print('Error getting address: $e');
    }

    return null;
  }

  // Get coordinates from address
  static Future<Map<String, double>?> getCoordinatesFromAddress(String address) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return null;
    }

    final url = '${ApiConfig.geocodingApi}?address=${Uri.encodeComponent(address)}&key=${ApiConfig.mapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'latitude': location['lat'].toDouble(),
            'longitude': location['lng'].toDouble(),
          };
        }
      }
    } catch (e) {
      print('Error getting coordinates: $e');
    }

    return null;
  }

  // Calculate fastest route to emergency location)
  static Future<Map<String, dynamic>?> getEmergencyRoute(
      double startLat,
      double startLng,
      double emergencyLat,
      double emergencyLng,
      ) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return null;
    }

    final origin = '$startLat,$startLng';
    final destination = '$emergencyLat,$emergencyLng';

    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=driving&key=${ApiConfig.mapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return {
            'distance': leg['distance']['text'],
            'duration': leg['duration']['text'],
            'distanceValue': leg['distance']['value'], // in meters
            'durationValue': leg['duration']['value'], // in seconds
          };
        }
      }
    } catch (e) {
      print('Error getting emergency route: $e');
    }

    return null;
  }

  // Find nearby emergency services
  static Future<List<Map<String, dynamic>>> findNearbyEmergencyServices(
      double latitude,
      double longitude, {
        int radius = 10000,
        List<String> serviceTypes = const ['hospital', 'police'],
      }) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return [];
    }

    List<Map<String, dynamic>> emergencyServices = [];

    for (String serviceType in serviceTypes) {
      final services = await _findServiceType(latitude, longitude, serviceType, radius);
      emergencyServices.addAll(services);
    }

    return emergencyServices;
  }

  // Helper method to find specific service type
  static Future<List<Map<String, dynamic>>> _findServiceType(
      double latitude,
      double longitude,
      String serviceType,
      int radius,
      ) async {
    final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&type=$serviceType&key=${ApiConfig.mapsApiKey}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null) {
          return (data['results'] as List).map((place) => {
            'name': place['name'],
            'vicinity': place['vicinity'],
            'latitude': place['geometry']['location']['lat'],
            'longitude': place['geometry']['location']['lng'],
            'rating': place['rating'],
            'serviceType': serviceType,
            'placeId': place['place_id'],
          }).toList();
        }
      }
    } catch (e) {
      print('Error finding $serviceType: $e');
    }

    return [];
  }

  // Validate API key
  static Future<bool> validateApiKey() async {
    if (!ApiConfig.isConfigured) return false;

    try {
      final response = await http.get(
          Uri.parse('https://maps.googleapis.com/maps/api/geocode/json?address=test&key=${ApiConfig.mapsApiKey}')
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
