/// Input sanitization utilities for defense-in-depth protection against
/// SQL injection and other input-based attacks.
///
/// Note: The app already uses parameterized queries (sqflite's `whereArgs`),
/// so this provides an additional layer of protection.
class InputSanitizer {
  // Characters that could be dangerous in SQL contexts (semicolon, quotes, backslash)
  static final RegExp _sqlSpecialChars = RegExp(r'''[;'"\\]''');
  
  // Control characters that should never appear in user input
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');
  
  // Valid email pattern
  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Sanitizes general text input by removing control characters
  /// and optionally escaping SQL special characters.
  /// 
  /// [input] - The raw user input
  /// [maxLength] - Maximum allowed length (default 500)
  /// [escapeSqlChars] - Whether to escape SQL special characters (default false)
  static String sanitizeText(
    String? input, {
    int maxLength = 500,
    bool escapeSqlChars = false,
  }) {
    if (input == null || input.isEmpty) return '';
    
    // Remove control characters
    String sanitized = input.replaceAll(_controlChars, '');
    
    // Trim whitespace
    sanitized = sanitized.trim();
    
    // Optionally escape SQL special characters
    if (escapeSqlChars) {
      sanitized = sanitized.replaceAllMapped(
        _sqlSpecialChars,
        (match) => '\\${match.group(0)}',
      );
    }
    
    // Enforce maximum length
    if (sanitized.length > maxLength) {
      sanitized = sanitized.substring(0, maxLength);
    }
    
    return sanitized;
  }

  /// Sanitizes numeric string input, ensuring only valid integers.
  /// Returns the sanitized number string or '0' if invalid.
  static String sanitizeNumeric(String? input, {int maxValue = 9999}) {
    if (input == null || input.isEmpty) return '0';
    
    // Remove everything except digits and minus sign
    final digitsOnly = input.replaceAll(RegExp(r'[^\d-]'), '');
    
    final parsed = int.tryParse(digitsOnly);
    if (parsed == null) return '0';
    
    // Clamp to valid range
    final clamped = parsed.clamp(0, maxValue);
    return clamped.toString();
  }

  /// Validates and normalizes email address.
  /// Returns null if invalid, otherwise returns lowercase trimmed email.
  static String? sanitizeEmail(String? input) {
    if (input == null || input.isEmpty) return null;
    
    final trimmed = input.trim().toLowerCase();
    
    // Remove control characters
    final cleaned = trimmed.replaceAll(_controlChars, '');
    
    // Validate email format
    if (!_emailPattern.hasMatch(cleaned)) {
      return null;
    }
    
    // Enforce reasonable email length
    if (cleaned.length > 254) {
      return null;
    }
    
    return cleaned;
  }

  /// Sanitizes product name input - more permissive than general text
  /// but still removes dangerous characters.
  static String sanitizeProductName(String? input) {
    return sanitizeText(
      input,
      maxLength: 200,
      escapeSqlChars: false, // Let parameterized queries handle this
    );
  }

  /// Sanitizes notes/context fields - allows more characters for readability.
  static String sanitizeNotes(String? input) {
    return sanitizeText(
      input,
      maxLength: 1000,
      escapeSqlChars: false,
    );
  }

  /// Sanitizes a full name input.
  static String sanitizeFullName(String? input) {
    if (input == null || input.isEmpty) return '';
    
    // Remove control characters
    String sanitized = input.replaceAll(_controlChars, '');
    
    // Trim and limit length
    sanitized = sanitized.trim();
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    
    return sanitized;
  }

  /// Validates that an integer ID is within valid bounds.
  /// Returns null if invalid.
  static int? validateId(dynamic input) {
    if (input == null) return null;
    
    int? id;
    if (input is int) {
      id = input;
    } else if (input is String) {
      id = int.tryParse(input);
    }
    
    if (id == null || id < 0 || id > 2147483647) {
      return null;
    }
    
    return id;
  }
}
