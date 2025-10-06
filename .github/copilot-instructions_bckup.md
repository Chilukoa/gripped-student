# Gripped Apps - AI Coding Agent Instructions

## IMPORTANT:
These instructions are for GitHub Copilot to help generate code for the Gripped Apps Flutter project. These are copied over from cd ~/grippedapps. The grippedapps and gripped_student projects are identical except for bundle IDs and API endpoints. Do not copy changes between trainer and student projects for classes.


## Project Overview
Flutter fitness app with AWS Cognito authentication, REST API backend, and multi-environment support. Supports both trainer and student workflows with shared auth/profile setup across 4 project variants: trainer prod/beta and student alpha/beta.

## Architecture & Key Components

### Authentication Flow
- **Entry Point**: `main.dart` → `AuthWrapper` checks Amplify config + auth status + profile existence
- **Navigation Logic**: Unauthenticated → `LoginScreen` → Profile missing → `ProfileSetupScreen` → `TrainerDashboardScreen`
- **Service Pattern**: Singleton services (`AuthService`, `UserService`, `ClassService`) with proper error handling
- **AWS Integration**: Amplify configured in `amplifyconfiguration.dart`, tokens managed via `CognitoAuthSession`

### API Architecture
- **Environment Config**: `lib/config/api_config.dart` with prod/test/dev URLs via `Environment` enum
- **Auth Headers**: All API calls require `Authorization: Bearer {idToken}` from Cognito session
- **Endpoints**: RESTful pattern - `/profile/me`, `/trainers/me/classes`, `/classes/{id}`, `/classes/{sessionId}/messages`, `/classes/{sessionId}/enroll`
- **Image Upload**: Presigned S3 URLs via `/profile/presigned-url` endpoint

### Data Models
- **UserProfile**: Role-based model supporting both trainer/student with conditional fields
- **TrainingClass**: Complete class management with participants, pricing, scheduling
- **ClassCreationRequest/Response**: Separate models for API payloads with session creation
- **JSON Mapping**: Custom `fromJson`/`toJson` with null safety and backend format compatibility
- **Field Naming**: Backend uses `classOverview` vs `overview`, `classPrice` vs `pricePerClass` - ensure proper mapping

### Class Management System
- **CRUD Operations**: Full lifecycle - create, read, update, cancel classes with proper status management
- **Session-Based**: Classes contain multiple sessions with independent enrollment/cancellation
- **Messaging**: Trainers can broadcast messages to all enrolled students via `/classes/{sessionId}/messages`
- **Enrollment**: Students enroll/unenroll with status tracking (ACTIVE/CANCELLED), not hard deletion
- **Status Management**: Classes/enrollments marked as CANCELLED rather than deleted for audit trail

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
- **Multi-Step Forms**: Use `PageController` for class creation/editing with progress indicators
- **Card-Based Layout**: Group related fields in `Card` widgets with consistent padding

### State Management
- **StatefulWidget** pattern with lifecycle management
- **Controller Disposal**: Always dispose TextEditingControllers and ScrollControllers
- **Mounted Checks**: Wrap setState calls with `if (mounted)` checks
- **Loading States**: Separate boolean flags for different operations (`_isLoading`, `_isSendingMessage`)

### Service Integration
- **updateClassWithPayload**: Use specific payload updates rather than full model updates
- **Payload Construction**: Only include updatable fields in API payloads
- **Response Handling**: Parse API responses with proper error status checking (200/201 success, others throw exceptions)

## Environment & Build Configuration

### Multi-Environment Setup
- **Trainer Prod**: `grippedapps/` → `com.example.grippedapps` (production API)
- **Trainer Beta**: `grippedapps_beta/` → `com.grippedapp.beta` (test API) 
- **Student Alpha**: `gripped_student/` → `com.grippedstudent.alpha` (production API)
- **Student Beta**: `gripped_student_beta/` → `com.grippedstudent.beta` (test API)
- **API Switching**: Change `_environment` in `api_config.dart`

### Project Structure
- **Shared Codebase**: Auth, profile setup, and core services identical across all variants
- **Role Differentiation**: `UserProfile.role` determines trainer vs student workflows  
- **Navigation**: Trainer → `TrainerDashboardScreen`, Student → `StudentDashboardScreen` (TBD)

### Bundle ID Updates
When creating new environments, update:
1. `android/app/build.gradle.kts` - `applicationId` and `namespace`
2. iOS `Runner.xcodeproj/project.pbxproj` - `PRODUCT_BUNDLE_IDENTIFIER`
3. `pubspec.yaml` - `name` and `description`
4. Deep link schemes in platform configs

### Environment Synchronization
Student projects are complete copies of trainer codebases:
- `grippedapps` → `gripped_student` (same auth/profile flows)
- `grippedapps_beta` → `gripped_student_beta` (same auth/profile flows)
- Future differentiation will be in dashboard screens and user role logic
- Do not copy changes between trainer and student projects for classes.

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
- **File System Issues**: If class definitions aren't recognized despite proper imports, try alternate filenames (e.g., `edit_training_class_screen.dart` vs `edit_class_screen.dart`)
- **Import Resolution**: Flutter analyzer can cache stale import paths; clean rebuild resolves most import issues
- **Field Mapping**: Verify backend API field names match model field names (common mismatches: `overview`/`classOverview`, `pricePerClass`/`classPrice`)

## Key Files to Understand
- `lib/main.dart` - App initialization and auth wrapper logic
- `lib/services/auth_service.dart` - Amplify configuration and auth methods
- `lib/services/class_service.dart` - Class CRUD operations, messaging, enrollment management
- `lib/config/api_config.dart` - Environment management and API endpoints
- `lib/models/user_profile.dart` - Data model with backend compatibility
- `lib/models/training_class.dart` - Complete class model with session management
- `lib/models/class_creation.dart` - API request/response models for class creation
- `lib/screens/profile_setup_screen.dart` - Complex form with image upload
- `lib/screens/trainer_dashboard_screen.dart` - Main trainer interface with class management
- `lib/screens/class_detail_screen.dart` - Full class management (edit, cancel, messaging)
- `lib/screens/edit_training_class_screen.dart` - Class editing form with address validation
- `lib/screens/create_class_screen.dart` - Multi-step class creation with session scheduling

## Code Style
- Material 3 design with `Colors.deepPurple` theme
- Responsive sizing using `MediaQuery` multipliers
- Consistent error messaging with `SnackBar`
- Null safety throughout with explicit null checks
- Service singletons with factory constructors
