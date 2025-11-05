import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:another_flushbar/flushbar.dart';
import 'theme/app_theme.dart';
import 'widgets/gust_button.dart';
import 'widgets/gust_text_field.dart';
import 'widgets/auth_provider_buttons.dart';
import 'services/biometric_auth_service.dart';
import 'widgets/biometric_prompt_dialog.dart';

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

        // Check if this is the first login
        final hasCompletedOnboarding = prefs.getBool('onboarding_completed') ?? false;

        Flushbar(
          message: 'Login successful!',
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successGreen,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.check_circle, color: Colors.white),
        ).show(context);
        if (!mounted) return;
        
        // Show biometric prompt (if not already enabled)
        await _showBiometricPrompt(token);
        
        // Navigate to onboarding if first time, otherwise go to main navigation
        if (!hasCompletedOnboarding) {
          Navigator.pushReplacementNamed(context, '/onboarding');
        } else {
          Navigator.pushReplacementNamed(context, '/main-nav');
        }
      } else {
        final message = _parseErrorMessage(response.body) ?? 'Login failed';
        Flushbar(
          message: 'Error: $message',
          duration: const Duration(seconds: 2),
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
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.errorRed,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.error, color: Colors.white),
      ).show(context);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    // Check if Google Client ID is configured
    if (googleClientId.isEmpty) {
      setState(() => _isLoading = false);
      Flushbar(
        message: 'Google Sign-In not configured yet.\n\nPlease add your Google Client ID to constants.dart\n\nSee GOOGLE_SIGNIN_SETUP.md for instructions.',
        duration: const Duration(seconds: 5),
        backgroundColor: AppTheme.warningOrange,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
        icon: const Icon(Icons.warning, color: Colors.white),
      ).show(context);
      return;
    }
    
    try {
      // Initialize GoogleSignIn with client ID
      final googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        clientId: googleClientId,
      );

      // Sign in
      final GoogleSignInAccount? account = await googleSignIn.signIn();
      
      if (account == null) {
        // User canceled sign-in
        setState(() => _isLoading = false);
        return;
      }
      
      setState(() => _isLoading = false);

      final auth = await account.authentication;
      final idToken = auth.idToken;

      if (idToken != null) {
        // Try exchanging the idToken with your backend for a JWT (optional)
        try {
          final url = Uri.parse('$baseUrl/api/auth/google');
          final resp = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'idToken': idToken}),
          );
          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            final token = data['token'];
            if (token != null) {
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('jwt_token', token);
              Flushbar(
                message: 'Signed in with Google',
                duration: const Duration(seconds: 2),
                backgroundColor: AppTheme.successGreen,
                flushbarPosition: FlushbarPosition.TOP,
                margin: const EdgeInsets.all(8),
                borderRadius: BorderRadius.circular(8),
              ).show(context);
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/main-nav');
              return;
            }
          }
          // If backend exchange failed, fall through to local success handling
        } catch (_) {
          // ignore backend errors and continue
        }
      }

      // Fallback: we have a signed-in Google account; store some info locally and continue
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('google_email', account.email);
      await prefs.setString('google_display_name', account.displayName ?? '');

      Flushbar(
        message: 'Signed in as ${account.email}',
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.successGreen,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
      ).show(context);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main-nav');
    } catch (e) {
      setState(() => _isLoading = false);
      Flushbar(
        message: 'Google sign-in error: $e',
        duration: const Duration(seconds: 3),
        backgroundColor: AppTheme.errorRed,
        flushbarPosition: FlushbarPosition.TOP,
        margin: const EdgeInsets.all(8),
        borderRadius: BorderRadius.circular(8),
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

  /// Show biometric prompt dialog after successful login
  Future<void> _showBiometricPrompt(String token) async {
    final isBiometricEnabled = await _biometricService.isBiometricEnabled();
    if (isBiometricEnabled) return; // Already enabled

    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return; // Device doesn't support biometric

    if (!mounted) return;
    
    final result = await BiometricPromptDialog.show(context);
    if (result == true) {
      // User wants to enable biometric
      final didAuthenticate = await _biometricService.authenticate(
        reason: 'Authenticate to enable biometric login',
      );
      
      if (didAuthenticate) {
        // Save token and enable biometric
        await _biometricService.saveAuthToken(token);
        await _biometricService.enableBiometric();
        
        if (!mounted) return;
        Flushbar(
          message: 'Biometric login enabled!',
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successGreen,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.fingerprint, color: Colors.white),
        ).show(context);
      }
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
        // Successfully authenticated with biometric
        if (!mounted) return;
        Flushbar(
          message: 'Welcome back!',
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.successGreen,
          flushbarPosition: FlushbarPosition.TOP,
          margin: const EdgeInsets.all(8),
          borderRadius: BorderRadius.circular(8),
          icon: const Icon(Icons.fingerprint, color: Colors.white),
        ).show(context);
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
