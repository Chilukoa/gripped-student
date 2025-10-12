import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/student_dashboard_screen.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_profile.dart' as models;

// App configuration - defines what role this app is designed for
const String EXPECTED_USER_ROLE =
    'subscriber'; // This app is designed for subscribers only

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isAmplifyConfigured = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    try {
      // Add timeout to prevent infinite loading
      await AuthService().initialize().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Amplify initialization timed out after 30 seconds');
        },
      );

      if (mounted) {
        setState(() {
          _isAmplifyConfigured = true;
        });
      }
    } catch (e) {
      safePrint('Failed to configure Amplify: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gripped Student',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _error != null
          ? ErrorScreen(error: _error!)
          : _isAmplifyConfigured
          ? const AuthWrapper()
          : const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isSignedIn = false;
  bool _isLoading = true;
  bool _hasProfile = false;
  models.UserProfile? _userProfile;
  String? _roleError; // Add role validation error state

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      // Add timeout to prevent infinite loading
      final isSignedIn = await AuthService().isSignedIn().timeout(
        const Duration(seconds: 10),
      );

      safePrint('Auth status check - isSignedIn: $isSignedIn');

      if (isSignedIn) {
        safePrint('User is signed in, checking profile...');
        // Check if user has completed profile setup
        try {
          final userService = UserService();
          final profile = await userService.getUserProfile();
          safePrint('Retrieved profile: ${profile?.toJson()}');
          
          // Role validation - check if user role matches expected role for this app
          if (profile != null && profile.role != EXPECTED_USER_ROLE) {
            safePrint(
              'ROLE VALIDATION FAILED: User role is ${profile.role}, but app expects $EXPECTED_USER_ROLE',
            );
            setState(() {
              _roleError =
                  'This email is registered as ${profile.role} and can not be signed into student app. Please signup with different email to register as subscriber';
              _isLoading = false;
            });
            safePrint('ROLE ERROR SET: _roleError = $_roleError');
            return;
          }
          
          final hasCompleteProfile =
              profile != null && profile.isProfileComplete;

          safePrint('Profile check - profile exists: ${profile != null}');
          safePrint('Profile check - role: ${profile?.role}');
          safePrint(
            'Profile check - isComplete: ${profile?.isProfileComplete}',
          );
          safePrint('Profile check - hasProfile: $hasCompleteProfile');

          if (mounted) {
            setState(() {
              _roleError = null; // Clear any previous role error
              _isSignedIn = true;
              _hasProfile = hasCompleteProfile;
              _userProfile = profile;
              _isLoading = false;
            });
          }
        } catch (e) {
          safePrint('Error checking profile: $e');
          // If profile check fails, assume no profile and go to setup
          if (mounted) {
            setState(() {
              _isSignedIn = true;
              _hasProfile = false;
              _isLoading = false;
            });
          }
        }
      } else {
        safePrint('User is not signed in');
        if (mounted) {
          setState(() {
            _isSignedIn = false;
            _hasProfile = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      safePrint('Error checking auth status: $e');
      if (mounted) {
        setState(() {
          _isSignedIn = false;
          _hasProfile = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    safePrint(
      'BUILD METHOD - _isLoading: $_isLoading, _isSignedIn: $_isSignedIn, _hasProfile: $_hasProfile, _roleError: $_roleError',
    );
    
    if (_isLoading) {
      return const SplashScreen();
    }

    // Check for role error first - this takes precedence over other states
    if (_roleError != null) {
      safePrint('SHOWING ROLE ERROR SCREEN with message: $_roleError');
      return RoleErrorScreen(errorMessage: _roleError!);
    }

    if (!_isSignedIn) {
      return const LoginScreen();
    }

    if (!_hasProfile) {
      return const ProfileSetupScreen();
    }

    // Navigate to appropriate dashboard - should only be subscriber at this point
    safePrint('User profile: ${_userProfile?.toJson()}');
    safePrint('User role: ${_userProfile?.role}');
    safePrint('Role toLowerCase: ${_userProfile?.role.toLowerCase()}');

    // Since we validated role earlier, this should always be subscriber
    safePrint('Navigating to StudentDashboardScreen');
    return const StudentDashboardScreen();
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurple,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.8 + (_animation.value * 0.2),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 100,
                    color: Colors.white,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Gripped Apps',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 16),
            const Text(
              'Initializing...',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    final bool isSecureStorageError =
        error.contains('SecureStorageInterface') ||
        error.contains('builder identifier') ||
        error.contains('bundle identifier');

    return Scaffold(
      backgroundColor: Colors.red.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red.shade400),
              const SizedBox(height: 24),
              Text(
                'Configuration Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isSecureStorageError) ...[
                Text(
                  'Failed to initialize authentication: ${error.contains('SecureStorageInterface') ? 'Secure storage configuration issue' : 'Bundle identifier changed'}',
                  style: TextStyle(fontSize: 16, color: Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'This usually happens when:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Bundle identifier was changed\n• App was reinstalled\n• iOS keychain entries are corrupted',
                        style: TextStyle(color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      // Clear app data and restart
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.clear();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'App data cleared. Please restart the app.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error clearing data: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Clear App Data'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    error,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  // Restart the app
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const MyApp()),
                  );
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _signOut() async {
    try {
      await AuthService().signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class RoleErrorScreen extends StatelessWidget {
  final String errorMessage;

  const RoleErrorScreen({super.key, required this.errorMessage});

  Future<void> _signOut(BuildContext context) async {
    try {
      await AuthService().signOut();
      if (context.mounted) {
        // Navigate directly to login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _signOut(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Sign Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
