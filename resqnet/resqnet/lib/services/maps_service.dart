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

  // Calculate route between two points
  static Future<Map<String, dynamic>?> getRoute(
      double startLat,
      double startLng,
      double endLat,
      double endLng, {
        String mode = 'driving', // driving, walking, bicycling, transit
      }) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return null;
    }

    final origin = '$startLat,$startLng';
    final destination = '$endLat,$endLng';
    final url = 'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$destination&mode=$mode&key=${ApiConfig.mapsApiKey}';

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
            'polyline': route['overview_polyline']['points'],
            'steps': leg['steps'],
          };
        }
      }
    } catch (e) {
      print('Error getting route: $e');
    }

    return null;
  }

  // Find nearby places (hospitals, police stations, etc.)
  static Future<List<Map<String, dynamic>>> findNearbyPlaces(
      double latitude,
      double longitude,
      String placeType, {
        int radius = 5000, // 5km default
      }) async {
    if (!ApiConfig.isConfigured) {
      print('Warning: Google Maps API key not configured');
      return [];
    }

    final url = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$latitude,$longitude&radius=$radius&type=$placeType&key=${ApiConfig.mapsApiKey}';

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
            'placeId': place['place_id'],
            'types': place['types'],
          }).toList();
        }
      }
    } catch (e) {
      print('Error finding nearby places: $e');
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
