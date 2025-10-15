import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as config;

class StudentService {
  static final StudentService _instance = StudentService._internal();
  factory StudentService() => _instance;
  StudentService._internal();

  static String get _baseUrl => config.ApiConfig.baseUrl;

  Future<String> _getAuthToken() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      final cognitoSession = session as CognitoAuthSession;
      final idToken = cognitoSession.userPoolTokensResult.value.idToken.raw;
      return idToken;
    } catch (e) {
      safePrint('StudentService: Error getting auth token: $e');
      throw Exception('Authentication failed');
    }
  }

  Map<String, String> _getAuthHeaders(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Search for classes using geospatial search
  /// Based on the updated test-geospatial-search.py implementation
  Future<List<Map<String, dynamic>>> searchClasses({
    required String zipCode,
    String? query,
    String radiusMiles = "30",
    String? date,
  }) async {
    try {
      final token = await _getAuthToken();
      
      // Build query parameters
      final queryParams = <String, String>{
        'zipCode': zipCode,
        'radiusMiles': radiusMiles,
      };
      
      if (query != null && query.isNotEmpty) {
        queryParams['query'] = query;
      }
      
      if (date != null && date.isNotEmpty) {
        queryParams['date'] = date;
      }
      
      final uri = Uri.parse('$_baseUrl/classes/search').replace(
        queryParameters: queryParams,
      );

      safePrint('StudentService: Searching classes with URL: $uri');
      
      final response = await http.get(
        uri,
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Search response status: ${response.statusCode}');
      safePrint('StudentService: Search response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body) as Map<String, dynamic>;
        final results = responseData['results'] as List<dynamic>? ?? [];
        final totalFound = responseData['totalFound'] as int? ?? 0;
        final searchLocation = responseData['searchLocation'] as Map<String, dynamic>? ?? {};
        final radiusValue = responseData['radiusMiles'];
        final radius = radiusValue is int ? radiusValue.toDouble() : (radiusValue as double? ?? 0.0);
        
        safePrint('StudentService: Found $totalFound classes within $radius miles');
        safePrint('StudentService: Search location: ${searchLocation['latitude']}, ${searchLocation['longitude']}');
        
        return results.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to search classes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      safePrint('StudentService: Error searching classes: $e');
      throw Exception('Failed to search classes: $e');
    }
  }

  /// Get enrolled classes for the current student
  Future<Map<String, dynamic>> getEnrolledClasses({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final token = await _getAuthToken();
      
      // Build query parameters for date filtering
      final queryParams = <String, String>{};
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }
      
      // Build URI with query parameters
      final uri = Uri.parse('$_baseUrl/students/me/classes');
      final uriWithQuery = uri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      
      final response = await http.get(
        uriWithQuery,
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Get enrolled classes URL: ${uriWithQuery.toString()}');
      safePrint('StudentService: Get enrolled classes response status: ${response.statusCode}');
      safePrint('StudentService: Get enrolled classes response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to get enrolled classes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      safePrint('StudentService: Error getting enrolled classes: $e');
      throw Exception('Failed to get enrolled classes: $e');
    }
  }

  /// Enroll in a class session
  Future<void> enrollInClass(String sessionId) async {
    try {
      final token = await _getAuthToken();
      
      safePrint('StudentService: Enrolling in session: $sessionId');
      safePrint('StudentService: Enroll URL: $_baseUrl/classes/$sessionId/enroll');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/classes/$sessionId/enroll'),
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Enroll response status: ${response.statusCode}');
      safePrint('StudentService: Enroll response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to enroll in class: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error enrolling in class: $e');
      throw Exception('Failed to enroll in class: $e');
    }
  }

  /// Unenroll from a class session
  Future<void> unenrollFromClass(String sessionId) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.delete(
        Uri.parse('$_baseUrl/classes/$sessionId/enroll'),
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Unenroll response status: ${response.statusCode}');
      safePrint('StudentService: Unenroll response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to unenroll from class: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error unenrolling from class: $e');
      throw Exception('Failed to unenroll from class: $e');
    }
  }

  /// Submit a rating for a trainer
  Future<Map<String, dynamic>> submitRating({
    required String trainerId,
    required int rating,
    String? feedback,
    bool isAnonymous = false,
  }) async {
    try {
      final token = await _getAuthToken();
      
      final requestBody = {
        'trainerId': trainerId,
        'rating': rating,
        'feedback': feedback,
        'isAnonymous': isAnonymous,
      };
      
      safePrint('StudentService: Submitting rating for trainer: $trainerId');
      safePrint('StudentService: Rating data: $requestBody');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/ratings'),
        headers: _getAuthHeaders(token),
        body: json.encode(requestBody),
      );

      safePrint('StudentService: Submit rating response status: ${response.statusCode}');
      safePrint('StudentService: Submit rating response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to submit rating: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error submitting rating: $e');
      throw Exception('Failed to submit rating: $e');
    }
  }

  /// Update an existing rating for a trainer
  Future<Map<String, dynamic>> updateRating({
    required String trainerId,
    required int rating,
    String? feedback,
    bool isAnonymous = false,
  }) async {
    try {
      final token = await _getAuthToken();
      
      final requestBody = {
        'rating': rating,
        'feedback': feedback,
        'isAnonymous': isAnonymous,
      };
      
      safePrint('StudentService: Updating rating for trainer: $trainerId');
      safePrint('StudentService: Updated rating data: $requestBody');
      
      final response = await http.put(
        Uri.parse('$_baseUrl/ratings/$trainerId'),
        headers: _getAuthHeaders(token),
        body: json.encode(requestBody),
      );

      safePrint('StudentService: Update rating response status: ${response.statusCode}');
      safePrint('StudentService: Update rating response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to update rating: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error updating rating: $e');
      throw Exception('Failed to update rating: $e');
    }
  }

  /// Get rating submitted by current student for a specific trainer
  Future<Map<String, dynamic>?> getStudentRatingForTrainer(String trainerId) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/ratings'),
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Get student ratings response status: ${response.statusCode}');
      safePrint('StudentService: Get student ratings response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> ratings = responseData is List ? responseData : (responseData['ratings'] ?? []);
        
        // Find rating for specific trainer
        for (final rating in ratings) {
          if (rating is Map<String, dynamic> && rating['trainerId'] == trainerId) {
            return rating;
          }
        }
        return null; // No rating found for this trainer
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to get student ratings: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error getting student rating for trainer: $e');
      throw Exception('Failed to get student rating for trainer: $e');
    }
  }

  /// Get all ratings submitted by current student
  Future<List<Map<String, dynamic>>> getStudentRatings() async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/ratings'),
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Get all student ratings response status: ${response.statusCode}');
      safePrint('StudentService: Get all student ratings response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> ratings = responseData is List ? responseData : (responseData['ratings'] ?? []);
        return ratings.cast<Map<String, dynamic>>();
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to get student ratings: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error getting student ratings: $e');
      throw Exception('Failed to get student ratings: $e');
    }
  }

  /// Get average rating and rating count for a trainer
  Future<Map<String, dynamic>?> getTrainerRating(String trainerId) async {
    try {
      final token = await _getAuthToken();
      
      final uri = Uri.parse('$_baseUrl/ratings').replace(
        queryParameters: {
          'trainerId': trainerId,
          'summary': 'true',
        },
      );
      
      final response = await http.get(
        uri,
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Get trainer rating response status: ${response.statusCode}');
      safePrint('StudentService: Get trainer rating response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        // No ratings found for this trainer
        return null;
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to get trainer rating: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error getting trainer rating: $e');
      throw Exception('Failed to get trainer rating: $e');
    }
  }

  /// Get all detailed ratings for a trainer (for rating details view)
  Future<List<Map<String, dynamic>>> getTrainerRatingDetails(String trainerId) async {
    try {
      final token = await _getAuthToken();
      
      final uri = Uri.parse('$_baseUrl/ratings').replace(
        queryParameters: {
          'trainerId': trainerId,
        },
      );
      
      final response = await http.get(
        uri,
        headers: _getAuthHeaders(token),
      );

      safePrint('StudentService: Get trainer rating details response status: ${response.statusCode}');
      safePrint('StudentService: Get trainer rating details response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        // The endpoint returns a List<RatingResponse> directly
        if (responseData is List) {
          return responseData.cast<Map<String, dynamic>>();
        } else {
          throw Exception('Unexpected response format: expected List but got ${responseData.runtimeType}');
        }
      } else {
        final errorBody = response.body.isNotEmpty ? response.body : 'Unknown error';
        throw Exception('Failed to get trainer rating details: ${response.statusCode} - $errorBody');
      }
    } catch (e) {
      safePrint('StudentService: Error getting trainer rating details: $e');
      throw Exception('Failed to get trainer rating details: $e');
    }
  }
}
