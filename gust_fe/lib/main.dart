import 'package:flutter/material.dart';
import 'register.dart';
import 'forgot_password.dart';
import 'login.dart';
import 'sugar_log.dart';
import 'main_navigation.dart';
import 'onboarding_page.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class AppRoutes {
  static const String login = '/';              // Login page is root "/"
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String mainNav = '/main-nav';
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
      initialRoute: AppRoutes.login, // This is "/"
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.register: (context) => const RegisterPage(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
        AppRoutes.onboarding: (context) => const OnboardingPage(),
        AppRoutes.mainNav: (context) => MainNavigation(logs: mockLogs),
      },
    );
  }
}
