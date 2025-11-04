import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/gust_button.dart';

/// Onboarding screen shown to first-time users
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({Key? key}) : super(key: key);

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

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
                child: Text(
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
            SizedBox(height: AppTheme.spaceXL),

            // Next/Get Started button
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
              child: GustButton(
                text: _currentPage == _pages.length - 1 ? 'Get Started' : 'Next',
                onPressed: _nextPage,
                type: ButtonType.primary,
                width: double.infinity,
                icon: _currentPage == _pages.length - 1 ? Icons.check : Icons.arrow_forward,
              ),
            ),
            SizedBox(height: AppTheme.spaceXL),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingItem item) {
    return Padding(
      padding: EdgeInsets.all(AppTheme.spaceXL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            padding: EdgeInsets.all(AppTheme.spaceXL),
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
          SizedBox(height: AppTheme.spaceXL),

          // Title
          Text(
            item.title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppTheme.spaceLG),

          // Description
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppTheme.textSecondary,
                  height: 1.6,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: AppTheme.spaceXS),
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

  OnboardingItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });
}
