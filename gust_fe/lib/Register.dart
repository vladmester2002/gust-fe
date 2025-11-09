import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/password_strength_indicator.dart';
import 'utils/notification_helper.dart';

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

  // Focus nodes to improve keyboard navigation (kept for possible future focus management)
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'fullName': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        await NotificationHelper.showSuccess(
          context,
          'Registration successful! You can now login.',
        );
        if (!mounted) return;
        Navigator.of(context).pop();
      } else if (response.statusCode == 409) {
        final message = NotificationHelper.parseErrorMessage(
          response.body,
          fallback: 'An account with this email already exists.',
        );
        await NotificationHelper.showWarning(context, message);
      } else {
        final message = NotificationHelper.parseErrorMessage(
          response.body,
          fallback: NotificationHelper.getHttpErrorMessage(response.statusCode),
        );
        await NotificationHelper.showError(context, message, title: 'Registration Failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await NotificationHelper.showNetworkError(context, onRetry: _register);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // (theme toggle removed)
              Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
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
                        child: AutofillGroup(
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
                                        color: Theme.of(context).colorScheme.primary,
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
                                  autofillHints: const [AutofillHints.name],
                                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
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
                                  autofillHints: const [AutofillHints.email],
                                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
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
                                  autofillHints: const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                  onChanged: (_) => setState(() {}), // Trigger rebuild for strength indicator
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
                                SizedBox(height: AppTheme.spaceXS),
                                // Password strength indicator
                                PasswordStrengthIndicator(
                                  password: _passwordController.text,
                                  showRequirements: true,
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
                                  autofillHints: const [AutofillHints.newPassword],
                                  onFieldSubmitted: (_) => _register(),
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
                        ), // AutofillGroup
                      ), // Padding
                    ), // Card
                  ), // SingleChildScrollView
                ), // Center
              ), // Expanded
                    ], // Column children
                  ), // Column
                ], // Stack children
              ), // Stack
          ), // SafeArea
      ), // Container
    ); // Scaffold body
  }
}
