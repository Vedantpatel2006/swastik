import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/accessibility_service.dart';

/// Accessible text field with proper semantic labels and keyboard navigation
class AccessibleTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? semanticLabel;
  final String? helperText;
  final String? errorText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? maxLength;
  final bool autofocus;
  final FocusNode? focusNode;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final bool readOnly;

  const AccessibleTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.semanticLabel,
    this.helperText,
    this.errorText,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.readOnly = false,
  });

  @override
  State<AccessibleTextField> createState() => _AccessibleTextFieldState();
}

class _AccessibleTextFieldState extends State<AccessibleTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_onFocusChange);
    }
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _hasFocus = _focusNode.hasFocus;
    });

    if (_hasFocus) {
      // Announce field label when focused for screen readers
      final label = widget.semanticLabel ?? widget.labelText ?? widget.hintText;
      if (label != null) {
        AccessibilityService.instance.announceToScreenReader('Editing $label');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;
    final isScreenReaderEnabled = accessibilityService.isScreenReaderEnabled;

    // Build semantic label
    String? semanticLabel = widget.semanticLabel ?? widget.labelText;
    if (widget.helperText != null) {
      semanticLabel = '$semanticLabel. ${widget.helperText}';
    }
    if (widget.errorText != null) {
      semanticLabel = '$semanticLabel. Error: ${widget.errorText}';
    }

    return Semantics(
      label: semanticLabel,
      textField: true,
      enabled: widget.enabled && !widget.readOnly,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
          obscureText: widget.obscureText,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          autofocus: widget.autofocus,
          enabled: widget.enabled,
          readOnly: widget.readOnly,
          inputFormatters: widget.inputFormatters,
          validator: widget.validator,
          onChanged: (value) {
            widget.onChanged?.call(value);

            // Provide feedback for screen readers on significant changes
            if (isScreenReaderEnabled &&
                value.isNotEmpty &&
                value.length % 10 == 0) {
              accessibilityService.announceToScreenReader(
                '${value.length} characters entered',
              );
            }
          },
          onFieldSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            helperText: widget.helperText,
            errorText: widget.errorText,
            prefixIcon: widget.prefixIcon,
            suffixIcon: widget.suffixIcon,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.error,
                width: 2,
              ),
            ),
            // Enhanced visual feedback for accessibility
            filled: _hasFocus,
            fillColor: _hasFocus
                ? Theme.of(context).primaryColor.withValues(alpha: 0.05)
                : null,
          ),
      ),
    );
  }
}

/// Accessible search field with voice input support
class AccessibleSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? semanticLabel;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final FocusNode? focusNode;
  final bool showVoiceInput;

  const AccessibleSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.semanticLabel,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.focusNode,
    this.showVoiceInput = false,
  });

  @override
  State<AccessibleSearchField> createState() => _AccessibleSearchFieldState();
}

class _AccessibleSearchFieldState extends State<AccessibleSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _clearSearch() {
    _controller.clear();
    widget.onClear?.call();
    AccessibilityService.instance.announceToScreenReader('Search cleared');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? 'Search field',
      textField: true,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        autofocus: widget.autofocus,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText ?? 'Search...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasText)
                Semantics(
                  label: 'Clear search',
                  button: true,
                  child: IconButton(
                    onPressed: _clearSearch,
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                  ),
                ),
              if (widget.showVoiceInput)
                Semantics(
                  label: 'Voice search',
                  button: true,
                  child: IconButton(
                    onPressed: () {
                      // Voice input functionality would be implemented here
                      AccessibilityService.instance.announceToScreenReader(
                        'Voice search not yet implemented',
                      );
                    },
                    icon: const Icon(Icons.mic),
                    tooltip: 'Voice search',
                  ),
                ),
            ],
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
