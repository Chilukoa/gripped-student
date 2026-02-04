import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import '../config/api_config.dart' as app_config;

class SupportTicket {
  final String ticketId;
  final String userId;
  final String issueType;
  final String subject;
  final String message;
  final String priority;
  final String status;
  final String? adminResponse;
  final String createdAt;
  final String updatedAt;
  final String? resolvedAt;

  SupportTicket({
    required this.ticketId,
    required this.userId,
    required this.issueType,
    required this.subject,
    required this.message,
    required this.priority,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      ticketId: json['ticketId'] ?? '',
      userId: json['userId'] ?? '',
      issueType: json['issueType'] ?? '',
      subject: json['subject'] ?? '',
      message: json['message'] ?? '',
      priority: json['priority'] ?? 'MEDIUM',
      status: json['status'] ?? 'OPEN',
      adminResponse: json['adminResponse'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      resolvedAt: json['resolvedAt'],
    );
  }
}

class SupportService {
  static final SupportService _instance = SupportService._internal();
  factory SupportService() => _instance;
  SupportService._internal();

  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final token = session.userPoolTokensResult.value.idToken.raw;

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

  /// Create a new support ticket
  Future<SupportTicket> createSupportTicket({
    required String issueType,
    required String subject,
    required String message,
    String priority = 'MEDIUM',
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'issueType': issueType,
        'subject': subject,
        'message': message,
        'priority': priority,
      });

      final response = await http.post(
        Uri.parse(app_config.ApiConfig.createSupportTicket),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        return SupportTicket.fromJson(data);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create support ticket');
      }
    } catch (e) {
      safePrint('Error creating support ticket: $e');
      rethrow;
    }
  }

  /// Get all support tickets for the current user
  Future<List<SupportTicket>> getSupportTickets() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse(app_config.ApiConfig.getSupportTickets),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> ticketsJson = data['tickets'] ?? [];
        return ticketsJson.map((json) => SupportTicket.fromJson(json)).toList();
      } else {
        throw Exception('Failed to get support tickets: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error getting support tickets: $e');
      rethrow;
    }
  }

  /// Get a specific support ticket
  Future<SupportTicket> getSupportTicket(String ticketId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await http.get(
        Uri.parse('${app_config.ApiConfig.getSupportTicket}/$ticketId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SupportTicket.fromJson(data);
      } else {
        throw Exception('Failed to get support ticket: ${response.statusCode}');
      }
    } catch (e) {
      safePrint('Error getting support ticket: $e');
      rethrow;
    }
  }

  /// Update a support ticket (add additional info)
  Future<SupportTicket> updateSupportTicket({
    required String ticketId,
    required String additionalMessage,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = json.encode({
        'message': additionalMessage,
      });

      final response = await http.put(
        Uri.parse('${app_config.ApiConfig.updateSupportTicket}/$ticketId'),
        headers: headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return SupportTicket.fromJson(data);
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to update support ticket');
      }
    } catch (e) {
      safePrint('Error updating support ticket: $e');
      rethrow;
    }
  }
}
