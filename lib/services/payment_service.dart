import 'dart:convert';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart' as app_config;

class PaymentService {
  // Cache for payment method status
  static bool? _cachedHasPaymentMethod;
  static Map<String, dynamic>? _cachedPaymentMethodDetails;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(hours: 6);

  /// Checks if the cache is still valid (not expired)
  bool _isCacheValid() {
    if (_cacheTimestamp == null) return false;
    final elapsed = DateTime.now().difference(_cacheTimestamp!);
    return elapsed < _cacheDuration;
  }

  /// Clears the payment method cache (call this after adding/removing payment method)
  void clearCache() {
    safePrint('PaymentService: Clearing payment method cache');
    _cachedHasPaymentMethod = null;
    _cachedPaymentMethodDetails = null;
    _cacheTimestamp = null;
  }

  /// Static method to clear cache from anywhere
  static void invalidateCache() {
    safePrint('PaymentService: Invalidating payment method cache (static)');
    _cachedHasPaymentMethod = null;
    _cachedPaymentMethodDetails = null;
    _cacheTimestamp = null;
  }

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
        final result = json.decode(response.body) as Map<String, dynamic>;
        
        // Clear cache after adding payment method (will be refreshed on next check)
        clearCache();
        
        // Update cache with new payment method status
        _cachedHasPaymentMethod = true;
        _cacheTimestamp = DateTime.now();
        
        return result;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to confirm setup intent');
      }
    } catch (e) {
      safePrint('PaymentService: Error confirming setup intent: $e');
      rethrow;
    }
  }

  /// Gets the student's saved payment method (with caching)
  /// Set [forceRefresh] to true to bypass the cache
  Future<Map<String, dynamic>> getPaymentMethod({bool forceRefresh = false}) async {
    // Check cache first (unless force refresh requested)
    if (!forceRefresh && _isCacheValid() && _cachedPaymentMethodDetails != null) {
      safePrint('PaymentService: Returning cached payment method (cache age: ${DateTime.now().difference(_cacheTimestamp!).inMinutes} minutes)');
      return _cachedPaymentMethodDetails!;
    }

    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('${app_config.ApiConfig.baseUrl}/stripe/student-payments/payment-method'),
        headers: headers,
      );

      safePrint('PaymentService: GetPaymentMethod response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body) as Map<String, dynamic>;
        
        // Update cache
        _cachedPaymentMethodDetails = result;
        _cachedHasPaymentMethod = result['hasPaymentMethod'] == true;
        _cacheTimestamp = DateTime.now();
        safePrint('PaymentService: Payment method cached (hasPaymentMethod: $_cachedHasPaymentMethod)');
        
        return result;
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to get payment method');
      }
    } catch (e) {
      safePrint('PaymentService: Error getting payment method: $e');
      rethrow;
    }
  }

  /// Checks if student has a valid payment method on file (with caching)
  /// Set [forceRefresh] to true to bypass the cache
  Future<bool> hasPaymentMethod({bool forceRefresh = false}) async {
    // Check cache first (unless force refresh requested)
    if (!forceRefresh && _isCacheValid() && _cachedHasPaymentMethod != null) {
      safePrint('PaymentService: Returning cached hasPaymentMethod: $_cachedHasPaymentMethod (cache age: ${DateTime.now().difference(_cacheTimestamp!).inMinutes} minutes)');
      return _cachedHasPaymentMethod!;
    }

    try {
      final result = await getPaymentMethod(forceRefresh: forceRefresh);
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

      if (response.statusCode == 200) {
        // Clear cache after successful deletion
        clearCache();
      } else {
        final errorBody = json.decode(response.body);
        throw Exception(errorBody['error'] ?? 'Failed to delete payment method');
      }
    } catch (e) {
      safePrint('PaymentService: Error deleting payment method: $e');
      rethrow;
    }
  }
}
