import 'dart:math';

class LocationUtils {
  static Future<List<String>> getNearbyHospitals(double lat, double lng) async {
    return [
      "Mulago Hospital - 0.338,32.581",
      "Nakasero Hospital - 0.318,32.585",
      "Case Clinic - 0.313,32.582"
    ];
  }

  static Future<List<String>> getNearbyUsers(double lat, double lng) async {
    return [
      "User1 - 0.320,32.579",
      "User2 - 0.322,32.583",
      "User3 - 0.324,32.588",
      "User4 - 0.328,32.590",
      "User5 - 0.330,32.593"
    ];
  }

  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
