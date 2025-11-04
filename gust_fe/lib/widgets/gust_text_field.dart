import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// GustTextField - Reusable text field component with consistent styling
class GustTextField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final void Function(String)? onChanged;
  final Iterable<String>? autofillHints;
  final String? semanticLabel;

  const GustTextField({
    Key? key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autofillHints,
    this.semanticLabel,
  }) : super(key: key);
  @override
  State<GustTextField> createState() => _GustTextFieldState();
}

class _GustTextFieldState extends State<GustTextField> {
  late bool _obscure;

  @override
  void initState() {
    super.initState();
    _obscure = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final showSuffix = widget.suffixIcon != null;
    final theme = Theme.of(context);
    final InputDecorationTheme idt = theme.inputDecorationTheme;
    final Color fill = widget.enabled
        ? (idt.fillColor ?? AppTheme.cardWhite)
        : AppTheme.backgroundGrey;
    final TextStyle? labelStyle = idt.labelStyle ?? TextStyle(color: AppTheme.textSecondary, fontSize: 16);
    final TextStyle? hintStyle = idt.hintStyle ?? TextStyle(color: AppTheme.textSecondary.withOpacity(0.6), fontSize: 14);
    final TextStyle? errorStyle = idt.errorStyle ?? TextStyle(color: AppTheme.errorRed, fontSize: 12);

    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        keyboardType: widget.keyboardType,
        validator: widget.validator,
        enabled: widget.enabled,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        textInputAction: widget.textInputAction,
        onFieldSubmitted: widget.onFieldSubmitted,
        onChanged: widget.onChanged,
        autofillHints: widget.autofillHints == null ? null : List<String>.from(widget.autofillHints!),
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.textTheme.bodyLarge?.color ?? AppTheme.textPrimary),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: theme.colorScheme.primary,
                  size: 22,
                )
              : null,
          suffixIcon: showSuffix
              ? IconButton(
                  icon: Icon(
                    widget.suffixIcon,
                    color: theme.iconTheme.color?.withOpacity(0.8),
                    size: 22,
                  ),
                  onPressed: widget.onSuffixIconTap,
                )
              : (widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: theme.iconTheme.color?.withOpacity(0.8),
                        size: 22,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    )
                  : null),
          filled: true,
          fillColor: fill,
          contentPadding: EdgeInsets.symmetric(horizontal: AppTheme.spaceMD, vertical: AppTheme.spaceMD),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide(color: AppTheme.dividerGrey, width: 1)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide(color: AppTheme.dividerGrey, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide(color: theme.colorScheme.primary, width: 2)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide(color: AppTheme.errorRed, width: 1)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide(color: AppTheme.errorRed, width: 2)),
          labelStyle: labelStyle,
          hintStyle: hintStyle,
          errorStyle: errorStyle,
        ),
      ),
    );
  }
}
