import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'reset_password.dart';
import 'login.dart';
import 'sugar_log.dart';
import 'main_navigation.dart';
import 'onboarding_page.dart';
import 'theme/app_theme.dart';
import 'data/local/gust_database.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    await GustDatabase.instance.database;
  }
  final authState = AuthState();
  await authState.hydrate();
  runApp(
    ChangeNotifierProvider<AuthState>.value(
      value: authState,
      child: const MyApp(),
    ),
  );
}

class AppRoutes {
  static const String login = '/';              // Login page is root "/"
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String onboarding = '/onboarding';
  static const String mainNav = '/main-nav';
}

class MainNavArguments {
  const MainNavArguments({this.initialIndex = 0});
  final int initialIndex;
}

// Mock logs for demo/testing (replace with your backend fetching logic)
final List<SugarLog> mockLogs = [
  // SugarLog(...), // Add example logs here if needed
];

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUST App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AuthGate(),
      routes: {
        AppRoutes.register: (context) => const RegisterPage(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
        AppRoutes.resetPassword: (context) => const ResetPasswordPage(),
        AppRoutes.onboarding: (context) => const OnboardingPage(),
        AppRoutes.mainNav: (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          final initialIndex =
              args is MainNavArguments ? args.initialIndex : 0;
          return MainNavigation(
            logs: mockLogs,
            initialIndex: initialIndex,
          );
        },
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    
    if (kDebugMode) {
      print('=== AUTH GATE DEBUG ===');
      print('isLoading: ${authState.isLoading}');
      print('currentUser: ${authState.currentUser?.email}');
      print('isAuthenticated: ${authState.isAuthenticated}');
      print('Will show: ${authState.isLoading ? "SplashScreen" : (authState.currentUser != null && !authState.isAuthenticated) ? "AppLockScreen" : authState.isAuthenticated ? "MainNavigation" : "LoginPage"}');
      print('=====================');
    }
    
    if (authState.isLoading) {
      return const _SplashScreen();
    }
    
    // Check if user is locked (has session but requires biometric)
    if (authState.currentUser != null && !authState.isAuthenticated) {
      if (kDebugMode) {
        print('Showing AppLockScreen');
      }
      return const _AppLockScreen();
    }
    
    if (authState.isAuthenticated) {
      if (kDebugMode) {
        print('Showing MainNavigation');
      }
      return MainNavigation(logs: mockLogs, initialIndex: 0);
    }
    
    if (kDebugMode) {
      print('Showing LoginPage');
    }
    return const LoginPage();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _AppLockScreen extends StatefulWidget {
  const _AppLockScreen();

  @override
  State<_AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<_AppLockScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger biometric auth immediately when lock screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _unlockWithBiometric();
    });
  }

  Future<void> _unlockWithBiometric() async {
    final authState = context.read<AuthState>();
    final success = await authState.loginWithBiometrics();
    
    if (!success && mounted) {
      // If biometric fails, show option to use password or logout
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Authentication Failed'),
          content: const Text('Biometric authentication failed. Please try again or logout.'),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await authState.signOut();
              },
              child: const Text('Logout'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _unlockWithBiometric();
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'App Locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Welcome back, ${authState.currentUser?.fullName ?? "User"}',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Waiting for biometric authentication...'),
          ],
        ),
      ),
    );
  }
}
