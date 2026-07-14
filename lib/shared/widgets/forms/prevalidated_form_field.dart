import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../shared/widgets/animations/app_animations.dart';

/// Validation result for form fields
class ValidationResult {
  final bool isValid;
  final String? errorMessage;
  final String? successMessage;
  final ValidationSeverity severity;

  const ValidationResult({
    required this.isValid,
    this.errorMessage,
    this.successMessage,
    this.severity = ValidationSeverity.error,
  });

  const ValidationResult.valid({this.successMessage})
    : isValid = true,
      errorMessage = null,
      severity = ValidationSeverity.success;

  const ValidationResult.invalid(
    this.errorMessage, {
    this.severity = ValidationSeverity.error,
  }) : isValid = false,
       successMessage = null;

  const ValidationResult.warning(this.errorMessage)
    : isValid = true,
      successMessage = null,
      severity = ValidationSeverity.warning;
}

/// Validation severity levels
enum ValidationSeverity { error, warning, info, success }

/// Validation mode for form fields
enum ValidationMode {
  onSubmit, // Validate only when form is submitted
  onChange, // Validate on every change
  onFocusLost, // Validate when field loses focus
  realTime, // Validate with debouncing
}

/// Pre-validated form field with real-time feedback
class PrevalidatedFormField extends StatefulWidget {
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final ValidationMode validationMode;
  final Duration validationDelay;
  final Future<ValidationResult> Function(String value)? validator;
  final List<ValidationResult Function(String value)> syncValidators;
  final void Function(String value)? onChanged;
  final void Function(String value)? onSubmitted;
  final void Function()? onTap;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final bool showValidationIcon;
  final bool showValidationMessage;
  final EdgeInsetsGeometry? contentPadding;
  final InputBorder? border;
  final Color? fillColor;
  final bool filled;

  const PrevalidatedFormField({
    super.key,
    this.initialValue,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.validationMode = ValidationMode.realTime,
    this.validationDelay = const Duration(milliseconds: 500),
    this.validator,
    this.syncValidators = const [],
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.controller,
    this.focusNode,
    this.showValidationIcon = true,
    this.showValidationMessage = true,
    this.contentPadding,
    this.border,
    this.fillColor,
    this.filled = true,
  });

  @override
  State<PrevalidatedFormField> createState() => _PrevalidatedFormFieldState();
}

