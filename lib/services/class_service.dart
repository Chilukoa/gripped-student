import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart' hide UserProfile;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as app_config;
import '../models/training_class.dart';

class ClassService {
  static final ClassService _instance = ClassService._internal();
  factory ClassService() => _instance;
  ClassService._internal();

  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final token = session.userPoolTokensResult.value.accessToken.raw;
        
        return {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
      }
    } catch (e) {
      safePrint('Error getting auth headers: $e');
    }
    
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<TrainingClass>> getClassesByTrainer() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(app_config.ApiConfig.getClassesByTrainer),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> classesJson = data['classes'] ?? data;
        return classesJson.map((json) => TrainingClass.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get classes: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error getting classes: $e');
      rethrow;
    }
  }

  Future<TrainingClass> createClass(TrainingClass trainingClass) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode(trainingClass.toJson());

      final response = await http.post(
        Uri.parse(app_config.ApiConfig.createClass),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return TrainingClass.fromJson(data);
      } else {
        throw Exception('Failed to create class: ${response.statusCode}');
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
        Uri.parse('${app_config.ApiConfig.updateClass}/${trainingClass.id}'),
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
}
