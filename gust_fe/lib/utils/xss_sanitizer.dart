/// XSS (Cross-Site Scripting) protection utilities.
/// 
/// Provides HTML entity encoding for safe display of user-generated content.
/// Use these methods when displaying any content that could contain 
/// malicious scripts or HTML.
class XssSanitizer {
  /// HTML entity mappings for characters that should be escaped
  static const Map<String, String> _htmlEntities = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#x27;',
    '/': '&#x2F;',
  };

  /// Encodes HTML special characters to prevent XSS attacks.
  /// 
  /// Converts potentially dangerous characters to their HTML entity equivalents:
  /// - `&` → `&amp;`
  /// - `<` → `&lt;`
  /// - `>` → `&gt;`
  /// - `"` → `&quot;`
  /// - `'` → `&#x27;`
  /// - `/` → `&#x2F;`
  /// 
  /// Use this when displaying user input in HTML context.
  static String encodeHtml(String? input) {
    if (input == null || input.isEmpty) return '';
    
    return input.replaceAllMapped(
      RegExp(r'''[&<>"'/]'''),
      (match) => _htmlEntities[match.group(0)] ?? match.group(0)!,
    );
  }

  /// Strips all HTML tags from input, keeping only text content.
  /// 
  /// Removes anything between < and > including the brackets.
  /// Use this when you want to display only plain text.
  static String stripHtmlTags(String? input) {
    if (input == null || input.isEmpty) return '';
    
    return input.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  /// Sanitizes content for safe display in the app.
  /// 
  /// Combines stripping HTML tags and encoding remaining special characters.
  /// This is the safest option for user-generated content.
  static String sanitizeForDisplay(String? input) {
    if (input == null || input.isEmpty) return '';
    
    // First strip any HTML tags
    String stripped = stripHtmlTags(input);
    
    // Then encode any remaining special characters
    return encodeHtml(stripped);
  }

  /// Sanitizes a URL to prevent javascript: and data: protocol attacks.
  /// 
  /// Returns the original URL only if it starts with http://, https://, or /
  /// Otherwise returns an empty string.
  static String sanitizeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    
    final trimmed = url.trim().toLowerCase();
    
    // Only allow safe URL schemes
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('/')) {
      return url;
    }
    
    // Block potentially dangerous schemes
    if (trimmed.startsWith('javascript:') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('vbscript:')) {
      return '';
    }
    
    return url;
  }

  /// Checks if a string contains potentially dangerous HTML/script content.
  /// 
  /// Returns true if the input contains script tags, event handlers,
  /// or other potentially dangerous patterns.
  static bool containsDangerousContent(String? input) {
    if (input == null || input.isEmpty) return false;
    
    final lowerInput = input.toLowerCase();
    
    // Check for script tags
    if (lowerInput.contains('<script')) return true;
    
    // Check for event handlers
    if (RegExp(r'on\w+\s*=', caseSensitive: false).hasMatch(input)) return true;
    
    // Check for javascript: protocol
    if (lowerInput.contains('javascript:')) return true;
    
    // Check for data: protocol (can contain scripts)
    if (lowerInput.contains('data:text/html')) return true;
    
    return false;
  }
}