class _PrevalidatedFormFieldState extends State<PrevalidatedFormField>
    with TickerProviderStateMixin {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late AnimationController _validationController;
  late AnimationController _iconController;
  late Animation<double> _validationAnimation;
  late Animation<double> _iconAnimation;
  late Animation<Color?> _borderColorAnimation;

  ValidationResult? _currentValidation;
  Timer? _validationTimer;
  bool _isValidating = false;
  bool _hasBeenFocused = false;

  @override
  void initState() {
    super.initState();

    _controller =
        widget.controller ?? TextEditingController(text: widget.initialValue);
    _focusNode = widget.focusNode ?? FocusNode();

    _validationController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    _iconController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    _validationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _validationController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: AppAnimations.interactionCurve,
      ),
    );

    _borderColorAnimation = ColorTween(
      begin: Colors.grey[300],
      end: Colors.grey[300],
    ).animate(_validationController);

    _focusNode.addListener(_onFocusChanged);
    _controller.addListener(_onTextChanged);

    // Initial validation if there's initial value
    if (widget.initialValue?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateField(_controller.text);
      });
    }
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _validationController.dispose();
    _iconController.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _controller.removeListener(_onTextChanged);

    if (widget.controller == null) {
      _controller.dispose();
    }
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }

    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _hasBeenFocused = true;
    } else if (_hasBeenFocused &&
        widget.validationMode == ValidationMode.onFocusLost) {
      _validateField(_controller.text);
    }
  }

  void _onTextChanged() {
    final text = _controller.text;
    widget.onChanged?.call(text);

    switch (widget.validationMode) {
      case ValidationMode.onChange:
        _validateField(text);
        break;
      case ValidationMode.realTime:
        _scheduleValidation(text);
        break;
      case ValidationMode.onSubmit:
      case ValidationMode.onFocusLost:
        // Only validate if there was a previous validation result
        if (_currentValidation != null) {
          _scheduleValidation(text);
        }
        break;
    }
  }

  void _scheduleValidation(String text) {
    _validationTimer?.cancel();
    _validationTimer = Timer(widget.validationDelay, () {
      _validateField(text);
    });
  }

  Future<void> _validateField(String text) async {
    if (!mounted) return;

    setState(() {
      _isValidating = true;
    });

    try {
      // Run synchronous validators first
      for (final syncValidator in widget.syncValidators) {
        final result = syncValidator(text);
        if (!result.isValid) {
          _setValidationResult(result);
          return;
        }
      }

      // Run async validator if provided
      if (widget.validator != null) {
        final result = await widget.validator!(text);
        if (mounted) {
          _setValidationResult(result);
        }
      } else {
        // No validators, consider valid
        _setValidationResult(const ValidationResult.valid());
      }
    } catch (e) {
      if (mounted) {
        _setValidationResult(ValidationResult.invalid('Validation error: $e'));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isValidating = false;
        });
      }
    }
  }

  void _setValidationResult(ValidationResult result) {
    setState(() {
      _currentValidation = result;
    });

    // Update animations based on validation result
    _updateValidationAnimations(result);
  }

  void _updateValidationAnimations(ValidationResult result) {
    // Update border color animation
    Color targetColor;
    switch (result.severity) {
      case ValidationSeverity.error:
        targetColor = Colors.red;
        break;
      case ValidationSeverity.warning:
        targetColor = Colors.orange;
        break;
      case ValidationSeverity.info:
        targetColor = Colors.orange;
        break;
      case ValidationSeverity.success:
        targetColor = Colors.green;
        break;
    }

    _borderColorAnimation = ColorTween(
      begin: _borderColorAnimation.value,
      end: targetColor,
    ).animate(_validationController);

    _validationController.forward();

    if (result.isValid) {
      _iconController.forward();
    } else {
      _iconController.reverse();
    }
  }

  /// Manually trigger validation (useful for form submission)
  Future<ValidationResult?> validate() async {
    await _validateField(_controller.text);
    return _currentValidation;
  }

  /// Clear validation state
  void clearValidation() {
    setState(() {
      _currentValidation = null;
    });
    _validationController.reset();
    _iconController.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedBuilder(
          animation: _borderColorAnimation,
          builder: (context, child) {
            return TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              obscureText: widget.obscureText,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              enabled: widget.enabled,
              readOnly: widget.readOnly,
              onTap: widget.onTap,
              onFieldSubmitted: widget.onSubmitted,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon != null
                    ? Icon(widget.prefixIcon)
                    : null,
                suffixIcon: _buildSuffixIcon(),
                contentPadding: widget.contentPadding,
                border: widget.border ?? _buildBorder(),
                enabledBorder: _buildBorder(),
                focusedBorder: _buildBorder(focused: true),
                errorBorder: _buildBorder(error: true),
                focusedErrorBorder: _buildBorder(focused: true, error: true),
                fillColor: widget.fillColor ?? Colors.grey[50],
                filled: widget.filled,
                counterText: '', // Hide character counter
              ),
            );
          },
        ),

        // Validation message
        if (widget.showValidationMessage)
          AnimatedBuilder(
            animation: _validationAnimation,
            builder: (context, child) {
              return AnimatedContainer(
                duration: AppAnimations.fastDuration,
                height: _currentValidation != null ? 24.0 : 0.0,
                child: AnimatedOpacity(
                  opacity: _validationAnimation.value,
                  duration: AppAnimations.fastDuration,
                  child: _buildValidationMessage(),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget? _buildSuffixIcon() {
    if (!widget.showValidationIcon) {
      return widget.suffixIcon;
    }

    Widget? validationIcon;

    if (_isValidating) {
      validationIcon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_currentValidation != null) {
      IconData iconData;
      Color iconColor;

      switch (_currentValidation!.severity) {
        case ValidationSeverity.error:
          iconData = Icons.error;
          iconColor = Colors.red;
          break;
        case ValidationSeverity.warning:
          iconData = Icons.warning;
          iconColor = Colors.orange;
          break;
        case ValidationSeverity.info:
          iconData = Icons.info;
          iconColor = Colors.orange;
          break;
        case ValidationSeverity.success:
          iconData = Icons.check_circle;
          iconColor = Colors.green;
          break;
      }

      validationIcon = AnimatedBuilder(
        animation: _iconAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _iconAnimation.value,
            child: Icon(iconData, color: iconColor, size: 20),
          );
        },
      );
    }

    if (validationIcon != null && widget.suffixIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          validationIcon,
          const SizedBox(width: 8),
          widget.suffixIcon!,
        ],
      );
    }

    return validationIcon ?? widget.suffixIcon;
  }

  Widget _buildValidationMessage() {
    if (_currentValidation == null) {
      return const SizedBox.shrink();
    }

    final message = _currentValidation!.isValid
        ? _currentValidation!.successMessage
        : _currentValidation!.errorMessage;

    if (message == null) {
      return const SizedBox.shrink();
    }

    Color textColor;
    switch (_currentValidation!.severity) {
      case ValidationSeverity.error:
        textColor = Colors.red;
        break;
      case ValidationSeverity.warning:
        textColor = Colors.orange;
        break;
      case ValidationSeverity.info:
        textColor = Colors.orange;
        break;
      case ValidationSeverity.success:
        textColor = Colors.green;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, left: 12.0),
      child: Text(message, style: TextStyle(color: textColor, fontSize: 12)),
    );
  }

  InputBorder _buildBorder({bool focused = false, bool error = false}) {
    Color borderColor;

    if (error && _currentValidation?.severity == ValidationSeverity.error) {
      borderColor = Colors.red;
    } else if (focused) {
      borderColor =
          _borderColorAnimation.value ?? Theme.of(context).primaryColor;
    } else {
      borderColor = _borderColorAnimation.value ?? Colors.grey[300]!;
    }

    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
      borderSide: BorderSide(color: borderColor, width: focused ? 2.0 : 1.0),
    );
  }
}

