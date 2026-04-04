import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum PasswordStrength {
  empty,
  weak,
  medium,
  strong,
}

class PasswordStrengthResult {
  final PasswordStrength strength;
  final List<String> requirements;
  final int score;

  PasswordStrengthResult({
    required this.strength,
    required this.requirements,
    required this.score,
  });
}

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool showRequirements;

  const PasswordStrengthIndicator({
    super.key,
    required this.password,
    this.showRequirements = true,
  });

  PasswordStrengthResult _calculateStrength(String password) {
    if (password.isEmpty) {
      return PasswordStrengthResult(
        strength: PasswordStrength.empty,
        requirements: [],
        score: 0,
      );
    }

    final requirements = <String>[];
    int score = 0;

    // Check length (minimum 6, recommended 8+)
    if (password.length >= 6) {
      requirements.add('At least 6 characters');
      score += 1;
    }
    if (password.length >= 8) {
      score += 1;
    }
    if (password.length >= 12) {
      score += 1;
    }

    // Check for lowercase
    if (password.contains(RegExp(r'[a-z]'))) {
      requirements.add('Contains lowercase letter');
      score += 1;
    }

    // Check for uppercase
    if (password.contains(RegExp(r'[A-Z]'))) {
      requirements.add('Contains uppercase letter');
      score += 1;
    }

    // Check for numbers
    if (password.contains(RegExp(r'[0-9]'))) {
      requirements.add('Contains number');
      score += 1;
    }

    // Check for special characters
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      requirements.add('Contains special character');
      score += 1;
    }

    // Determine strength based on score
    PasswordStrength strength;
    if (score <= 2) {
      strength = PasswordStrength.weak;
    } else if (score <= 4) {
      strength = PasswordStrength.medium;
    } else {
      strength = PasswordStrength.strong;
    }

    return PasswordStrengthResult(
      strength: strength,
      requirements: requirements,
      score: score,
    );
  }

  Color _getStrengthColor(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return AppTheme.dividerGrey;
      case PasswordStrength.weak:
        return AppTheme.errorRed;
      case PasswordStrength.medium:
        return AppTheme.warningOrange;
      case PasswordStrength.strong:
        return AppTheme.successGreen;
    }
  }

  String _getStrengthText(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return '';
      case PasswordStrength.weak:
        return 'Weak';
      case PasswordStrength.medium:
        return 'Medium';
      case PasswordStrength.strong:
        return 'Strong';
    }
  }

  double _getStrengthProgress(PasswordStrength strength) {
    switch (strength) {
      case PasswordStrength.empty:
        return 0.0;
      case PasswordStrength.weak:
        return 0.33;
      case PasswordStrength.medium:
        return 0.66;
      case PasswordStrength.strong:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _calculateStrength(password);
    final color = _getStrengthColor(result.strength);
    final strengthText = _getStrengthText(result.strength);
    final progress = _getStrengthProgress(result.strength);

    if (result.strength == PasswordStrength.empty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.dividerGrey.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Text(
              strengthText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),

        // Requirements checklist
        if (showRequirements && password.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spaceSM),
          ..._buildRequirementsList(password),
        ],
      ],
    );
  }

  List<Widget> _buildRequirementsList(String password) {
    final requirements = [
      _RequirementItem('At least 6 characters', password.length >= 6),
      _RequirementItem('Contains lowercase letter', password.contains(RegExp(r'[a-z]'))),
      _RequirementItem('Contains uppercase letter', password.contains(RegExp(r'[A-Z]'))),
      _RequirementItem('Contains number', password.contains(RegExp(r'[0-9]'))),
      _RequirementItem('Contains special character', password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
    ];

    return requirements
        .map((req) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
              child: Row(
                children: [
                  Icon(
                    req.met ? Icons.check_circle : Icons.circle_outlined,
                    size: 16,
                    color: req.met ? AppTheme.successGreen : AppTheme.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(width: AppTheme.spaceXS),
                  Text(
                    req.text,
                    style: TextStyle(
                      fontSize: 11,
                      color: req.met ? AppTheme.textPrimary : AppTheme.textSecondary,
                      fontWeight: req.met ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }
}

class _RequirementItem {
  final String text;
  final bool met;

  _RequirementItem(this.text, this.met);
}
