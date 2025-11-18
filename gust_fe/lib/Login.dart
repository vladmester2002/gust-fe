import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/auth_provider_buttons.dart';
import 'services/biometric_auth_service.dart';
import 'utils/notification_helper.dart';
import 'state/auth_state.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  final BiometricAuthService _biometricService = BiometricAuthService();
  bool _biometricVisible = false;
  // (No explicit focus nodes required; keyboard flow uses FocusScope)

  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final authState = context.read<AuthState>();
    final success = await authState.loginWithEmail(
      _usernameController.text.trim(),
      _passwordController.text.trim(),
    );
    await _handleAuthResult(success);
  }

  Future<void> _loginWithGoogle() async {
    final authState = context.read<AuthState>();
    final success = await authState.loginWithGoogle();
    await _handleAuthResult(success);
  }

  Future<void> _loginAnonymously() async {
    final authState = context.read<AuthState>();
    final success = await authState.loginAnonymously();
    await _handleAuthResult(success);
  }

  Future<void> _loginWithBiometrics() async {
    final authState = context.read<AuthState>();
    final success = await authState.loginWithBiometrics();
    await _handleAuthResult(success);
  }

  Future<void> _handleAuthResult(bool success) async {
    if (!mounted) return;
    final authState = context.read<AuthState>();
    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final hasCompletedOnboarding =
          prefs.getBool('onboarding_completed') ?? false;
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        hasCompletedOnboarding ? '/main-nav' : '/onboarding',
      );
      return;
    }

    final message = authState.errorMessage;
    if (message != null && mounted) {
      await NotificationHelper.showError(
        context,
        message,
        title: 'Authentication Failed',
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    await NotificationHelper.showWarning(
      context,
      'Facebook Sign-In coming soon!\n\nThis feature will be available in the next update.',
      duration: const Duration(seconds: 3),
    );
  }

  void _register() => Navigator.pushNamed(context, '/register');

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricAuth();
    });
  }

  /// Check if biometric authentication is enabled and authenticate if so
  Future<void> _checkBiometricAuth() async {
    final isBiometricEnabled = await _biometricService.isBiometricEnabled();
    if (!isBiometricEnabled) return;

    // Check if device supports biometric
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    if (mounted && !_biometricVisible) {
      setState(() => _biometricVisible = true);
    }

    final success = await context.read<AuthState>().loginWithBiometrics();
    if (!success || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_welcome_back', true);
    final hasCompletedOnboarding =
        prefs.getBool('onboarding_completed') ?? false;

    if (!mounted) return;
    Navigator.pushReplacementNamed(
      context,
      hasCompletedOnboarding ? '/main-nav' : '/onboarding',
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
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
          child: Stack(
            children: [
              // (theme toggle removed)
              Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: SlideTransition(
                        position: _slideAnim,
                        child: FadeTransition(
                          opacity: _fadeAnim,
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
                                  color: Theme.of(context).colorScheme.primary,
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

                          // Provider buttons (Google & Facebook)
                          AuthProviderButtons(
                            onGoogle: kIsWeb ? null : (_loginWithGoogle),
                            onFacebook: _signInWithFacebook,
                            onAnonymous: authState.isLoading ? null : _loginAnonymously,
                          ),

                          // Divider
                          SizedBox(height: AppTheme.spaceMD),
                          Row(
                            children: [
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider(color: Colors.grey.shade300)),
                            ],
                          ),
                          SizedBox(height: AppTheme.spaceMD),

                          // Email Field
                          // use a lightweight regex for better validation
                          GustTextField(
                            controller: _usernameController,
                            label: 'Email',
                            hint: 'Enter your email',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            semanticLabel: 'Email input',
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your email';
                              final emailRe = RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+");
                              if (!emailRe.hasMatch(value)) return 'Invalid email format';
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
                            semanticLabel: 'Password input',
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _loginWithEmail(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Please enter your password';
                              if (value.length < 6) return 'Password must be at least 6 characters';
                              return null;
                            },
                          ),
                          // Forgot password link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(context, '/forgot-password'),
                              child: Text('Forgot password?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.accentTeal)),
                            ),
                          ),
                          SizedBox(height: AppTheme.spaceLG),

                          // Login Button
                          GustButton(
                            text: 'Login',
                            onPressed: _loginWithEmail,
                            isLoading: authState.isLoading,
                            type: ButtonType.primary,
                            width: double.infinity,
                          ),
                          if (_biometricVisible) ...[
                            SizedBox(height: AppTheme.spaceSM),
                            TextButton.icon(
                              onPressed: authState.isLoading ? null : _loginWithBiometrics,
                              icon: Icon(Icons.fingerprint, color: AppTheme.accentTeal),
                              label: Text(
                                'Sign in with biometrics',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: AppTheme.accentTeal,
                                    ),
                              ),
                            ),
                          ],
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
                          ),
                        ], // Column children
                      ), // Column
                    ), // Form
                  ), // AutofillGroup
                ), // Padding
                          ), // Card
                        ), // FadeTransition
                      ), // SlideTransition
                    ), // ConstrainedBox
                  ), // inner Center
                ), // SingleChildScrollView
              ), // outer Center
              ], // Stack children
            ), // Stack
          ), // SafeArea
          ), // Container
        ); // Scaffold body
  }
}
