import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef VoidCallbackAsync = Future<void> Function();

class AuthProviderButtons extends StatelessWidget {
  final VoidCallback? onGoogle;
  final VoidCallback? onApple;

  const AuthProviderButtons({
    Key? key,
    this.onGoogle,
    this.onApple,
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

  Widget _appleLogo() {
    // Simple Apple logo representation
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.apple,
        color: Colors.white,
        size: 20,
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

        // Apple Sign In
        if (onApple != null) ...[
          SizedBox(height: AppTheme.spaceSM),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.black,
                side: BorderSide(color: Colors.black),
                padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium)),
              ),
              onPressed: onApple,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _appleLogo(),
                  SizedBox(width: AppTheme.spaceSM),
                  Text('Sign in with Apple', style: TextStyle(color: Colors.white, fontSize: 15)),
                ],
              ),
            ),
          ),
        ],

        // Divider
        if (onGoogle != null || onApple != null) ...[
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
      ],
    );
  }
}
