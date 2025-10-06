import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as config;
import '../models/training_class.dart';

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
  /// Based on the test-geospatial-search.py implementation
  Future<List<TrainingClass>> searchClasses({
    required String zipCode,
    String? query,
    String radiusMiles = "30",
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
        final classes = responseData['classes'] as List<dynamic>? ?? [];
        
        return classes
            .map((classData) => TrainingClass.fromJson(classData as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Failed to search classes: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      safePrint('StudentService: Error searching classes: $e');
      throw Exception('Failed to search classes: $e');
    }
  }

  /// Get enrolled classes for the current student
  Future<Map<String, dynamic>> getEnrolledClasses() async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.get(
        Uri.parse('$_baseUrl/students/me/classes'),
        headers: _getAuthHeaders(token),
      );

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
}
