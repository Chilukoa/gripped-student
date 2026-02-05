import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

class ApiConfig {
  // Base URLs for different environments
  // nonProd = dev/beta AWS account (841162691071)
  // prod = production AWS account (371457438483)
  static const String _nonProdBaseUrl =
      'https://xsmi514ucd.execute-api.us-east-1.amazonaws.com/prod';
  static const String _prodBaseUrl =
      'https://3q2dju8479.execute-api.us-east-1.amazonaws.com/prod';
  static const String _betaBaseUrl =
      'https://5957u6zvu3.execute-api.us-east-1.amazonaws.com/prod';

  // Stripe publishable keys per environment
  static const String _nonProdStripeKey =
      'pk_test_51SGlhA37CiRnvWXT4OXsu5Eb5eP0eGP6vGWjO2hnJDWSCx0gGiB6LlRVwVlyVedRsVmqihjmdMAylYeXEQSSlmsz00Vo4YYh9J';
  static const String _prodStripeKey =
      'pk_live_51SsWEW2NzmiT6SLdA2BsnjSuC3vJceoLJQinNW4UWxC50fchfdhkNw4pi2Z8o2I8i1ADk5fDC7zJCehjBIL7idvJ00HhKgng5C';

  // S3 bucket URLs per environment
  static const String _nonProdS3BucketUrl =
      'https://grippedstack-userphotosbucket4d5de39b-gvc8qfaefzit.s3.us-east-1.amazonaws.com';
  static const String _prodS3BucketUrl =
      'https://grippedstack-userphotosbucket4d5de39b-gvc8qfaefzit.s3.us-east-1.amazonaws.com'; // Update with prod bucket when available

  // Environment flag - change this for different builds
  // nonProd = development/testing, prod = real production
  static const Environment _environment =
      Environment.nonProd; // Change to Environment.prod for production deployment

  static String get baseUrl {
    switch (_environment) {
      case Environment.prod:
        return _prodBaseUrl;
      case Environment.nonProd:
        return _nonProdBaseUrl;
      case Environment.beta:
        return _betaBaseUrl;
    }
  }

  static String get stripePublishableKey {
    switch (_environment) {
      case Environment.prod:
        return _prodStripeKey;
      case Environment.nonProd:
      case Environment.beta:
        return _nonProdStripeKey;
    }
  }

  static String get s3BucketUrl {
    switch (_environment) {
      case Environment.prod:
        return _prodS3BucketUrl;
      case Environment.nonProd:
      case Environment.beta:
        return _nonProdS3BucketUrl;
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
  static String get batchEnrollClasses => '$baseUrl/classes/batch-enroll';

  // Trainer endpoints
  static String getTrainerProfile(String trainerId) => '$baseUrl/trainers/$trainerId/profile';
  static String getTrainerClasses(String trainerId) => '$baseUrl/trainers/$trainerId/classes';

  // Rating endpoints
  static String get getRatings => '$baseUrl/ratings';
  static String get submitRating => '$baseUrl/ratings';
  static String get updateRating => '$baseUrl/ratings'; // + /{trainerId}
  static String get deleteRating => '$baseUrl/ratings'; // + /{trainerId}

  // Customer Support endpoints
  static String get createSupportTicket => '$baseUrl/support';
  static String get getSupportTickets => '$baseUrl/support';
  static String get getSupportTicket => '$baseUrl/support'; // + /{ticketId}
  static String get updateSupportTicket => '$baseUrl/support'; // + /{ticketId}

  // S3 bucket URL for profile images (environment-aware)
  // Use s3BucketUrl getter above instead of this hardcoded value

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

enum Environment { prod, nonProd, beta }
