import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';
import 'constants.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _token;
  bool _tokenExpired = false;


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Extract token from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map) {
      _token = args['token'] as String?;
    }
    // Also try to get from query parameters (for web)
    if (_token == null) {
      final uri = Uri.base;
      _token = uri.queryParameters['token'];
    }
  }

  @override
  void dispose() {
    _passwordController.clear();
    _confirmPasswordController.clear();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  int getPasswordStrength(String password) {
    int strength = 0;
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;
    return (strength / 6 * 3).round(); // Scale to 0-3
  }

  Color getStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return AppTheme.errorRed;
      case 2:
        return Colors.orange;
      case 3:
        return AppTheme.successGreen;
      default:
        return Colors.grey;
    }
  }

  String getStrengthText(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Medium';
      case 3:
        return 'Strong';
      default:
        return '';
    }
  }

  Future<void> _resetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_token == null || _token!.isEmpty) {
      _showError('Invalid reset link. Please request a new password reset.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$baseUrl/api/auth/reset-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': _token,
          'newPassword': _passwordController.text.trim(),
        }),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        _showSuccess();
      } else {
        // Parse error message
        String errorMessage = 'Failed to reset password. Please try again.';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          if (errorData.containsKey('message')) {
            errorMessage = errorData['message'];
          }
        } catch (e) {
          // Use default error message
        }

        if (errorMessage.toLowerCase().contains('expired')) {
          setState(() => _tokenExpired = true);
        }

        _showError(errorMessage);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Network error: ${e.toString()}');
    }
  }

  void _showSuccess() {
    Flushbar(
      message: 'Password reset successful! Redirecting to login...',
      duration: const Duration(seconds: 3),
      backgroundColor: AppTheme.successGreen,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.check_circle, color: Colors.white),
    ).show(context).then((_) {
      // Navigate to login after success message
      Navigator.of(context).pushReplacementNamed('/login');
    });
  }

  void _showError(String message) {
    Flushbar(
      message: message,
      duration: const Duration(seconds: 4),
      backgroundColor: AppTheme.errorRed,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(8),
      borderRadius: BorderRadius.circular(8),
      icon: const Icon(Icons.error, color: Colors.white),
    ).show(context);
  }

  @override
  Widget build(BuildContext context) {
    final passwordStrength = getPasswordStrength(_passwordController.text);

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
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
                    child: Card(
                      elevation: 12.0,
                      shadowColor: Colors.black.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppTheme.spaceXL),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Icon
                              Container(
                                padding: const EdgeInsets.all(AppTheme.spaceLG),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _tokenExpired
                                      ? AppTheme.errorRed.withOpacity(0.1)
                                      : AppTheme.primaryPurple.withOpacity(0.1),
                                ),
                                child: Icon(
                                  _tokenExpired ? Icons.error : Icons.lock_reset,
                                  size: 64,
                                  color: _tokenExpired ? AppTheme.errorRed : AppTheme.primaryPurple,
                                ),
                              ),
                              const SizedBox(height: AppTheme.spaceLG),

                              // Title
                              Text(
                                _tokenExpired ? 'Link Expired' : 'Reset Password',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      color: AppTheme.primaryPurple,
                                      fontSize: 28,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppTheme.spaceMD),

                              // Description
                              if (!_tokenExpired) ...[
                                Text(
                                  'Enter your new password below',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spaceXL),

                                // New Password Field
                                GustTextField(
                                  controller: _passwordController,
                                  label: 'New Password',
                                  hint: 'Enter new password',
                                  prefixIcon: Icons.lock_outlined,
                                  obscureText: _obscurePassword,
                                  suffixIcon: _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  onSuffixIconTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                  validator: validatePassword,
                                  onChanged: (value) => setState(() {}), // Trigger rebuild for strength indicator
                                ),
                                const SizedBox(height: AppTheme.spaceSM),

                                // Password strength indicator
                                if (_passwordController.text.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: LinearProgressIndicator(
                                          value: passwordStrength / 3,
                                          backgroundColor: Colors.grey.shade200,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            getStrengthColor(passwordStrength),
                                          ),
                                          minHeight: 4,
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spaceSM),
                                      Text(
                                        getStrengthText(passwordStrength),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: getStrengthColor(passwordStrength),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppTheme.spaceMD),
                                ],

                                // Confirm Password Field
                                GustTextField(
                                  controller: _confirmPasswordController,
                                  label: 'Confirm Password',
                                  hint: 'Re-enter new password',
                                  prefixIcon: Icons.lock_outlined,
                                  obscureText: _obscureConfirmPassword,
                                  textInputAction: TextInputAction.done,
                                  suffixIcon: _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                  onSuffixIconTap: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                  validator: validateConfirmPassword,
                                ),
                                const SizedBox(height: AppTheme.spaceLG),

                                // Reset Password Button
                                GustButton(
                                  text: 'Reset Password',
                                  onPressed: _resetPassword,
                                  isLoading: _isLoading,
                                  type: ButtonType.primary,
                                  width: double.infinity,
                                  icon: Icons.check,
                                ),
                              ] else ...[
                                // Expired token message
                                Text(
                                  'This password reset link has expired. Please request a new one.',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppTheme.spaceXL),
                                GustButton(
                                  text: 'Request New Link',
                                  onPressed: () => Navigator.of(context).pushReplacementNamed('/forgot-password'),
                                  type: ButtonType.primary,
                                  width: double.infinity,
                                  icon: Icons.refresh,
                                ),
                              ],

                              const SizedBox(height: AppTheme.spaceMD),

                              // Back to Login Link
                              GestureDetector(
                                onTap: () => Navigator.of(context).pushReplacementNamed('/login'),
                                child: Text(
                                  'Back to Login',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.accentTeal,
                                        fontWeight: FontWeight.w600,
                                      ),
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
            ],
          ),
        ),
      ),
    );
  }
}
