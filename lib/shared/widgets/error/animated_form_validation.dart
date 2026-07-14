import 'package:flutter/material.dart';
import '../animations/app_animations.dart';
import '../animations/micro_animations.dart';

/// Animated form field with validation feedback and smooth transitions
class AnimatedFormField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? errorText;
  final bool hasError;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconPressed;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final EdgeInsets? contentPadding;
  final InputBorder? border;
  final Color? fillColor;
  final bool filled;

  const AnimatedFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.errorText,
    this.hasError = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixIconPressed,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.contentPadding,
    this.border,
    this.fillColor,
    this.filled = true,
  });

  @override
  State<AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<AnimatedFormField>
    with TickerProviderStateMixin {
  late AnimationController _errorController;
  late AnimationController _focusController;
  late AnimationController _shakeController;

  late Animation<double> _errorHeightAnimation;
  late Animation<double> _errorOpacityAnimation;
  late Animation<double> _shakeAnimation;

  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _wasError = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupFocusListener();
  }

  void _initializeAnimations() {
    // Error animation controller
    _errorController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    // Focus animation controller
    _focusController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    // Shake animation controller
    _shakeController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    // Error animations
    _errorHeightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _errorOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _errorController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    // Shake animation
    _shakeAnimation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _setupFocusListener() {
    _focusNode.addListener(() {
      if (_focusNode.hasFocus != _isFocused) {
        setState(() {
          _isFocused = _focusNode.hasFocus;
        });

        if (_isFocused) {
          _focusController.forward();
        } else {
          _focusController.reverse();
        }
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedFormField oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle error state changes
    if (widget.hasError != oldWidget.hasError) {
      if (widget.hasError) {
        _errorController.forward();
        _focusController.forward();
        if (!_wasError) {
          _triggerShakeAnimation();
        }
      } else {
        _errorController.reverse();
        if (!_isFocused) {
          _focusController.reverse();
        }
      }
      _wasError = widget.hasError;
    }
  }

  Future<void> _triggerShakeAnimation() async {
    await MicroAnimations.triggerHapticFeedback(HapticFeedbackType.error);
    _shakeController.forward().then((_) => _shakeController.reset());
  }

  @override
  void dispose() {
    _errorController.dispose();
    _focusController.dispose();
    _shakeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Color get _currentBorderColor {
    if (widget.hasError) {
      return const Color(0xFFEF4444);
    } else if (_isFocused) {
      return const Color(0xFFFF7A00);
    } else {
      return const Color(0xFFE5E7EB);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value * 4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Text Field
              AnimatedBuilder(
                animation: _focusController,
                builder: (context, child) {
                  return AnimatedContainer(
                    duration: AppAnimations.fastDuration,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _currentBorderColor,
                        width: _isFocused || widget.hasError ? 2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focusNode,
                      keyboardType: widget.keyboardType,
                      obscureText: widget.obscureText,
                      maxLines: widget.maxLines,
                      minLines: widget.minLines,
                      onChanged: widget.onChanged,
                      onTap: widget.onTap,
                      readOnly: widget.readOnly,
                      decoration: InputDecoration(
                        labelText: widget.labelText,
                        hintText: widget.hintText,
                        prefixIcon: widget.prefixIcon != null
                            ? Icon(
                                widget.prefixIcon,
                                color: widget.hasError
                                    ? const Color(0xFFEF4444)
                                    : _isFocused
                                    ? const Color(0xFFFF7A00)
                                    : const Color(0xFF6B7280),
                              )
                            : null,
                        suffixIcon: widget.suffixIcon != null
                            ? IconButton(
                                icon: Icon(
                                  widget.suffixIcon,
                                  color: widget.hasError
                                      ? const Color(0xFFEF4444)
                                      : _isFocused
                                      ? const Color(0xFFFF7A00)
                                      : const Color(0xFF6B7280),
                                ),
                                onPressed: widget.onSuffixIconPressed,
                              )
                            : null,
                        contentPadding:
                            widget.contentPadding ??
                            const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        filled: widget.filled,
                        fillColor: widget.fillColor ?? Colors.grey[50],
                        labelStyle: TextStyle(
                          color: widget.hasError
                              ? const Color(0xFFEF4444)
                              : _isFocused
                              ? const Color(0xFFFF7A00)
                              : const Color(0xFF6B7280),
                        ),
                        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  );
                },
              ),

              // Animated Error Message
              AnimatedBuilder(
                animation: _errorController,
                builder: (context, child) {
                  return ClipRect(
                    child: Align(
                      alignment: Alignment.topLeft,
                      heightFactor: _errorHeightAnimation.value,
                      child: Opacity(
                        opacity: _errorOpacityAnimation.value,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8, left: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Color(0xFFEF4444),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.errorText ?? 'This field has an error',
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Animated validation message that can be used independently
class AnimatedValidationMessage extends StatefulWidget {
  final String message;
  final bool isVisible;
  final ValidationMessageType type;
  final IconData? icon;

  const AnimatedValidationMessage({
    super.key,
    required this.message,
    required this.isVisible,
    this.type = ValidationMessageType.error,
    this.icon,
  });

  @override
  State<AnimatedValidationMessage> createState() =>
      _AnimatedValidationMessageState();
}

class _AnimatedValidationMessageState extends State<AnimatedValidationMessage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _heightAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: AppAnimations.defaultCurve),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppAnimations.defaultCurve,
          ),
        );
  }

  @override
  void didUpdateWidget(AnimatedValidationMessage oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _messageColor {
    switch (widget.type) {
      case ValidationMessageType.error:
        return const Color(0xFFEF4444);
      case ValidationMessageType.warning:
        return const Color(0xFFF59E0B);
      case ValidationMessageType.success:
        return const Color(0xFF10B981);
      case ValidationMessageType.info:
        return const Color(0xFFFF7A00);
    }
  }

  IconData get _defaultIcon {
    if (widget.icon != null) return widget.icon!;

    switch (widget.type) {
      case ValidationMessageType.error:
        return Icons.error_outline;
      case ValidationMessageType.warning:
        return Icons.warning_amber_outlined;
      case ValidationMessageType.success:
        return Icons.check_circle_outline;
      case ValidationMessageType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ClipRect(
          child: Align(
            alignment: Alignment.topLeft,
            heightFactor: _heightAnimation.value,
            child: SlideTransition(
              position: _slideAnimation,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(_defaultIcon, color: _messageColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.message,
                          style: TextStyle(
                            color: _messageColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Types of validation messages
enum ValidationMessageType { error, warning, success, info }
