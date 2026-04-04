import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// GustButton - Reusable button component with consistent styling
class GustButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonType type;
  final IconData? icon;
  final double? width;

  const GustButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.type = ButtonType.primary,
    this.icon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    if (type == ButtonType.text) {
      return TextButton(
        onPressed: isLoading ? null : onPressed,
        child: _buildContent(),
      );
    }

    return SizedBox(
      width: width,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getBackgroundColor(),
          foregroundColor: _getForegroundColor(),
          elevation: type == ButtonType.primary ? 2 : 0,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceXL,
            vertical: AppTheme.spaceMD,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            side: type == ButtonType.secondary
                ? const BorderSide(color: AppTheme.primaryPurple, width: 1.5)
                : BorderSide.none,
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            type == ButtonType.text || type == ButtonType.secondary
                ? AppTheme.primaryPurple
                : Colors.white,
          ),
        ),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: AppTheme.spaceSM),
          Text(text),
        ],
      );
    }

    return Text(text);
  }

  Color _getBackgroundColor() {
    switch (type) {
      case ButtonType.primary:
        return AppTheme.primaryPurple;
      case ButtonType.secondary:
        return Colors.transparent;
      case ButtonType.success:
        return AppTheme.successGreen;
      case ButtonType.danger:
        return AppTheme.errorRed;
      default:
        return AppTheme.primaryPurple;
    }
  }

  Color _getForegroundColor() {
    switch (type) {
      case ButtonType.secondary:
        return AppTheme.primaryPurple;
      default:
        return Colors.white;
    }
  }
}

enum ButtonType {
  primary,
  secondary,
  text,
  success,
  danger,
}
