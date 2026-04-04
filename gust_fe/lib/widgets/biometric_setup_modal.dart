import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BiometricSetupModal extends StatelessWidget {
  final String biometricType;
  final VoidCallback onEnable;
  final VoidCallback onSkip;

  const BiometricSetupModal({
    super.key,
    required this.biometricType,
    required this.onEnable,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    IconData biometricIcon;
    if (biometricType.toLowerCase().contains('face')) {
      biometricIcon = Icons.face;
    } else if (biometricType.toLowerCase().contains('fingerprint')) {
      biometricIcon = Icons.fingerprint;
    } else {
      biometricIcon = Icons.security;
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spaceLG),
              decoration: BoxDecoration(
                color: AppTheme.primaryPurple.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                biometricIcon,
                size: 64,
                color: AppTheme.primaryPurple,
              ),
            ),
            const SizedBox(height: AppTheme.spaceLG),
            Text(
              'Enable $biometricType?',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'Sign in quickly and securely using your $biometricType for future logins.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceXL),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                      side: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onEnable,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
                      backgroundColor: AppTheme.primaryPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: const Text(
                      'Enable',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
