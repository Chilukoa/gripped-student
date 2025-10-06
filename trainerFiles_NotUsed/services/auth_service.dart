import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_secure_storage/amplify_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../amplifyconfiguration.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if Amplify is already configured
      if (Amplify.isConfigured) {
        _isInitialized = true;
        safePrint('Amplify is already configured');
        return;
      }

      // Add the Auth plugin with secure storage configuration
      await Amplify.addPlugin(
        AmplifyAuthCognito(
          secureStorageFactory: AmplifySecureStorage.factoryFrom(),
        ),
      );

      // Configure Amplify with the configuration
      await Amplify.configure(amplifyconfig);

      _isInitialized = true;
      safePrint('Amplify configured successfully');
    } on AmplifyAlreadyConfiguredException {
      // Amplify was already configured, just mark as initialized
      _isInitialized = true;
      safePrint('Amplify was already configured');
    } on AmplifyException catch (e) {
      safePrint('AmplifyException during initialization: ${e.message}');
      safePrint('Recovery suggestion: ${e.recoverySuggestion}');

      // Check for specific secure storage errors
      if (e.message.contains('SecureStorageInterface') ||
          e.message.contains('No builder registered')) {
        safePrint('Secure storage configuration issue detected');

        // Try to clear any corrupted storage and retry with fallback
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          safePrint('Cleared SharedPreferences for fresh start');
        } catch (clearError) {
          safePrint('Error clearing SharedPreferences: $clearError');
        }
      }

      rethrow;
    } catch (e) {
      safePrint('Error configuring Amplify: $e');
      rethrow;
    }
  }

  Future<bool> isSignedIn() async {
    try {
      if (!_isInitialized) {
        safePrint('Amplify not initialized, cannot check auth status');
        return false;
      }

      final result = await Amplify.Auth.fetchAuthSession();
      return result.isSignedIn;
    } on AmplifyException catch (e) {
      safePrint('AmplifyException checking sign-in status: ${e.message}');
      return false;
    } catch (e) {
      safePrint('Error checking sign-in status: $e');
      return false;
    }
  }

  Future<String?> getCurrentUserId() async {
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  Future<AuthUser?> getCurrentUser() async {
    try {
      return await Amplify.Auth.getCurrentUser();
    } catch (e) {
      safePrint('Error getting current user: $e');
      return null;
    }
  }

  Future<SignUpResult> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final userAttributes = <AuthUserAttributeKey, String>{
        AuthUserAttributeKey.email: email,
        if (fullName != null) AuthUserAttributeKey.name: fullName,
      };

      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );

      return result;
    } catch (e) {
      safePrint('Error signing up: $e');
      rethrow;
    }
  }

  Future<SignUpResult> confirmSignUp({
    required String email,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );
      return result;
    } catch (e) {
      safePrint('Error confirming sign-up: $e');
      rethrow;
    }
  }

  Future<SignInResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      safePrint('Attempting sign in for user: $email');
      safePrint('Amplify configured: ${Amplify.isConfigured}');

      final result = await Amplify.Auth.signIn(
        username: email,
        password: password,
      );

      safePrint('Sign in result: ${result.isSignedIn}');
      safePrint('Next step: ${result.nextStep}');

      if (result.isSignedIn) {
        await _saveUserSession();
        safePrint('User session saved successfully');
      }

      return result;
    } catch (e) {
      safePrint('Error signing in: $e');
      safePrint('Error type: ${e.runtimeType}');
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await Amplify.Auth.signOut();
      await _clearUserSession();
    } catch (e) {
      safePrint('Error signing out: $e');
      rethrow;
    }
  }

  Future<ResetPasswordResult> resetPassword({required String email}) async {
    try {
      final result = await Amplify.Auth.resetPassword(username: email);
      return result;
    } catch (e) {
      safePrint('Error resetting password: $e');
      rethrow;
    }
  }

  Future<ResetPasswordResult> confirmResetPassword({
    required String email,
    required String newPassword,
    required String confirmationCode,
  }) async {
    try {
      final result = await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      return result;
    } catch (e) {
      safePrint('Error confirming password reset: $e');
      rethrow;
    }
  }

  Future<void> _saveUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
    } catch (e) {
      safePrint('Error saving user session: $e');
    }
  }

  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('isLoggedIn');
    } catch (e) {
      safePrint('Error clearing user session: $e');
    }
  }

  Future<bool> isLoggedInLocally() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('isLoggedIn') ?? false;
    } catch (e) {
      safePrint('Error checking local login status: $e');
      return false;
    }
  }

  /// Force sign out and clear all local session data
  /// Useful for debugging or when switching between accounts
  Future<void> forceSignOut() async {
    try {
      // Sign out from Amplify
      await Amplify.Auth.signOut();

      // Clear local session
      await _clearUserSession();

      // Clear shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      safePrint('Force sign out completed');
    } catch (e) {
      safePrint('Error during force sign out: $e');
      // Even if Amplify sign out fails, clear local data
      try {
        await _clearUserSession();
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
      } catch (clearError) {
        safePrint('Error clearing local data: $clearError');
      }
    }
  }
}
