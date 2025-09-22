# Gripped Apps - AI Coding Agent Instructions

## Project Overview
Flutter fitness trainer app with AWS Cognito authentication, REST API backend, and multi-environment support. Supports both trainer and student workflows with shared auth/profile setup.

## Architecture & Key Components

### Authentication Flow
- **Entry Point**: `main.dart` → `AuthWrapper` checks Amplify config + auth status + profile existence
- **Navigation Logic**: Unauthenticated → `LoginScreen` → Profile missing → `ProfileSetupScreen` → `TrainerDashboardScreen`
- **Service Pattern**: Singleton services (`AuthService`, `UserService`, `ClassService`) with proper error handling
- **AWS Integration**: Amplify configured in `amplifyconfiguration.dart`, tokens managed via `CognitoAuthSession`

### API Architecture
- **Environment Config**: `lib/config/api_config.dart` with prod/test/dev URLs via `Environment` enum
- **Auth Headers**: All API calls require `Authorization: Bearer {idToken}` from Cognito session
- **Endpoints**: RESTful pattern - `/profile/me`, `/trainers/me/classes`, `/classes/{id}`
- **Image Upload**: Presigned S3 URLs via `/profile/presigned-url` endpoint

### Data Models
- **UserProfile**: Role-based model supporting both trainer/student with conditional fields
- **TrainingClass**: Complete class management with participants, pricing, scheduling
- **JSON Mapping**: Custom `fromJson`/`toJson` with null safety and backend format compatibility

## Development Patterns

### Error Handling
```dart
try {
  final result = await service.method();
  // Handle success
} on AuthException catch (e) {
  // Amplify-specific errors
} catch (e) {
  // Generic error handling with user feedback
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
  );
}
```

### Screen Structure
- **Responsive Design**: Use `MediaQuery` for `screenWidth * 0.04` spacing patterns
- **Loading States**: `_isLoading` boolean with `CircularProgressIndicator`
- **Form Validation**: `GlobalKey<FormState>` with custom validators
- **Navigation**: `pushReplacement` for auth flows, `pushAndRemoveUntil` for sign out

### State Management
- **StatefulWidget** pattern with lifecycle management
- **Controller Disposal**: Always dispose TextEditingControllers and ScrollControllers
- **Mounted Checks**: Wrap setState calls with `if (mounted)` checks

## Environment & Build Configuration

### Multi-Environment Setup
- **Trainer Prod**: `com.example.grippedapps` (production API)
- **Trainer Beta**: `com.grippedapps.beta` (test API) 
- **Trainer Student**: `com.grippedstudent.alpha` 
- **Trainer Student beta**: `com.grippedstudent.beta`
- **API Switching**: Change `_environment` in `api_config.dart`

### Bundle ID Updates
When creating new environments, update:
1. `android/app/build.gradle.kts` - `applicationId`
2. iOS bundle identifier in Xcode project
3. Deep link schemes in platform configs

## Testing & Debugging

### E2E Testing
- Python scripts in `int_tests/` for API validation
- AWS SDK integration for Cognito user management
- Base64 image generation for upload testing

### Common Commands
```bash
flutter pub get                    # Install dependencies
flutter run                       # Run app (debug mode)
flutter run --release            # Release build
flutter clean && flutter pub get # Clean rebuild
```

### Debugging Tips
- **Amplify Issues**: Check `safePrint` logs for initialization errors
- **API Errors**: Enable request/response logging in services
- **Token Issues**: Verify `CognitoAuthSession` token extraction
- **Navigation**: Use named routes with `pushNamedAndRemoveUntil('/', (route) => false)`

## Key Files to Understand
- `lib/main.dart` - App initialization and auth wrapper logic
- `lib/services/auth_service.dart` - Amplify configuration and auth methods
- `lib/config/api_config.dart` - Environment management and API endpoints
- `lib/models/user_profile.dart` - Data model with backend compatibility
- `lib/screens/profile_setup_screen.dart` - Complex form with image upload

## Code Style
- Material 3 design with `Colors.deepPurple` theme
- Responsive sizing using `MediaQuery` multipliers
- Consistent error messaging with `SnackBar`
- Null safety throughout with explicit null checks
- Service singletons with factory constructors
