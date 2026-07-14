import 'dart:async';
import 'package:flutter/material.dart';
import '../animations/app_animations.dart';
import 'prevalidated_form_field.dart';

/// Form configuration for pre-validation behavior
class PrevalidatedFormConfig {
  final ValidationMode defaultValidationMode;
  final Duration validationDelay;
  final bool enableRealTimeFeedback;
  final bool enableProgressIndicator;
  final bool enableAutoSave;
  final Duration autoSaveDelay;
  final bool showValidationSummary;

  const PrevalidatedFormConfig({
    this.defaultValidationMode = ValidationMode.realTime,
    this.validationDelay = const Duration(milliseconds: 500),
    this.enableRealTimeFeedback = true,
    this.enableProgressIndicator = true,
    this.enableAutoSave = false,
    this.autoSaveDelay = const Duration(seconds: 2),
    this.showValidationSummary = true,
  });
}

/// Enhanced form with pre-validation and real-time feedback
class PrevalidatedForm extends StatefulWidget {
  final GlobalKey<FormState>? formKey;
  final List<Widget> children;
  final PrevalidatedFormConfig config;
  final void Function(Map<String, dynamic> formData)? onChanged;
  final void Function(Map<String, dynamic> formData)? onAutoSave;
  final Future<bool> Function(Map<String, dynamic> formData)? onSubmit;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;
  final MainAxisAlignment mainAxisAlignment;
  final MainAxisSize mainAxisSize;

  const PrevalidatedForm({
    super.key,
    this.formKey,
    required this.children,
    this.config = const PrevalidatedFormConfig(),
    this.onChanged,
    this.onAutoSave,
    this.onSubmit,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.mainAxisSize = MainAxisSize.max,
  });

  @override
  State<PrevalidatedForm> createState() => _PrevalidatedFormState();
}

