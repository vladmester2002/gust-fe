import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Biometric Authentication Prompt Dialog
/// Shows after first successful login to offer biometric setup
class BiometricPromptDialog extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const BiometricPromptDialog({
    Key? key,
    required this.onEnable,
    required this.onSkip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryPurple.withOpacity(0.1),
              ),
              child: Icon(
                Icons.fingerprint,
                size: 64,
                color: AppTheme.primaryPurple,
              ),
            ),
            SizedBox(height: AppTheme.spaceLG),

            // Title
            Text(
              'Enable Biometric Login?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spaceMD),

            // Description
            Text(
              'Use Face ID or fingerprint to sign in quickly and securely. You can always use your password as a fallback.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spaceXL),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.dividerGrey),
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onEnable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      padding: EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: Text('Enable'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Show the biometric prompt dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => BiometricPromptDialog(
        onEnable: () => Navigator.of(context).pop(true),
        onSkip: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
