import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/auth_provider_buttons.dart';
import 'utils/notification_helper.dart';
import 'state/auth_state.dart';
import 'main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final authState = context.read<AuthState>();
    final success = await authState.loginWithEmail(
      _emailController.text.trim(),
      _passwordController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      // Navigation handled by AuthGate
    } else {
      final message = authState.errorMessage ?? 'Login failed. Please check your credentials.';
      await NotificationHelper.showError(
        context,
        message,
        title: 'Login Failed',
      );
    }
  }

  Future<void> _loginAsGuest() async {
    final authState = context.read<AuthState>();
    await authState.loginAnonymously();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.mainNav);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthState>();
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundGrey,
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
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          // Logo or App Name
                          Icon(
                            Icons.favorite,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          SizedBox(height: AppTheme.spaceMD),
                          
                          // Title
                          Text(
                            'Welcome to GUST',
                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 32,
                                ),
                          ),
                          SizedBox(height: AppTheme.spaceSM),
                          Text(
                            'Track your sugar intake and stay healthy',
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
                            hint: 'Enter your password',
                            prefixIcon: Icons.lock_outline,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _login(),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: AppTheme.spaceSM),

                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                              child: Text(
                                'Forgot Password?',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.accentTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceLG),

                          // Login Button
                          GustButton(
                            text: 'Login',
                            onPressed: _login,
                            isLoading: authState.isLoading,
                            type: ButtonType.primary,
                            width: double.infinity,
                          ),
                          SizedBox(height: AppTheme.spaceMD),

                          // Divider
                          Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
                                child: Text(
                                  'OR',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          SizedBox(height: AppTheme.spaceMD),

                          // Auth Provider Buttons (Google, Yahoo)
                          AuthProviderButtons(
                            onGoogle: () async {
                              final success = await context.read<AuthState>().loginWithGoogle();
                              if (!success && mounted) {
                                await NotificationHelper.showError(
                                  context,
                                  context.read<AuthState>().errorMessage ?? 'Google sign-in failed',
                                );
                              }
                            },
                            onYahoo: () async {
                              final success = await context.read<AuthState>().loginWithYahoo();
                              if (!success && mounted) {
                                await NotificationHelper.showError(
                                  context,
                                  context.read<AuthState>().errorMessage ?? 'Yahoo sign-in failed',
                                );
                              }
                            },
                            onAnonymous: _loginAsGuest,
                          ),
                          SizedBox(height: AppTheme.spaceMD),

                          // Register Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Don\'t have an account? ',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pushNamed(context, AppRoutes.register),
                                child: Text(
                                  'Register',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
