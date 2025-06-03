import 'package:flutter/material.dart';
import 'package:gust_fe/Register.dart';
import 'package:gust_fe/forgot_password.dart';
import 'package:gust_fe/Login.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:gust_fe/main_navigation.dart';

// Suggestion 1.3: Add a global error handler for crash reporting
void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Optionally: send details to a crash reporting service
    // print('Caught Flutter error: ${details.exception}');
  };
  runApp(const MyApp());
}

class AppRoutes {
  static const String login = '/'; // Login page is root "/"
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String mainNav = '/main-nav';
}

// Suggestion 1.2: Remove mockLogs, use empty list or fetch real data after login
final List<SugarLog> mockLogs = []; // Remove this when real data is used

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GUST App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialRoute: AppRoutes.login,
      routes: {
        AppRoutes.login: (context) => const LoginPage(),
        AppRoutes.register: (context) => const RegisterPage(),
        AppRoutes.forgotPassword: (context) => const ForgotPasswordPage(),
        // Suggestion 1.1: For now, still pass logs, but recommend Provider/Riverpod for real app state
        AppRoutes.mainNav: (context) => MainNavigation(logs: mockLogs),
      },
      navigatorObservers: [routeObserver],
    );
  }
}

// Suggestion 1.1: For scalable state management, consider using Provider, Riverpod, or Bloc
// Example: Wrap MyApp with a Provider for user/auth state and logs in the future.
