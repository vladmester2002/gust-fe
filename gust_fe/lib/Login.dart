import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final url = Uri.parse('$baseUrl/api/auth/login');
    final headers = {'Content-Type': 'application/json'};
    final body = jsonEncode({
      'email': _usernameController.text.trim(),
      'password': _passwordController.text.trim(),
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      setState(() => _isLoading = false);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Save token securely for further API use
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        Flushbar(
          message: 'Login successful!',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.green,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        ).show(context);

        Navigator.pushReplacementNamed(context, '/main-nav');
      } else {
        final message = _parseErrorMessage(response.body) ?? 'Login failed';
        Flushbar(
          message: 'Error: $message',
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.error, color: Colors.white),
        ).show(context);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      Flushbar(
        message: 'Network error: $e',
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.error, color: Colors.white),
      ).show(context);
    }
  }

  String? _parseErrorMessage(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  void _register() => Navigator.pushNamed(context, '/register');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
              child: Card(
                elevation: 12.0,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                ),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spaceXL),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                      // App Logo/Title
                      Container(
                        padding: EdgeInsets.all(AppTheme.spaceMD),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryPurple.withOpacity(0.1),
                        ),
                        child: Icon(
                          Icons.local_drink_outlined,
                          size: 64,
                          color: AppTheme.primaryPurple,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      Text(
                        'GUST',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.primaryPurple,
                              fontSize: 48,
                            ),
                      ),
                      SizedBox(height: AppTheme.spaceSM),
                      Text(
                        'Track your sugar, improve your health',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppTheme.spaceXL),
                      
                      // Email Field
                      GustTextField(
                        controller: _usernameController,
                        label: 'Email',
                        hint: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your email';
                          if (!value.contains('@')) return 'Invalid email format';
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Password Field
                      GustTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Enter your password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please enter your password';
                          if (value.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceLG),
                      
                      // Login Button
                      GustButton(
                        text: 'Login',
                        onPressed: _login,
                        isLoading: _isLoading,
                        type: ButtonType.primary,
                        width: double.infinity,
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Register Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          GestureDetector(
                            onTap: _register,
                            child: Text(
                              'Sign Up',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ), // Row
                    ], // Column children
                  ), // Column
                ), // Form
              ), // Padding
            ), // Card
          ), // SingleChildScrollView
        ), // Center
      ), // SafeArea
    ), // Container
    ); // Scaffold body
  }
}
