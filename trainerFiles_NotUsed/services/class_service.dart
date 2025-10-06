import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart' hide UserProfile;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as app_config;
import '../models/training_class.dart';
import '../models/class_creation.dart';

class ClassService {
  static final ClassService _instance = ClassService._internal();
  factory ClassService() => _instance;
  ClassService._internal();

  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final token = session.userPoolTokensResult.value.idToken.raw;
        safePrint('ClassService Token length: ${token.length}');
        safePrint(
          'ClassService Token first 20 chars: ${token.substring(0, 20)}...',
        );

        final headers = {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };

        safePrint(
          'ClassService Authorization header: Bearer ${token.substring(0, 20)}...',
        );
        return headers;
      }
    } catch (e) {
      safePrint('ClassService Error getting auth headers: $e');
    }

    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  Future<List<TrainingClass>> getClassesByTrainer() async {
    try {
      final headers = await _getAuthHeaders();

      // Get the trainer ID from the current session
      final session = await Amplify.Auth.fetchAuthSession();
      final cognitoSession = session as CognitoAuthSession;
      final trainerId = cognitoSession.userSubResult.value;

      // Build URL with trainerId query parameter (matching test file format)
      final url =
          '${app_config.ApiConfig.getClassesByTrainer}?trainerId=$trainerId';

      safePrint('ClassService: Fetching classes from $url');
      safePrint('ClassService: Using headers: $headers');

      final response = await http.get(Uri.parse(url), headers: headers);

      safePrint('ClassService: Response status: ${response.statusCode}');
      safePrint('ClassService: Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        safePrint('ClassService: Decoded data type: ${data.runtimeType}');
        safePrint('ClassService: Decoded data: $data');

        // Handle both array and object responses
        List<dynamic> classesJson;
        if (data is List) {
          classesJson = data;
        } else if (data is Map && data['classes'] != null) {
          classesJson = data['classes'];
        } else {
          classesJson = [];
        }

        safePrint('ClassService: Classes array length: ${classesJson.length}');

        if (classesJson.isEmpty) {
          safePrint('ClassService: No classes found - returning empty list');
          return [];
        }

        final allClasses = classesJson
            .map((json) => TrainingClass.fromJson(json))
            .toList();

        // Filter out cancelled and past classes - only show active future classes
        final now = DateTime.now();
        final activeClasses = allClasses.where((trainingClass) {
          final isActive = trainingClass.status.toUpperCase() == 'ACTIVE';
          final isFuture = trainingClass.endTime.isAfter(now);
          return isActive && isFuture;
        }).toList();

        // Sort classes by start time in ascending order (earliest first)
        activeClasses.sort((a, b) => a.startTime.compareTo(b.startTime));

        safePrint(
          'ClassService: Total classes: ${allClasses.length}, Active future classes: ${activeClasses.length}',
        );
        return activeClasses;
      } else if (response.statusCode == 404) {
        // No classes found - return empty list
        safePrint('ClassService: No classes found for trainer');
        return [];
      } else {
        safePrint(
          'ClassService: API Error - Status: ${response.statusCode}, Body: ${response.body}',
        );
        throw Exception(
          'Failed to get classes: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error getting classes: $e');
      rethrow;
    }
  }

  Future<ClassCreationResponse> createClass(
    ClassCreationRequest classRequest,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode(classRequest.toJson());

      safePrint('ClassService: Creating class with payload: $body');

      final response = await http.post(
        Uri.parse(app_config.ApiConfig.createClass),
        headers: headers,
        body: body,
      );

      safePrint(
        'ClassService: Create class response status: ${response.statusCode}',
      );
      safePrint('ClassService: Create class response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return ClassCreationResponse.fromJson(data);
      } else {
        throw Exception(
          'Failed to create class: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error creating class: $e');
      rethrow;
    }
  }

  Future<TrainingClass> updateClass(TrainingClass trainingClass) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode(trainingClass.toJson());

      final response = await http.put(
        Uri.parse(
          '${app_config.ApiConfig.updateClass}/${trainingClass.sessionId}',
        ),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TrainingClass.fromJson(data);
      } else {
        throw Exception('Failed to update class: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error updating class: $e');
      rethrow;
    }
  }

  Future<TrainingClass> updateClassWithPayload(
    String sessionId,
    Map<String, dynamic> updatePayload,
  ) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode(updatePayload);

      safePrint('ClassService: Updating class $sessionId with payload: $body');

      final response = await http.put(
        Uri.parse('${app_config.ApiConfig.updateClass}/$sessionId'),
        headers: headers,
        body: body,
      );

      safePrint(
        'ClassService: Update class response status: ${response.statusCode}',
      );
      safePrint('ClassService: Update class response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return TrainingClass.fromJson(data);
      } else {
        throw Exception(
          'Failed to update class: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error updating class: $e');
      rethrow;
    }
  }

  Future<void> deleteClass(String classId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.delete(
        Uri.parse('${app_config.ApiConfig.deleteClass}/$classId'),
        headers: headers,
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete class: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error deleting class: $e');
      rethrow;
    }
  }

  Future<void> sendMessage(String sessionId, String messageText) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({'messageText': messageText});

      // URL format: POST /classes/{sessionId}/messages
      final url = '${app_config.ApiConfig.baseUrl}/classes/$sessionId/messages';

      safePrint('ClassService: Sending message to $url');
      safePrint('ClassService: Message payload: $body');

      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: body,
      );

      safePrint(
        'ClassService: Send message response status: ${response.statusCode}',
      );
      safePrint('ClassService: Send message response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception(
          'Failed to send message: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> cancelClass(String sessionId) async {
    try {
      final headers = await _getAuthHeaders();

      // URL format: DELETE /classes/{sessionId}
      final url = '${app_config.ApiConfig.baseUrl}/classes/$sessionId';

      safePrint('ClassService: Cancelling class at $url');

      final response = await http.delete(Uri.parse(url), headers: headers);

      safePrint(
        'ClassService: Cancel class response status: ${response.statusCode}',
      );
      safePrint('ClassService: Cancel class response body: ${response.body}');

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
          'Failed to cancel class: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error cancelling class: $e');
      rethrow;
    }
  }
}
