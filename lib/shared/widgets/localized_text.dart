import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/services/localization_service.dart';

/// Widget for rendering localized text with proper script support
/// Handles Devanagari (Hindi) and Gujarati scripts with appropriate fonts
class LocalizedText extends StatelessWidget {
  final String textKey;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? parameters;
  final String? fallbackText;

  const LocalizedText(
    this.textKey, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.parameters,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    String text;

    if (parameters != null) {
      text = LocalizationService.getLocalizedTextWithParams(
        textKey,
        parameters!,
      );
    } else {
      text = LocalizationService.getLocalizedText(textKey);
    }

    // Use fallback text if localization key not found and text equals key
    if (text == textKey && fallbackText != null) {
      text = fallbackText!;
    }

    // Get appropriate text style with font family for current script
    TextStyle effectiveStyle = _getEffectiveTextStyle(text, style);

    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      textDirection: textDirection ?? LocalizationService.textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Get effective text style with appropriate font family for the script
  TextStyle _getEffectiveTextStyle(String text, TextStyle? baseStyle) {
    String? fontFamily;

    // Determine appropriate font based on script
    if (LocalizationService.containsDevanagari(text)) {
      fontFamily = 'NotoSansDevanagari';
    } else if (LocalizationService.containsGujarati(text)) {
      fontFamily = 'NotoSansGujarati';
    } else {
      fontFamily = LocalizationService.getFontFamily();
    }

    if (fontFamily != null) {
      return (baseStyle ?? const TextStyle()).copyWith(fontFamily: fontFamily);
    }

    return baseStyle ?? const TextStyle();
  }
}

/// Extension for easy localization access
extension LocalizationExtension on String {
  /// Get localized text for this key
  String get tr => LocalizationService.getLocalizedText(this);

  /// Get localized text with parameters
  String trParams(Map<String, String> params) =>
      LocalizationService.getLocalizedTextWithParams(this, params);
}

/// Widget for rendering text that automatically detects and handles scripts
class ScriptAwareText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final ui.TextDirection? textDirection;
  final int? maxLines;
  final TextOverflow? overflow;

  const ScriptAwareText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    // Get appropriate text style with font family for current script
    TextStyle effectiveStyle = _getEffectiveTextStyle(text, style);

    return Text(
      text,
      style: effectiveStyle,
      textAlign: textAlign,
      textDirection: textDirection ?? LocalizationService.textDirection,
      maxLines: maxLines,
      overflow: overflow,
    );
  }

  /// Get effective text style with appropriate font family for the script
  TextStyle _getEffectiveTextStyle(String text, TextStyle? baseStyle) {
    String? fontFamily;

    // Determine appropriate font based on script detection
    if (LocalizationService.containsDevanagari(text)) {
      fontFamily = 'NotoSansDevanagari';
    } else if (LocalizationService.containsGujarati(text)) {
      fontFamily = 'NotoSansGujarati';
    }

    if (fontFamily != null) {
      return (baseStyle ?? const TextStyle()).copyWith(fontFamily: fontFamily);
    }

    return baseStyle ?? const TextStyle();
  }
}

/// Localized text field widget
class LocalizedTextField extends StatelessWidget {
  final String hintKey;
  final String? labelKey;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final int? maxLines;
  final String? Function(String?)? validator;

  const LocalizedTextField({
    super.key,
    required this.hintKey,
    this.labelKey,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      onChanged: onChanged,
      onTap: onTap,
      readOnly: readOnly,
      maxLines: maxLines,
      validator: validator,
      textDirection: LocalizationService.textDirection,
      style: TextStyle(fontFamily: LocalizationService.getFontFamily()),
      decoration: InputDecoration(
        hintText: LocalizationService.getLocalizedText(hintKey),
        labelText: labelKey != null
            ? LocalizationService.getLocalizedText(labelKey!)
            : null,
        hintStyle: TextStyle(fontFamily: LocalizationService.getFontFamily()),
        labelStyle: TextStyle(fontFamily: LocalizationService.getFontFamily()),
      ),
    );
  }
}
