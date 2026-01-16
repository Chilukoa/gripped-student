import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart' as app_config;

class PaymentService {
  Future<Map<String, String>> _getAuthHeaders() async {
    try {
      final session = await Amplify.Auth.fetchAuthSession();
      if (session is CognitoAuthSession) {
        final idToken = session.userPoolTokensResult.value.idToken.raw;
        return {
          'Content-Type': 'application/json',
          'Authorization': idToken,
        };
      }
    } catch (e) {
      safePrint('PaymentService: Error getting auth headers: $e');
    }
    return {'Content-Type': 'application/json'};
  }

  /// Creates a SetupIntent for capturing student's payment method
  Future<Map<String, dynamic>> createSetupIntent() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('${app_config.ApiConfig.baseUrl}/stripe/student-payments/setup-intent'),
        headers: headers,
      );

      safePrint('PaymentService: CreateSetupIntent response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to create setup intent');
      }
    } catch (e) {
      safePrint('PaymentService: Error creating setup intent: $e');
      rethrow;
    }
  }

  /// Confirms the SetupIntent after payment method collection
  Future<Map<String, dynamic>> confirmSetupIntent({
    required String setupIntentId,
    String? paymentMethodId,
  }) async {
    try {
      final headers = await _getAuthHeaders();
      final body = {
        'setupIntentId': setupIntentId,
        if (paymentMethodId != null) 'paymentMethodId': paymentMethodId,
      };

      final response = await http.post(
        Uri.parse('${app_config.ApiConfig.baseUrl}/stripe/student-payments/confirm-setup'),
        headers: headers,
        body: json.encode(body),
      );

      safePrint('PaymentService: ConfirmSetupIntent response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to confirm setup intent');
      }
    } catch (e) {
      safePrint('PaymentService: Error confirming setup intent: $e');
      rethrow;
    }
  }

  /// Gets the student's saved payment method
  Future<Map<String, dynamic>> getPaymentMethod() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${app_config.ApiConfig.baseUrl}/stripe/student-payments/payment-method'),
        headers: headers,
      );

      safePrint('PaymentService: GetPaymentMethod response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get payment method');
      }
    } catch (e) {
      safePrint('PaymentService: Error getting payment method: $e');
      rethrow;
    }
  }

  /// Checks if student has a valid payment method on file
  Future<bool> hasPaymentMethod() async {
    try {
      final result = await getPaymentMethod();
      return result['hasPaymentMethod'] == true;
    } catch (e) {
      safePrint('PaymentService: Error checking payment method: $e');
      return false;
    }
  }

  /// Deletes the student's saved payment method
  Future<void> deletePaymentMethod() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('${app_config.ApiConfig.baseUrl}/stripe/student-payments/payment-method'),
        headers: headers,
      );

      safePrint('PaymentService: DeletePaymentMethod response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete payment method');
      }
    } catch (e) {
      safePrint('PaymentService: Error deleting payment method: $e');
      rethrow;
    }
  }
}
