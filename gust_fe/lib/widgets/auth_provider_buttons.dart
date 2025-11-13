import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef VoidCallbackAsync = Future<void> Function();

class AuthProviderButtons extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onFacebook;
  final VoidCallback? onAnonymous;

  const AuthProviderButtons({
    Key? key,
    this.onGoogle,
    this.onFacebook,
    this.onAnonymous,
  }) : super(key: key);

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
      child: Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _facebookLogo() {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1877F2),
      ),
      alignment: Alignment.center,
      child: Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 20,
          fontFamily: 'serif',
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: BorderSide(color: AppTheme.dividerGrey),
                padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              onPressed: onGoogle,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _googleLogo(),
                  SizedBox(width: AppTheme.spaceSM),
                  Text('Sign in with Google', style: TextStyle(color: AppTheme.textPrimary, fontSize: 15)),
                ],
              ),
            ),
          ),

        // Facebook Sign In
        if (onFacebook != null)
          Padding(
            padding: EdgeInsets.only(
              left: AppTheme.spaceSM,
              right: AppTheme.spaceSM,
              top: onGoogle != null ? AppTheme.spaceSM : 0,
            ),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0xFF1877F2),
                side: BorderSide.none,
                padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              onPressed: onFacebook,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _facebookLogo(),
                  SizedBox(width: AppTheme.spaceSM),
                  Text('Sign in with Facebook', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),

        // Divider
        if (onGoogle != null || onFacebook != null) ...[
          Padding(
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
      ],
    );
  }

  Widget buildAnonymousButton() {
    if (onAnonymous == null) return const SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.only(top: AppTheme.spaceMD),
      child: TextButton.icon(
        onPressed: onAnonymous,
        icon: Icon(Icons.person_outline, color: AppTheme.textSecondary, size: 20),
        label: Text(
          'Continue as Guest',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
