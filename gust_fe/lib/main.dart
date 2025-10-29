import 'package:flutter/material.dart';
import 'package:gust_fe/Register.dart';
import 'package:gust_fe/forgot_password.dart';
import 'package:gust_fe/home_page.dart';
import 'package:gust_fe/analytics_page.dart';
import 'package:gust_fe/Login.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:gust_fe/sugar_log_creation_dialog.dart';
import 'package:gust_fe/main_navigation.dart';
import 'package:gust_fe/theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class AppRoutes {
  static const String login = '/';              // Login page is root "/"
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
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
      initialRoute: AppRoutes.login,        // This is "/"
      routes: {
        AppRoutes.login: (context) => const LoginPage(),              // "/" route: LoginPage
        AppRoutes.register: (context) => const RegisterPage(),        // "/register"
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(), // "/forgot-password"
        AppRoutes.mainNav: (context) => MainNavigation(logs: mockLogs),    // "/main-nav"
      },
    );
  }
}
