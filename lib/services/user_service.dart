import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
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
        final token = session.userPoolTokensResult.value.idToken.raw;
        safePrint('Token length: ${token.length}');
        safePrint('Token preview: ${token.substring(0, 50)}...');

        return {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        };
      }
    } catch (e) {
      safePrint('Error getting auth headers: $e');
    }

    return {'Content-Type': 'application/json', 'Accept': 'application/json'};
  }

  Future<UserProfile?> getUserProfile() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse(app_config.ApiConfig.getUserProfile),
        headers: headers,
      );

      if (response.statusCode == 200) {
        safePrint('Raw profile response: ${response.body}');
        final data = json.decode(response.body);
        safePrint('Parsed profile data: $data');
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

      safePrint('Updating user profile...');
      safePrint('Request URL: ${app_config.ApiConfig.updateUserProfile}');
      safePrint('Request headers: $headers');
      safePrint('Request body: $body');

      final response = await http.put(
        Uri.parse(app_config.ApiConfig.updateUserProfile),
        headers: headers,
        body: body,
      );

      safePrint('Profile update response: ${response.statusCode}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        safePrint('Profile update response body: ${response.body}');
        final data = json.decode(response.body);
        return UserProfile.fromJson(data);
      } else {
        safePrint('Profile update error response: ${response.body}');
        throw Exception(
          'Failed to update user profile: ${response.statusCode}',
        );
      }
    } catch (e) {
      safePrint('Error updating user profile: $e');
      rethrow;
    }
  }

  Future<List<String>> uploadImages(List<File> imageFiles) async {
    try {
      // Get presigned URLs for all images
      final presignedUrls = await _getPresignedUrls(imageFiles.length);
      if (presignedUrls == null || presignedUrls.length != imageFiles.length) {
        throw Exception('Failed to get presigned URLs for images');
      }

      // Upload each image to S3 using presigned URLs
      final uploadedImageKeys = <String>[];
      for (int i = 0; i < imageFiles.length; i++) {
        final imageKey = await _uploadImageToS3(
          imageFiles[i],
          presignedUrls[i],
        );
        if (imageKey != null) {
          uploadedImageKeys.add(imageKey);
        } else {
          throw Exception('Failed to upload image ${i + 1}');
        }
      }

      return uploadedImageKeys;
    } catch (e) {
      safePrint('Error uploading images: $e');
      rethrow;
    }
  }

  Future<String?> uploadSingleImage(File imageFile) async {
    try {
      final imageKeys = await uploadImages([imageFile]);
      return imageKeys.isNotEmpty ? imageKeys.first : null;
    } catch (e) {
      safePrint('Error uploading single image: $e');
      rethrow;
    }
  }

  /// Upload image from bytes (web-compatible)
  Future<String?> uploadSingleImageFromBytes(Uint8List imageBytes, String fileName) async {
    try {
      // Get presigned URL for single image
      final presignedUrls = await _getPresignedUrls(1);
      if (presignedUrls == null || presignedUrls.isEmpty) {
        throw Exception('Failed to get presigned URL for image');
      }

      final presignedUrl = presignedUrls.first;
      safePrint('Uploading image from bytes to S3...');
      safePrint('Upload URL: ${presignedUrl['uploadUrl']}');
      safePrint('Image ID: ${presignedUrl['imageId']}');
      safePrint('Image size: ${imageBytes.length} bytes');

      final response = await http.put(
        Uri.parse(presignedUrl['uploadUrl']),
        headers: {'Content-Type': 'image/jpeg'},
        body: imageBytes,
      );

      safePrint('S3 upload response: ${response.statusCode}');
      if (response.statusCode != 200) {
        safePrint('S3 upload response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final imageId = presignedUrl['imageId'];
        safePrint('Successfully uploaded image with ID: $imageId');
        return imageId;
      } else {
        throw Exception(
          'Failed to upload to S3: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error uploading image from bytes: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>?> _getPresignedUrls(int imageCount) async {
    try {
      safePrint('Getting presigned URLs for $imageCount images...');
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'imageCount': imageCount,
        'contentType': 'image/jpeg',
      });

      safePrint('Request URL: ${app_config.ApiConfig.getPresignedUrls}');
      safePrint('Request headers: $headers');
      safePrint('Request body: $body');

      final response = await http.post(
        Uri.parse(app_config.ApiConfig.getPresignedUrls),
        headers: headers,
        body: body,
      );

      safePrint('Presigned URL response: ${response.statusCode}');
      safePrint('Presigned URL response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final urls = List<Map<String, dynamic>>.from(data['presignedUrls']);
        safePrint('Got ${urls.length} presigned URLs');
        return urls;
      } else {
        throw Exception(
          'Failed to get presigned URLs: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error getting presigned URLs: $e');
      return null;
    }
  }

  Future<String?> _uploadImageToS3(
    File imageFile,
    Map<String, dynamic> presignedUrl,
  ) async {
    try {
      safePrint('Uploading image to S3...');
      safePrint('Upload URL: ${presignedUrl['uploadUrl']}');
      safePrint('Image ID: ${presignedUrl['imageId']}');

      final imageBytes = await imageFile.readAsBytes();
      safePrint('Image size: ${imageBytes.length} bytes');

      final response = await http.put(
        Uri.parse(presignedUrl['uploadUrl']),
        headers: {'Content-Type': 'image/jpeg'},
        body: imageBytes,
      );

      safePrint('S3 upload response: ${response.statusCode}');
      if (response.statusCode != 200) {
        safePrint('S3 upload response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final imageId = presignedUrl['imageId'];
        safePrint('Successfully uploaded image with ID: $imageId');
        return imageId;
      } else {
        throw Exception(
          'Failed to upload to S3: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      safePrint('Error uploading to S3: $e');
      return null;
    }
  }

  // Method to get presigned download URL for viewing images
  Future<String?> getDownloadUrl(String imageKey, String userId) async {
    try {
      final fullKey = 'profiles/$userId/$imageKey.jpg';
      safePrint('Getting download URL for key: $fullKey');

      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('${app_config.ApiConfig.getDownloadUrl}?key=$fullKey'),
        headers: headers,
      );

      safePrint('Download URL response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final downloadUrl = data['downloadUrl'];
        safePrint('Got download URL successfully');
        return downloadUrl;
      } else {
        safePrint(
          'Failed to get download URL: ${response.statusCode} - ${response.body}',
        );
        return null;
      }
    } catch (e) {
      safePrint('Error getting download URL: $e');
      return null;
    }
  }
}
