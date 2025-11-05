import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import '../theme/app_theme.dart';

/// Helper class for showing consistent notifications throughout the app
class NotificationHelper {
  /// Show a success notification
  static Future<void> showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    if (!context.mounted) return;
    
    await Flushbar(
      message: message,
      duration: duration,
      backgroundColor: AppTheme.successGreen,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.check_circle_rounded,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
    ).show(context);
  }

  /// Show an error notification
  static Future<void> showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
    String? title,
  }) async {
    if (!context.mounted) return;
    
    await Flushbar(
      title: title,
      message: message,
      duration: duration,
      backgroundColor: AppTheme.errorRed,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.error_rounded,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
    ).show(context);
  }

  /// Show a warning notification
  static Future<void> showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    if (!context.mounted) return;
    
    await Flushbar(
      message: message,
      duration: duration,
      backgroundColor: AppTheme.warningOrange,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.warning_rounded,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
    ).show(context);
  }

  /// Show an info notification
  static Future<void> showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) async {
    if (!context.mounted) return;
    
    await Flushbar(
      message: message,
      duration: duration,
      backgroundColor: AppTheme.infoBlue,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.info_rounded,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeInBack,
    ).show(context);
  }

  /// Show a network error with retry option
  static Future<void> showNetworkError(
    BuildContext context, {
    VoidCallback? onRetry,
  }) async {
    if (!context.mounted) return;
    
    await Flushbar(
      title: 'Connection Error',
      message: 'Unable to connect to server. Please check your internet connection.',
      duration: const Duration(seconds: 5),
      backgroundColor: AppTheme.errorRed,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const Icon(
        Icons.wifi_off_rounded,
        color: Colors.white,
        size: 28,
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: true,
      dismissDirection: FlushbarDismissDirection.HORIZONTAL,
      mainButton: onRetry != null
          ? TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text(
                'RETRY',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    ).show(context);
  }

  /// Show a loading notification (use sparingly, prefer CircularProgressIndicator)
  static Future<void> showLoading(
    BuildContext context,
    String message,
  ) async {
    if (!context.mounted) return;
    
    await Flushbar(
      message: message,
      duration: const Duration(seconds: 2),
      backgroundColor: AppTheme.textSecondary,
      flushbarPosition: FlushbarPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      icon: const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
      leftBarIndicatorColor: Colors.white,
      isDismissible: false,
    ).show(context);
  }

  /// Parse error message from API response
  static String parseErrorMessage(String responseBody, {String fallback = 'An error occurred'}) {
    try {
      final dynamic decoded = jsonDecode(responseBody);
      
      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('message') && decoded['message'] != null) {
          return decoded['message'].toString();
        }
        
        if (decoded.containsKey('error') && decoded['error'] != null) {
          return decoded['error'].toString();
        }
      }
    } catch (_) {
      // If parsing fails, return fallback
    }
    
    return fallback;
  }

  /// Get user-friendly error message based on status code
  static String getHttpErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Invalid credentials. Please try again.';
      case 403:
        return 'Access denied. Please check your permissions.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'This account already exists.';
      case 422:
        return 'Validation failed. Please check your input.';
      case 429:
        return 'Too many requests. Please try again later.';
      case 500:
        return 'Server error. Please try again later.';
      case 503:
        return 'Service unavailable. Please try again later.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
