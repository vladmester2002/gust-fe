import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:another_flushbar/flushbar.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _showFlushBar({
    required String message,
    required Color color,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) async {
    await Flushbar<void>(
      message: message,
      duration: duration,
      backgroundColor: color,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: icon != null ? Icon(icon, color: Colors.white) : null,
    ).show(context);
  }

  Future<void> _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final url = Uri.parse('$baseUrl/api/auth/register');
      final headers = {'Content-Type': 'application/json'};
      final body = jsonEncode({
        'fullName': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text.trim(),
      });

      try {
        final response = await http.post(url, headers: headers, body: body);
        setState(() => _isLoading = false);

        if (response.statusCode == 200) {
          await _showFlushBar(
            message: 'Registration successful!',
            color: Colors.green,
            icon: Icons.check_circle,
          );
          Navigator.of(context).pop();
        } else if (response.statusCode == 400) {
          final message = _parseErrorMessage(response.body) ?? 'Bad request. Please check your input.';
          await _showFlushBar(
            message: 'Error: $message',
            color: Colors.red,
            icon: Icons.error,
          );
        } else if (response.statusCode == 409) {
          await _showFlushBar(
            message: 'Account already exists.',
            color: Colors.orange,
            icon: Icons.warning,
          );
        } else {
          final message = _parseErrorMessage(response.body) ?? 'Unexpected error (${response.statusCode}).';
          await _showFlushBar(
            message: 'Error: $message',
            color: Colors.red,
            icon: Icons.error,
          );
        }
      } catch (e) {
        setState(() => _isLoading = false);
        await _showFlushBar(
          message: 'Network error: $e',
          color: Colors.red,
          icon: Icons.error,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back button
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.all(AppTheme.spaceMD),
                ),
              ),
              Expanded(
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Title
                      Text(
                        'Create Account',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: AppTheme.primaryPurple,
                              fontSize: 32,
                            ),
                      ),
                      SizedBox(height: AppTheme.spaceSM),
                      Text(
                        'Join GUST to start tracking your sugar intake',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppTheme.spaceXL),
                      
                      // Username Field
                      GustTextField(
                        controller: _usernameController,
                        label: 'Full Name',
                        hint: 'Enter your full name',
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Email Field
                      GustTextField(
                        controller: _emailController,
                        label: 'Email',
                        hint: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Password Field
                      GustTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hint: 'Create a password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Confirm Password Field
                      GustTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        prefixIcon: Icons.lock_reset_outlined,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppTheme.spaceLG),
                      
                      // Register Button
                      GustButton(
                        text: 'Create Account',
                        onPressed: _register,
                        isLoading: _isLoading,
                        type: ButtonType.primary,
                        width: double.infinity,
                      ),
                      SizedBox(height: AppTheme.spaceMD),
                      
                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Text(
                              'Login',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ), // Row
                    ],
                  ), // Column
                ), // Form
              ), // Padding
            ), // Card
          ), // SingleChildScrollView
        ), // Center
      ), // Expanded
      ], // Column children
    ), // Column
    ), // SafeArea
    ), // Container
    ); // Scaffold body
  }
}
