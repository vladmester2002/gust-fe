import 'package:flutter/material.dart';
import 'package:gust_fe/Register.dart';
import 'package:gust_fe/forgot_password.dart';
import 'package:gust_fe/home_page.dart';
import 'package:gust_fe/SugarLogPage.dart';
import 'package:gust_fe/SugarStatsPage.dart';
import 'package:gust_fe/Login.dart'; // Import Login page
import 'SugarLog.dart';

void main() {
  runApp(const MyApp());
}

class AppRoutes {
  static const String login = '/';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String home = '/home';
  static const String testPage = '/test-page';
  static const String testStats = '/test-stats';
}

// Mock logs for testing
final List<SugarLog> mockLogs = [
  // SugarLog(
  //   id: 1,
  //   sugarGrams: 25,
  //   date: DateTime(2025, 5, 27),
  //   hour: 9,
  //   minute: 30,
  //   productName: "Chocolate croissant",
  //   sugarType: "Pastry",
  //   contextNote: "Breakfast on the go",
  //   emotion: Emotion.happy,
  //   location: "Bakery",
  //   wasCraving: true,
  // ),
  // SugarLog(
  //   id: 2,
  //   sugarGrams: 15,
  //   date: DateTime(2025, 5, 27),
  //   hour: 13,
  //   minute: 45,
  //   productName: "Soda",
  //   sugarType: "Drink",
  //   contextNote: "Lunch with friends",
  //   emotion: Emotion.sad,
  //   location: "Restaurant",
  //   wasCraving: false,
  // ),
  // SugarLog(
  //   id: 3,
  //   sugarGrams: 40,
  //   date: DateTime(2025, 5, 26),
  //   hour: 22,
  //   minute: 15,
  //   productName: "Ice cream",
  //   sugarType: "Dessert",
  //   contextNote: "Late night binge",
  //   emotion: Emotion.stressed,
  //   location: "Home",
  //   wasCraving: true,
  // ),
  // SugarLog(
  //   id: 4,
  //   sugarGrams: 10,
  //   date: DateTime(2025, 5, 26),
  //   hour: 16,
  //   minute: 5,
  //   productName: "Gummy bears",
  //   sugarType: "Candy",
  //   contextNote: "Afternoon slump",
  //   emotion: Emotion.tired,
  //   location: "Office",
  //   wasCraving: true,
  // ),
  // SugarLog(
  //   id: 5,
  //   sugarGrams: 30,
  //   date: DateTime(2025, 5, 25),
  //   hour: 20,
  //   minute: 0,
  //   productName: "Cake slice",
  //   sugarType: "Dessert",
  //   contextNote: "Celebrated a friend's birthday",
  //   emotion: Emotion.happy,
  //   location: "Friend's house",
  //   wasCraving: false,
  // ),
  // SugarLog(
  //   id: 6,
  //   sugarGrams: 8,
  //   date: DateTime(2025, 5, 25),
  //   hour: 11,
  //   minute: 20,
  //   productName: "Flavored yogurt",
  //   sugarType: "Dairy",
  //   contextNote: "Light snack",
  //   emotion: Emotion.bored,
  //   location: "Kitchen",
  //   wasCraving: false,
  // ),
  // SugarLog(
  //   id: 7,
  //   sugarGrams: 18,
  //   date: DateTime(2025, 5, 24),
  //   hour: 14,
  //   minute: 50,
  //   productName: "Sweet iced tea",
  //   sugarType: "Drink",
  //   contextNote: "Chilling after a walk",
  //   emotion: Emotion.neutral,
  //   location: "Park bench",
  //   wasCraving: false,
  // ),
];

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
        AppRoutes.home: (context) => HomePage(logs: mockLogs),
        AppRoutes.testPage: (context) => SugarLogPage(logs: mockLogs),
        AppRoutes.testStats: (context) => SugarStatsPage(logs: mockLogs),
      },
    );
  }
}
