class ApiConfig {
  // Base URLs for different environments
  static const String _prodBaseUrl = 'https://api.grippedapp.com';
  static const String _testBaseUrl = 'https://test-api.grippedapp.com';
  static const String _devBaseUrl = 'https://dev-api.grippedapp.com';
  
  // Environment flag - change this for different builds
  static const Environment _environment = Environment.test; // Change to prod for production
  
  static String get baseUrl {
    switch (_environment) {
      case Environment.production:
        return _prodBaseUrl;
      case Environment.test:
        return _testBaseUrl;
      case Environment.development:
        return _devBaseUrl;
    }
  }
  
  // User endpoints
  static String get getUserProfile => '$baseUrl/user/profile';
  static String get updateUserProfile => '$baseUrl/user/profile';
  static String get uploadImage => '$baseUrl/user/upload-image';
  
  // Class endpoints
  static String get getClassesByTrainer => '$baseUrl/classes/trainer';
  static String get createClass => '$baseUrl/classes';
  static String get updateClass => '$baseUrl/classes';
  static String get deleteClass => '$baseUrl/classes';
  
  // Authentication headers
  static Future<Map<String, String>> getAuthHeaders() async {
    // This will be implemented to get the JWT token from Cognito
    // For now, returning basic headers
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }
}

enum Environment {
  production,
  test,
  development,
}
