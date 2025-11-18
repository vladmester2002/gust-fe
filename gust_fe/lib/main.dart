import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'login.dart';
import 'sugar_log.dart';
import 'main_navigation.dart';
import 'onboarding_page.dart';
import 'theme/app_theme.dart';
import 'data/local/gust_database.dart';
import 'package:provider/provider.dart';
import 'state/auth_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    if (authState.isLoading) {
      return const _SplashScreen();
    }
    if (authState.isAuthenticated) {
      return MainNavigation(logs: mockLogs, initialIndex: 0);
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
