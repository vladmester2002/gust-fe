import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 5.1

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

  // 5.3: Show/hide password toggle
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // 5.2: Password strength
  double _passwordStrength = 0;
  String _passwordStrengthLabel = '';

  void _checkPasswordStrength(String password) {
    double strength = 0;
    if (password.length >= 6) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;

    String label;
    if (strength == 0) {
      label = '';
    } else if (strength <= 0.25) {
      label = 'Weak';
    } else if (strength <= 0.5) {
      label = 'Fair';
    } else if (strength <= 0.75) {
      label = 'Good';
    } else {
      label = 'Strong';
    }

    setState(() {
      _passwordStrength = strength;
      _passwordStrengthLabel = label;
    });
  }

  Future<void> _showFlushBar({
    required String message,
    required Color color,
    IconData? icon,
    Duration duration = const Duration(seconds: 2),
  }) async {
    if (Theme.of(context).platform == TargetPlatform.linux ||
        Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS) {
      // Folosește dialog pe desktop și așteaptă să fie închis
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: color,
          content: Row(
            children: [
              if (icon != null) Icon(icon, color: Colors.white),
              if (icon != null) const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
        ),
      );
      // Dialogul se va închide după delay-ul de mai jos
    } else {
      // SnackBar pe mobil/web
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) Icon(icon, color: Colors.white),
              if (icon != null) const SizedBox(width: 8),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: color,
          duration: duration,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await Future.delayed(duration);
    }
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
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_email', _emailController.text.trim());
          await prefs.setString('user_fullName', _usernameController.text.trim());

          if (Theme.of(context).platform == TargetPlatform.linux ||
              Theme.of(context).platform == TargetPlatform.windows ||
              Theme.of(context).platform == TargetPlatform.macOS) {
            // Arată dialog, apoi delay, apoi închide dialogul și abia apoi pop
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const AlertDialog(
                backgroundColor: Colors.green,
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(child: Text('Registration successful!', style: TextStyle(color: Colors.white))),
                  ],
                ),
              ),
            );
            await Future.delayed(const Duration(seconds: 2));
            if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Închide dialogul
            await Future.delayed(const Duration(milliseconds: 100));
            if (Navigator.of(context).canPop()) Navigator.of(context).pop(); // Navighează înapoi
          } else {
            await _showFlushBar(
              message: 'Registration successful!',
              color: Colors.green,
              icon: Icons.check_circle,
            );
            Navigator.of(context).pop();
          }
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.inversePrimary,
        title: const Text('GUST Register'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          labelStyle: const TextStyle(fontSize: 14),
                          prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                        ),
                        style: const TextStyle(fontSize: 14),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: const TextStyle(fontSize: 14),
                          prefixIcon: Icon(Icons.email_outlined, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                        ),
                        style: const TextStyle(fontSize: 14),
                        keyboardType: TextInputType.emailAddress,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword, // 5.3
                        onChanged: _checkPasswordStrength, // 5.2
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(fontSize: 14),
                          prefixIcon: Icon(Icons.lock_outline, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
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
                      // 5.2: Password strength indicator
                      if (_passwordStrengthLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0, bottom: 2.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: LinearProgressIndicator(
                                  value: _passwordStrength,
                                  backgroundColor: Colors.grey[300],
                                  color: _passwordStrength < 0.5
                                      ? Colors.red
                                      : _passwordStrength < 0.75
                                          ? Colors.orange
                                          : Colors.green,
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _passwordStrengthLabel,
                                style: TextStyle(
                                  color: _passwordStrength < 0.5
                                      ? Colors.red
                                      : _passwordStrength < 0.75
                                          ? Colors.orange
                                          : Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword, // 5.3
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(fontSize: 14),
                          prefixIcon: Icon(Icons.lock_reset_outlined, color: theme.colorScheme.primary, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: theme.colorScheme.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                        ),
                        style: const TextStyle(fontSize: 14),
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
                      const SizedBox(height: 24),
                      _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                              ),
                              onPressed: _isLoading ? null : _register,
                              child: const Text('Register'),
                            ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          'Already have an account? Login',
                          style: TextStyle(color: theme.colorScheme.secondary),
                        ),
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
