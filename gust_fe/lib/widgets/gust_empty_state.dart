import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// GustEmptyState - Reusable empty state component
class GustEmptyState extends StatelessWidget {
  final String emoji;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const GustEmptyState({
    Key? key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: TextStyle(fontSize: 80),
            ),
            SizedBox(height: AppTheme.spaceLG),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              SizedBox(height: AppTheme.spaceSM),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              SizedBox(height: AppTheme.spaceLG),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(icon ?? Icons.refresh, color: AppTheme.primaryPurple),
                label: Text(
                  actionText!,
                  style: TextStyle(
                    color: AppTheme.primaryPurple,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