class _PrevalidatedFormState extends State<PrevalidatedForm>
    with TickerProviderStateMixin {
  late GlobalKey<FormState> _formKey;
  late AnimationController _progressController;
  late AnimationController _summaryController;
  late Animation<double> _progressAnimation;
  late Animation<double> _summaryAnimation;

  final Map<String, dynamic> _formData = {};
  final Map<String, ValidationResult?> _fieldValidations = {};
  Timer? _autoSaveTimer;
  Timer? _changeTimer;

  bool _isSubmitting = false;
  double _validationProgress = 0.0;
  int _validFieldCount = 0;
  int _totalFieldCount = 0;

  @override
  void initState() {
    super.initState();

    _formKey = widget.formKey ?? GlobalKey<FormState>();

    _progressController = AnimationController(
      duration: AppAnimations.normalDuration,
      vsync: this,
    );

    _summaryController = AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _progressController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    _summaryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _summaryController,
        curve: AppAnimations.defaultCurve,
      ),
    );

    // Count total fields
    _countFormFields();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _changeTimer?.cancel();
    _progressController.dispose();
    _summaryController.dispose();
    super.dispose();
  }

  /// Count the total number of form fields
  void _countFormFields() {
    int count = 0;

    void countInWidget(Widget widget) {
      if (widget is PrevalidatedFormField) {
        count++;
      } else if (widget is Column || widget is Row) {
        // Handle common layout widgets
        if (widget is Column) {
          for (final child in widget.children) {
            countInWidget(child);
          }
        } else if (widget is Row) {
          for (final child in widget.children) {
            countInWidget(child);
          }
        }
      }
    }

    for (final child in widget.children) {
      countInWidget(child);
    }

    setState(() {
      _totalFieldCount = count;
    });
  }

  /// Handle field value changes
  void _onFieldChanged(
    String fieldName,
    String value,
    ValidationResult? validation,
  ) {
    setState(() {
      _formData[fieldName] = value;
      _fieldValidations[fieldName] = validation;
    });

    _updateValidationProgress();

    // Notify parent of changes
    widget.onChanged?.call(Map.from(_formData));

    // Schedule auto-save if enabled
    if (widget.config.enableAutoSave) {
      _scheduleAutoSave();
    }

    // Update validation summary
    if (widget.config.showValidationSummary) {
      _updateValidationSummary();
    }
  }

  /// Update validation progress
  void _updateValidationProgress() {
    int validCount = 0;

    for (final validation in _fieldValidations.values) {
      if (validation?.isValid == true) {
        validCount++;
      }
    }

    setState(() {
      _validFieldCount = validCount;
      _validationProgress = _totalFieldCount > 0
          ? validCount / _totalFieldCount
          : 0.0;
    });

    if (widget.config.enableProgressIndicator) {
      _progressController.animateTo(_validationProgress);
    }
  }

  /// Update validation summary animation
  void _updateValidationSummary() {
    if (_fieldValidations.isNotEmpty) {
      _summaryController.forward();
    } else {
      _summaryController.reverse();
    }
  }

  /// Schedule auto-save
  void _scheduleAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(widget.config.autoSaveDelay, () {
      widget.onAutoSave?.call(Map.from(_formData));
    });
  }

  /// Submit the form
  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // Validate all fields
      final isValid = _formKey.currentState?.validate() ?? false;

      if (isValid && widget.onSubmit != null) {
        final success = await widget.onSubmit!(_formData);

        if (success) {
          // Form submitted successfully
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Form submitted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting form: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: widget.crossAxisAlignment,
        mainAxisAlignment: widget.mainAxisAlignment,
        mainAxisSize: widget.mainAxisSize,
        children: [
          // Progress indicator
          if (widget.config.enableProgressIndicator) _buildProgressIndicator(),

          // Form content
          Padding(
            padding: widget.padding ?? EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: widget.crossAxisAlignment,
              mainAxisAlignment: widget.mainAxisAlignment,
              mainAxisSize: widget.mainAxisSize,
              children: _buildEnhancedChildren(),
            ),
          ),

          // Validation summary
          if (widget.config.showValidationSummary) _buildValidationSummary(),

          // Submit button (if onSubmit is provided)
          if (widget.onSubmit != null)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Build progress indicator
  Widget _buildProgressIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Form Progress',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    '$_validFieldCount/$_totalFieldCount fields valid',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _validationProgress == 1.0
                          ? Colors.green
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: _progressAnimation.value,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _validationProgress == 1.0 ? Colors.green : Colors.orange,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Build enhanced children with field tracking
  List<Widget> _buildEnhancedChildren() {
    return widget.children.map((child) {
      if (child is PrevalidatedFormField) {
        // Wrap PrevalidatedFormField to track changes
        return _wrapFormField(child);
      }
      return child;
    }).toList();
  }

  /// Wrap form field to track changes
  Widget _wrapFormField(PrevalidatedFormField field) {
    // Generate a unique key for the field
    final fieldKey =
        field.labelText ?? field.hintText ?? 'field_${field.hashCode}';

    return PrevalidatedFormField(
      key: field.key,
      initialValue: field.initialValue,
      labelText: field.labelText,
      hintText: field.hintText,
      prefixIcon: field.prefixIcon,
      suffixIcon: field.suffixIcon,
      keyboardType: field.keyboardType,
      inputFormatters: field.inputFormatters,
      obscureText: field.obscureText,
      maxLines: field.maxLines,
      maxLength: field.maxLength,
      enabled: field.enabled,
      readOnly: field.readOnly,
      validationMode: field.validationMode,
      validationDelay: field.validationDelay,
      validator: field.validator,
      syncValidators: field.syncValidators,
      controller: field.controller,
      focusNode: field.focusNode,
      showValidationIcon: field.showValidationIcon,
      showValidationMessage: field.showValidationMessage,
      contentPadding: field.contentPadding,
      border: field.border,
      fillColor: field.fillColor,
      filled: field.filled,
      onChanged: (value) {
        field.onChanged?.call(value);
        // Track the change for form-level validation
        _changeTimer?.cancel();
        _changeTimer = Timer(const Duration(milliseconds: 100), () {
          // Get validation result from the field
          // This is a simplified approach - in a real implementation,
          // you might want to access the field's validation state directly
          _onFieldChanged(fieldKey, value, null);
        });
      },
      onSubmitted: field.onSubmitted,
      onTap: field.onTap,
    );
  }

  /// Build validation summary
  Widget _buildValidationSummary() {
    return AnimatedBuilder(
      animation: _summaryAnimation,
      builder: (context, child) {
        if (_summaryAnimation.value == 0.0) {
          return const SizedBox.shrink();
        }

        final errorCount = _fieldValidations.values
            .where((v) => v != null && !v.isValid)
            .length;

        final warningCount = _fieldValidations.values
            .where(
              (v) =>
                  v != null &&
                  v.isValid &&
                  v.severity == ValidationSeverity.warning,
            )
            .length;

        if (errorCount == 0 && warningCount == 0) {
          return const SizedBox.shrink();
        }

        return Opacity(
          opacity: _summaryAnimation.value,
          child: Container(
            margin: const EdgeInsets.only(top: 16.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: errorCount > 0 ? Colors.red[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: errorCount > 0 ? Colors.red[200]! : Colors.orange[200]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      errorCount > 0 ? Icons.error : Icons.warning,
                      color: errorCount > 0 ? Colors.red : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      errorCount > 0
                          ? 'Please fix $errorCount error${errorCount > 1 ? 's' : ''}'
                          : '$warningCount warning${warningCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        color: errorCount > 0
                            ? Colors.red[700]
                            : Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Enhanced form field wrapper that integrates with PrevalidatedForm
class FormFieldWrapper extends StatelessWidget {
  final String fieldName;
  final PrevalidatedFormField child;
  final void Function(
    String fieldName,
    String value,
    ValidationResult? validation,
  )?
  onFieldChanged;

  const FormFieldWrapper({
    super.key,
    required this.fieldName,
    required this.child,
    this.onFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
