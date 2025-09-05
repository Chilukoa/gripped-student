# Gripped Apps - AWS Cognito Authentication

This Flutter app implements AWS Cognito authentication with a complete user management system.

## Features

- User registration and email verification
- User sign-in and sign-out
- Password reset functionality
- Secure authentication flow using AWS Cognito
- Modern, beautiful UI design

## AWS Cognito Configuration

The app is configured with the following AWS Cognito settings:

- **User Pool ID**: `us-east-1_aUtqQtNcJ`
- **App Client ID**: `5or7m2e6ovvr8jmk9pj07j7pjj`
- **Region**: `us-east-1`
- **Callback URLs**: `com.gripped.app://auth-callback`
- **Sign-out URLs**: `com.gripped.app://auth-callback`

## Project Structure

```
lib/
├── main.dart                    # Main app entry point with authentication wrapper
├── services/
│   └── auth_service.dart        # AWS Cognito authentication service
└── screens/
    ├── login_screen.dart        # User login interface
    ├── signup_screen.dart       # User registration interface
    ├── verification_screen.dart # Email verification interface
    ├── forgot_password_screen.dart # Password reset request
    └── reset_password_screen.dart  # Password reset confirmation
```

## Dependencies

- `amplify_flutter`: Core Amplify library
- `amplify_auth_cognito`: Cognito authentication plugin
- `shared_preferences`: Local storage for session management
- `http`: HTTP client for API requests

## Getting Started

1. **Install dependencies**:
   ```bash
   flutter pub get
   ```

2. **Run the app**:
   ```bash
   flutter run
   ```

## Authentication Flow

1. **App Launch**: The app checks if Amplify is configured and if the user is authenticated
2. **Not Authenticated**: Shows login screen with options to sign up or reset password
3. **Sign Up**: User can create a new account, receive email verification, and confirm their email
4. **Sign In**: User can sign in with email and password
5. **Authenticated**: Shows the main app interface with sign-out option
6. **Password Reset**: User can request password reset via email

## Platform Configuration

### Android
- Package name: `com.gripped.app`
- Internet permissions added to AndroidManifest.xml
- Deep link configuration for auth callbacks

### iOS
- Bundle identifier should be set to `com.gripped.app`
- URL scheme configured for auth callbacks
- App Transport Security configured if needed

## Security Features

- Secure Remote Password (SRP) authentication
- Email verification required for new accounts
- Password policies enforced by Cognito
- Session management with secure tokens
- Deep link protection for auth callbacks

## Development Notes

- The app uses Material 3 design principles
- Error handling is implemented for all authentication flows
- Loading states provide user feedback during auth operations
- Form validation ensures data integrity
- Responsive design works on various screen sizes

## Testing

To test the authentication:

1. Run the app on a device or simulator
2. Try creating a new account (you'll receive a verification email)
3. Test signing in with valid credentials
4. Test password reset functionality
5. Test sign-out and automatic session management

## Troubleshooting

- Ensure your AWS Cognito user pool is properly configured
- Check that the app client settings match the configuration
- Verify that callback URLs are correctly set in Cognito
- Make sure internet permissions are granted on Android
- Check device logs for detailed error messages