/// Common validators for form fields
class FormValidators {
  /// Email validation
  static ValidationResult validateEmail(String value) {
    if (value.isEmpty) {
      return const ValidationResult.invalid('Email is required');
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return const ValidationResult.invalid(
        'Please enter a valid email address',
      );
    }

    return const ValidationResult.valid(successMessage: 'Valid email address');
  }

  /// Password validation
  static ValidationResult validatePassword(String value) {
    if (value.isEmpty) {
      return const ValidationResult.invalid('Password is required');
    }

    if (value.length < 8) {
      return const ValidationResult.invalid(
        'Password must be at least 8 characters',
      );
    }

    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(value)) {
      return const ValidationResult.warning(
        'Password should contain uppercase, lowercase, and numbers',
      );
    }

    return const ValidationResult.valid(successMessage: 'Strong password');
  }

  /// Required field validation
  static ValidationResult validateRequired(String value, {String? fieldName}) {
    if (value.trim().isEmpty) {
      return ValidationResult.invalid(
        '${fieldName ?? 'This field'} is required',
      );
    }
    return const ValidationResult.valid();
  }

  /// Phone number validation
  static ValidationResult validatePhone(String value) {
    if (value.isEmpty) {
      return const ValidationResult.invalid('Phone number is required');
    }

    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]{10,}$');
    if (!phoneRegex.hasMatch(value)) {
      return const ValidationResult.invalid(
        'Please enter a valid phone number',
      );
    }

    return const ValidationResult.valid(successMessage: 'Valid phone number');
  }

  /// URL validation
  static ValidationResult validateUrl(String value) {
    if (value.isEmpty) {
      return const ValidationResult.valid(); // Optional field
    }

    try {
      final uri = Uri.parse(value);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        return const ValidationResult.invalid('Please enter a valid URL');
      }
    } catch (e) {
      return const ValidationResult.invalid('Please enter a valid URL');
    }

    return const ValidationResult.valid(successMessage: 'Valid URL');
  }
}
