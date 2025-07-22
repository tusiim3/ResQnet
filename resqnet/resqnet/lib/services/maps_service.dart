import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../config/api_config.dart';

class MapsService {
  static final _cache = <String, List<Map<String, dynamic>>>{};
  static DateTime? _lastFetchTime;

  static Future<List<Map<String, dynamic>>> fetchNearbyHospitals(
    double lat,
    double lng, {
    int radius = 5000,
    bool useCache = true,
  }) async {
    final cacheKey = 'hospitals_${lat}_${lng}';
    
    if (useCache && 
        _cache.containsKey(cacheKey) && 
        _lastFetchTime != null && 
        DateTime.now().difference(_lastFetchTime!) < Duration(minutes: 5)) {
      return _cache[cacheKey]!;
    }

    const endpoint = 'https://maps.googleapis.com/maps/api/place/nearbysearch/json';
    final url = Uri.parse('$endpoint?'
        'location=$lat,$lng'
        '&radius=$radius'
        '&type=hospital'
        '&key=${ApiConfig.mapsApiKey}');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = _parseHospitalResponse(response.body, lat, lng);
        _cache[cacheKey] = data;
        _lastFetchTime = DateTime.now();
        return data;
      }
      return [];
    } catch (e) {
      print('Hospital fetch error: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> _parseHospitalResponse(
      String response, double originLat, double originLng) {
    try {
      final jsonData = jsonDecode(response);
      final results = (jsonData['results'] as List).map((hospital) {
        final lat = hospital['geometry']['location']['lat'];
        final lng = hospital['geometry']['location']['lng'];
        return {
          'name': hospital['name']?.toString() ?? 'Unknown Hospital',
          'vicinity': hospital['vicinity']?.toString() ?? 'Address not available',
          'distance': _calculateDistance(originLat, originLng, lat, lng)
              .toStringAsFixed(1),
          'latitude': lat,
          'longitude': lng,
        };
      }).toList();

      results.sort((a, b) => double.parse(a['distance']!)
          .compareTo(double.parse(b['distance']!)));
      return results;
    } catch (e) {
      print('Response parsing error: $e');
      return [];
    }
  }

  static double _calculateDistance(lat1, lng1, lat2, lng2) {
    const earthRadius = 6371; // km
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180);
}