import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class ApiConfig {
  // Base URLs for different environments
  static const String _prodBaseUrl =
      'https://xsmi514ucd.execute-api.us-east-1.amazonaws.com/prod';
  static const String _testBaseUrl =
      'https://5957u6zvu3.execute-api.us-east-1.amazonaws.com/prod';
  static const String _devBaseUrl = 'https://dev-api.grippedapp.com';

  // Environment flag - change this for different builds
  static const Environment _environment =
      Environment.production; // Change to prod for production

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
  static String get getUserProfile => '$baseUrl/profile/me';
  static String get updateUserProfile => '$baseUrl/profile/me';
  static String get getPresignedUrls => '$baseUrl/profile/presigned-url';
  static String get getDownloadUrl => '$baseUrl/profile/download-url';
  static String get deleteUserProfile => '$baseUrl/profile/me';

  // Class endpoints
  static String get getClassesByTrainer => '$baseUrl/trainers/me/classes';
  static String get createClass => '$baseUrl/classes';
  static String get updateClass => '$baseUrl/classes';
  static String get deleteClass => '$baseUrl/classes';
  static String get enrollInClass =>
      '$baseUrl/classes'; // + /{sessionId}/enroll
  static String get getStudentClasses => '$baseUrl/students/me/classes';
  static String get sendClassMessage =>
      '$baseUrl/classes'; // + /{sessionId}/messages

  // Search endpoints
  static String get searchClasses => '$baseUrl/classes/search';

  // Rating endpoints
  static String get getRatings => '$baseUrl/ratings';
  static String get submitRating => '$baseUrl/ratings';
  static String get updateRating => '$baseUrl/ratings'; // + /{trainerId}
  static String get deleteRating => '$baseUrl/ratings'; // + /{trainerId}

  // S3 bucket URL for profile images
  static String get s3BucketUrl => 'https://grippedstack-userphotosbucket4d5de39b-gvc8qfaefzit.s3.us-east-1.amazonaws.com';

  // Authentication headers
  static Future<Map<String, String>> getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      final cognitoSession = session as CognitoAuthSession;
      final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;

      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $idToken',
      };
    } catch (e) {
      print('Error getting auth headers: $e');
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
  }
}

enum Environment { production, test, development }
