import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/accessibility_service.dart';

/// Widget wrapper that provides enhanced accessibility features
class AccessibilityWidget extends StatefulWidget {
  final Widget child;
  final String? semanticLabel;
  final String? hint;
  final bool excludeSemantics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableKeyboardNavigation;
  final String? voiceCommand;

  const AccessibilityWidget({
    super.key,
    required this.child,
    this.semanticLabel,
    this.hint,
    this.excludeSemantics = false,
    this.onTap,
    this.onLongPress,
    this.enableKeyboardNavigation = true,
    this.voiceCommand,
  });

  @override
  State<AccessibilityWidget> createState() => _AccessibilityWidgetState();
}

class _AccessibilityWidgetState extends State<AccessibilityWidget> {
  final FocusNode _focusNode = FocusNode();
  final AccessibilityService _accessibilityService = AccessibilityService();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.semanticLabel != null) {
      _accessibilityService.announceForScreenReader(widget.semanticLabel!);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = widget.child;

    // Add keyboard navigation support
    if (widget.enableKeyboardNavigation &&
        _accessibilityService.isKeyboardNavigationEnabled) {
      child = Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyPress,
        child: child,
      );
    }

    // Add semantic information
    if (!widget.excludeSemantics) {
      child = Semantics(
        label: widget.semanticLabel,
        hint: widget.hint,
        button: widget.onTap != null,
        focusable: true,
        child: child,
      );
    }

    // Add gesture detection for accessibility
    if (widget.onTap != null || widget.onLongPress != null) {
      child = GestureDetector(
      behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: child,
      );
    }

    return child;
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle Enter/Space for activation
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        if (widget.onTap != null) {
          widget.onTap!();
          return KeyEventResult.handled;
        }
      }

      // Handle arrow keys for navigation
      if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        FocusScope.of(context).nextFocus();
        return KeyEventResult.handled;
      }

      if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        FocusScope.of(context).previousFocus();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}

/// Enhanced button with accessibility features
class AccessibleButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final String? hint;
  final ButtonStyle? style;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.hint,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService();

    return AccessibilityWidget(
      semanticLabel: accessibilityService.getSemanticLabel(semanticLabel),
      hint: hint,
      onTap: onPressed,
      child: ElevatedButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

/// Enhanced text field with accessibility features
class AccessibleTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String semanticLabel;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  const AccessibleTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    required this.semanticLabel,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService();

    return AccessibilityWidget(
      semanticLabel: accessibilityService.getSemanticLabel(semanticLabel),
      hint: hintText,
      onTap: onTap,
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: labelText, hintText: hintText),
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onTap: onTap,
      ),
    );
  }
}

/// Enhanced card with accessibility features
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final String semanticLabel;
  final String? hint;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  const AccessibleCard({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.hint,
    this.onTap,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService();

    return AccessibilityWidget(
      semanticLabel: accessibilityService.getSemanticLabel(semanticLabel),
      hint: hint,
      onTap: onTap,
      child: Card(
        margin: margin,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16.0),
          child: child,
        ),
      ),
    );
  }
}
