import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/gust_button.dart';
import '../services/biometric_auth_service.dart';

/// Onboarding screen shown to first-time users
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final BiometricAuthService _biometricService = BiometricAuthService();
  int _currentPage = 0;
  bool _biometricsEnabled = false;

  final List<OnboardingItem> _pages = [
    OnboardingItem(
      icon: Icons.local_drink_outlined,
      iconColor: AppTheme.primaryPurple,
      title: 'Welcome to GUST',
      description:
          'Track your daily sugar intake and build healthier habits. Take control of your health, one sip at a time.',
    ),
    OnboardingItem(
      icon: Icons.analytics_outlined,
      iconColor: AppTheme.accentTeal,
      title: 'Visualize Your Progress',
      description:
          'See detailed analytics and insights about your sugar consumption. Monitor trends and set achievable goals.',
    ),
    OnboardingItem(
      icon: Icons.notifications_outlined,
      iconColor: AppTheme.accentCoral,
      title: 'Stay on Track',
      description:
          'Get helpful reminders and tips to maintain your healthy lifestyle. Build lasting habits with personalized guidance.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final available = await _biometricService.isBiometricAvailable();
    if (available && mounted) {
      setState(() {
        _pages.add(
          OnboardingItem(
            icon: Icons.fingerprint,
            iconColor: AppTheme.primaryPurple,
            title: 'Secure Access',
            description:
                'Enable biometric authentication for faster and more secure login.',
            showBiometricAction: true,
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/main-nav');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skip() {
    _completeOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _skip,
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => _buildIndicator(index == _currentPage),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXL),

            // Next/Get Started button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
              child: GustButton(
                text: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                onPressed: _nextPage,
                type: ButtonType.primary,
                width: double.infinity,
                icon: _currentPage == _pages.length - 1 ? Icons.check : Icons.arrow_forward,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXL),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppTheme.spaceXL),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.iconColor.withOpacity(0.1),
            ),
            child: Icon(
              item.icon,
              size: 100,
              color: item.iconColor,
            ),
          ),
          const SizedBox(height: AppTheme.spaceXL),

          // Title
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppTheme.spaceLG),

          // Description
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
          
          if (item.showBiometricAction) ...[
            const SizedBox(height: AppTheme.spaceXL),
            GustButton(
              text: _biometricsEnabled ? 'Biometrics Enabled' : 'Enable Biometrics',
              onPressed: _biometricsEnabled
                  ? null
                  : () async {
                      await _biometricService.enableBiometric();
                      setState(() {
                        _biometricsEnabled = true;
                      });
                    },
              type: ButtonType.secondary,
              icon: _biometricsEnabled ? Icons.check : Icons.fingerprint,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXS),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? AppTheme.primaryPurple : AppTheme.dividerGrey,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class OnboardingItem {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool showBiometricAction;

  OnboardingItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    this.showBiometricAction = false,
  });
}
