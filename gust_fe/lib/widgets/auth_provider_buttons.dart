import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef VoidCallbackAsync = Future<void> Function();

class AuthProviderButtons extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onYahoo;
  final VoidCallback? onAnonymous;

  const AuthProviderButtons({
    super.key,
    this.onGoogle,
    this.onYahoo,
    this.onAnonymous,
  });

  Widget _googleLogo() {
    // Simple branded circle with a 'G' to indicate Google sign-in.
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFFFFFFF),
        border: Border.all(color: AppTheme.dividerGrey, width: 0.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _yahooLogo() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF6001D2),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Y',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Google Sign In
        if (onGoogle != null)
          Semantics(
            label: 'Sign in with Google button',
            hint: 'Double tap to sign in using your Google account',
            button: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
              child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppTheme.dividerGrey),
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              onPressed: onGoogle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _googleLogo(),
                  const SizedBox(width: AppTheme.spaceSM),
                  const Text('Sign in with Google',
                      style:
                          TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                ],
              ),
            ),
          )),

        // Yahoo Sign In
        if (onYahoo != null)
          Semantics(
            label: 'Sign in with Yahoo button',
            hint: 'Double tap to sign in using your Yahoo account',
            button: true,
            child: Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spaceSM,
              right: AppTheme.spaceSM,
              top: onGoogle != null ? AppTheme.spaceSM : 0,
            ),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF6001D2),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              onPressed: onYahoo,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _yahooLogo(),
                  const SizedBox(width: AppTheme.spaceSM),
                  const Text('Sign in with Yahoo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )),

        // Divider
        if (onGoogle != null || onYahoo != null) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
            child: Row(
              children: [
                Expanded(child: Divider(color: AppTheme.dividerGrey)),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(child: Divider(color: AppTheme.dividerGrey)),
              ],
            ),
          ),
        ],

        // Anonymous Sign In (after divider, below email/password)
        buildAnonymousButton(),
      ],
    );
  }

  Widget buildAnonymousButton() {
    if (onAnonymous == null) return const SizedBox.shrink();

    return Semantics(
      label: 'Continue as guest button',
      hint: 'Double tap to continue without creating an account',
      button: true,
      child: Padding(
      padding: const EdgeInsets.only(top: AppTheme.spaceMD),
      child: TextButton.icon(
        onPressed: onAnonymous,
        icon:
            const Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 20),
        label: const Text(
          'Continue as Guest',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ));
  }
}
