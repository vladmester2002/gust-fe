import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:gust_fe/SugarLog.dart';
import 'package:gust_fe/SugarStatsPage.dart';
import 'package:http/http.dart' as http;
import 'package:gust_fe/Register.dart';
import 'package:gust_fe/forgot_password.dart';
import 'package:gust_fe/home_page.dart';

import 'SugarLogPage.dart';

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

final List<SugarLog> mockLogs = [
  SugarLog(
    id: 1,
    sugarGrams: 25,
    date: DateTime(2025, 5, 27),
    hour: 9,
    minute: 30,
    productName: "Chocolate croissant",
    sugarType: "Pastry",
    contextNote: "Breakfast on the go",
    emotion: Emotion.happy,
    location: "Bakery",
    wasCraving: true,
  ),
  SugarLog(
    id: 2,
    sugarGrams: 15,
    date: DateTime(2025, 5, 27),
    hour: 13,
    minute: 45,
    productName: "Soda",
    sugarType: "Drink",
    contextNote: "Lunch with friends",
    emotion: Emotion.sad,
    location: "Restaurant",
    wasCraving: false,
  ),
  SugarLog(
    id: 3,
    sugarGrams: 40,
    date: DateTime(2025, 5, 26),
    hour: 22,
    minute: 15,
    productName: "Ice cream",
    sugarType: "Dessert",
    contextNote: "Late night binge",
    emotion: Emotion.stressed,
    location: "Home",
    wasCraving: true,
  ),
  SugarLog(
    id: 4,
    sugarGrams: 10,
    date: DateTime(2025, 5, 26),
    hour: 16,
    minute: 5,
    productName: "Gummy bears",
    sugarType: "Candy",
    contextNote: "Afternoon slump",
    emotion: Emotion.tired,
    location: "Office",
    wasCraving: true,
  ),
  SugarLog(
    id: 5,
    sugarGrams: 30,
    date: DateTime(2025, 5, 25),
    hour: 20,
    minute: 0,
    productName: "Cake slice",
    sugarType: "Dessert",
    contextNote: "Celebrated a friend's birthday",
    emotion: Emotion.happy,
    location: "Friend's house",
    wasCraving: false,
  ),
  SugarLog(
    id: 6,
    sugarGrams: 8,
    date: DateTime(2025, 5, 25),
    hour: 11,
    minute: 20,
    productName: "Flavored yogurt",
    sugarType: "Dairy",
    contextNote: "Light snack",
    emotion: Emotion.bored,
    location: "Kitchen",
    wasCraving: false,
  ),
  SugarLog(
    id: 7,
    sugarGrams: 18,
    date: DateTime(2025, 5, 24),
    hour: 14,
    minute: 50,
    productName: "Sweet iced tea",
    sugarType: "Drink",
    contextNote: "Chilling after a walk",
    emotion: Emotion.neutral,
    location: "Park bench",
    wasCraving: false,
  ),
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
        AppRoutes.home: (context) => const HomePage(),
        AppRoutes.testPage: (context) => SugarLogPage(logs: mockLogs),
        AppRoutes.testStats: (context) => SugarStatsPage(logs: mockLogs),
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final url = Uri.parse('http://192.168.1.111:8080/api/auth/login');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'email': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // TODO: Save token securely using flutter_secure_storage or SharedPreferences

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );

        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (_) => false);
      } else {
        final message = jsonDecode(response.body)['message'] ?? 'Login failed';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $message')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }

  void _register() => Navigator.pushNamed(context, AppRoutes.register);
  void _forgotPassword() => Navigator.pushNamed(context, AppRoutes.forgotPassword);
  void _testUser() => Navigator.pushNamed(context, AppRoutes.testPage);
  void _testStats() => Navigator.pushNamed(context, AppRoutes.testStats);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('GUST Login'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'GUST',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!value.contains('@')) return 'Invalid email format';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.0)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 10.0),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your password';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                        ),
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _register,
                        child: Text('Create Account', style: TextStyle(color: theme.colorScheme.secondary)),
                      ),
                      TextButton(
                        onPressed: _forgotPassword,
                        child: Text('Forgot Password?', style: TextStyle(color: theme.colorScheme.outline)),
                      ), 
                      TextButton(
                        onPressed: _testUser,
                        child: Text('TEST USER', style: TextStyle(color: theme.colorScheme.outline)),
                      ),
                      TextButton(
                        onPressed: _testStats,
                        child: Text('TEST STATS', style: TextStyle(color: theme.colorScheme.outline)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
