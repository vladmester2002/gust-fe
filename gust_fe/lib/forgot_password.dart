import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:another_flushbar/flushbar.dart';
import 'constants.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _emailSent = false;

  Future<void> _sendResetLink() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse('$baseUrl/api/auth/forgot-password');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        setState(() => _emailSent = true);
        Flushbar(
          message: 'Password reset link sent to ${_emailController.text}',
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.successGreen,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        ).show(context);
      } else {
        Flushbar(
          message: 'Error: Could not send reset link. Please try again.',
          duration: const Duration(seconds: 3),
          backgroundColor: AppTheme.errorRed,
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
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.errorRed,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.error, color: Colors.white),
      ).show(context);
    }
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
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              // Icon
                              Container(
                                padding: EdgeInsets.all(AppTheme.spaceLG),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.infoBlue.withOpacity(0.1),
                                ),
                                child: Icon(
                                  Icons.lock_reset,
                                  size: 64,
                                  color: AppTheme.infoBlue,
                                ),
                              ),
                              SizedBox(height: AppTheme.spaceLG),
                              
                              // Title
                              Text(
                                'Forgot Password?',
                                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                      color: AppTheme.primaryPurple,
                                      fontSize: 28,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AppTheme.spaceMD),
                              
                              // Description
                              Text(
                                'Enter your email address and we\'ll send you instructions to reset your password.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: AppTheme.spaceXL),
                              
                              // Email Field
                              GustTextField(
                                controller: _emailController,
                                label: 'Email',
                                hint: 'Enter your email',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: AppTheme.spaceLG),
                              
                              // Send Reset Link Button
                              GustButton(
                                text: _emailSent ? 'Resend Link' : 'Send Reset Link',
                                onPressed: _sendResetLink,
                                isLoading: _isLoading,
                                type: ButtonType.primary,
                                width: double.infinity,
                                icon: Icons.send,
                              ),
                              SizedBox(height: AppTheme.spaceMD),
                              
                              // Success message
                              if (_emailSent) ...[
                                Container(
                                  padding: EdgeInsets.all(AppTheme.spaceMD),
                                  decoration: BoxDecoration(
                                    color: AppTheme.successGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                    border: Border.all(color: AppTheme.successGreen.withOpacity(0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle, color: AppTheme.successGreen, size: 20),
                                      SizedBox(width: AppTheme.spaceSM),
                                      Expanded(
                                        child: Text(
                                          'Check your email for reset instructions',
                                          style: TextStyle(
                                            color: AppTheme.successGreen,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: AppTheme.spaceMD),
                              ],
                              
                              // Back to Login Link
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
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
