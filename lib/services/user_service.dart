import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart' hide UserProfile;
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as app_config;
import '../models/user_profile.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

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

  Future<UserProfile?> getUserProfile() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(app_config.ApiConfig.getUserProfile),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return UserProfile.fromJson(data);
      } else if (response.statusCode == 404) {
        // User profile doesn't exist yet
        return null;
      } else {
        throw Exception('Failed to get user profile: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error getting user profile: $e');
      rethrow;
    }
  }

  Future<UserProfile> createOrUpdateUserProfile(UserProfile profile) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode(profile.toJson());

      final response = await http.post(
        Uri.parse(app_config.ApiConfig.updateUserProfile),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return UserProfile.fromJson(data);
      } else {
        throw Exception('Failed to update user profile: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(File imageFile, String imageType) async {
    try {
      final headers = await _getAuthHeaders();
      headers.remove('Content-Type'); // Let http package set this for multipart

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(app_config.ApiConfig.uploadImage),
      );
      
      request.headers.addAll(headers);
      request.fields['imageType'] = imageType; // 'profile' or 'id'
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['imageUrl']; // Assuming the API returns the image URL
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error uploading image: $e');
      rethrow;
    }
  }
}
