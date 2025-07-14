class ApiConfig {
  // Google Maps API Key
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY_HERE';

  // i had added Firebase Configuration but later realises Okure already handled it in firebase_options.dart. Mann😂😭

  // in case we need these endpoints too
  static const String emergencyServicesApi = 'https://api.emergency-services.com';
  static const String geocodingApi = 'https://maps.googleapis.com/maps/api/geocode/json';

  // API Configuration for different environments
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static String get mapsApiKey {
    // You can have different API keys for development and production
    return googleMapsApiKey;
  }

  // Validate API key is configured
  static bool get isConfigured {
    return googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY_HERE' &&
        googleMapsApiKey.isNotEmpty;
  }
}

// Environment-specific configurations
class EnvironmentConfig {
  static const String development = 'development';
  static const String production = 'production';

  static String get currentEnvironment {
    return isProduction ? production : development;
  }

  static bool get isProduction {
    return bool.fromEnvironment('dart.vm.product');
  }

  // Different configurations for different environments
  static Map<String, dynamic> get config {
    if (isProduction) {
      return {
        'apiTimeout': 30000, // 30 seconds
        'locationUpdateInterval': 5000, // 5 seconds
        'emergencyTimeout': 10000, // 10 seconds
        'maxRetries': 3,
      };
    } else {
      return {
        'apiTimeout': 10000, // 10 seconds
        'locationUpdateInterval': 2000, // 2 seconds for testing
        'emergencyTimeout': 5000, // 5 seconds for testing
        'maxRetries': 1,
      };
    }
  }
}
