import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/auth_provider_buttons.dart';
import 'services/biometric_auth_service.dart';
import 'utils/notification_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;
  final BiometricAuthService _biometricService = BiometricAuthService();
  // (No explicit focus nodes required; keyboard flow uses FocusScope)

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _usernameController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          hasCompletedOnboarding ? '/main-nav' : '/onboarding',
        );
      } else {
        if (!mounted) return;
        final message = NotificationHelper.parseErrorMessage(
          response.body,
          fallback: NotificationHelper.getHttpErrorMessage(response.statusCode),
        );
        await NotificationHelper.showError(context, message, title: 'Login Failed');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await NotificationHelper.showNetworkError(context, onRetry: _login);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (googleClientId.isEmpty) {
      await NotificationHelper.showWarning(
        context,
        'Google Sign-In not configured yet.\n\nPlease add your Google Client ID to constants.dart',
        duration: const Duration(seconds: 5),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: googleClientId,
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();

      if (account == null) {
        setState(() => _isLoading = false);
        return;
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken != null) {
        try {
          final response = await http.post(
            Uri.parse('$baseUrl/api/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final token = data['token'];
            if (token != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jwt_token', token);
              if (!mounted) return;
              setState(() => _isLoading = false);
              Navigator.pushReplacementNamed(context, '/main-nav');
              return;
            }
          }
        } catch (_) {}
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_email', account.email);
      await prefs.setString('google_display_name', account.displayName ?? '');

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushReplacementNamed(context, '/main-nav');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      await NotificationHelper.showError(
        context,
        'Failed to sign in with Google. Please try again.',
        title: 'Google Sign-In Error',
      );
    }
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
    
    // Check if biometric is enabled and try to authenticate
    _checkBiometricAuth();
  }

  /// Check if biometric authentication is enabled and authenticate if so
  Future<void> _checkBiometricAuth() async {
    final isBiometricEnabled = await _biometricService.isBiometricEnabled();
    if (!isBiometricEnabled) return;

    // Check if device supports biometric
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    // Try to authenticate
    final didAuthenticate = await _biometricService.authenticate(
      reason: 'Authenticate to access GUST',
    );

    if (didAuthenticate) {
      // Retrieve stored token
      final token = await _biometricService.getAuthToken();
      if (token != null) {
        // Successfully authenticated with biometric - set flag for welcome message
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('show_welcome_back', true);
        
        if (!mounted) return;
        // Navigate directly to dashboard without notification
        Navigator.pushReplacementNamed(context, '/main-nav');
      }
    }
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

                          // Provider buttons (Google)
                          AuthProviderButtons(
                            onGoogle: _signInWithGoogle,
                          ),

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
                            onFieldSubmitted: (_) => _login(),
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
