import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';
import '../widgets/animations/app_animations.dart';
// import '../services/optimistic/temple_optimistic_service.dart'; // Removed - unused service
import 'performance/build_optimization_mixin.dart';

/// An animated text form field with smooth focus transitions and validation feedback
class AnimatedFormField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String?)? onSaved;
  final void Function()? onTap;
  final bool readOnly;
  final int? maxLines;
  final int? minLines;
  final bool enableHapticFeedback;
  final Duration animationDuration;
  final Color? focusedBorderColor;
  final Color? errorBorderColor;
  final Color? enabledBorderColor;
  final String? entityId;
  final String? entityType;
  final bool showOptimisticFeedback;

  const AnimatedFormField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onTap,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.enableHapticFeedback = true,
    this.animationDuration = AppAnimations.normalDuration,
    this.focusedBorderColor,
    this.errorBorderColor,
    this.enabledBorderColor,
    this.entityId,
    this.entityType,
    this.showOptimisticFeedback = false,
  });

  @override
  State<AnimatedFormField> createState() => _AnimatedFormFieldState();
}

class _AnimatedFormFieldState extends State<AnimatedFormField>
    with TickerProviderStateMixin, BuildOptimizationMixin<AnimatedFormField> {
  AnimationController? _focusController;
  AnimationController? _errorController;
  late Animation<double> _focusAnimation;
  late Animation<double> _errorAnimation;
  late Animation<Color?> _borderColorAnimation;

  final FocusNode _focusNode = FocusNode();

  bool _hasError = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);


  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _focusController ??= AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _errorController ??= AnimationController(
      duration: AppAnimations.fastDuration,
      vsync: this,
    );

    _focusAnimation = CurvedAnimation(
      parent: _focusController!,
      curve: AppAnimations.defaultCurve,
    );
    _errorAnimation = CurvedAnimation(
      parent: _errorController!,
      curve: AppAnimations.errorCurve,
    );

    // Cache the border color animation to avoid recreating it in build()
    _borderColorAnimation = computeOnce(
      'borderColorAnimation',
      () => ColorTween(
        begin: widget.enabledBorderColor ?? Colors.grey,
        end: widget.focusedBorderColor ?? Theme.of(context).primaryColor,
      ).animate(_focusAnimation),
      dependencies: [widget.enabledBorderColor, widget.focusedBorderColor],
    );
  }

  @override
  void dispose() {
    _focusController?.dispose();
    _errorController?.dispose();
    _focusNode.dispose();



    super.dispose();
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      _focusController?.forward();
      if (widget.enableHapticFeedback) {
        _triggerHapticFeedback();
      }
    } else {
      _focusController?.reverse();
    }
  }

  Future<void> _triggerHapticFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _showError(String? errorText) {
    final oldHasError = _hasError;
    final oldErrorText = _errorText;

    setState(() {
      _hasError = errorText != null;
      _errorText = errorText;
    });

    // Invalidate cache if error state changed
    if (oldHasError != _hasError || oldErrorText != _errorText) {
      invalidateCache('inputDecoration');
      invalidateCache('errorWidget');
    }

    if (_hasError) {
      _errorController?.forward();
      if (widget.enableHapticFeedback) {
        _triggerErrorHapticFeedback();
      }
    } else {
      _errorController?.reverse();
    }
  }

  String? _validateInput(String? value) {
    final error = widget.validator?.call(value);
    _showError(error);
    return error;
  }





  InputDecoration _buildInputDecoration() {
    return InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      helperText: widget.helperText,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _hasError
              ? (widget.errorBorderColor ?? Colors.red)
              : (widget.enabledBorderColor ?? Colors.grey),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _hasError
              ? (widget.errorBorderColor ?? Colors.red)
              : (widget.enabledBorderColor ?? Colors.grey),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: _hasError
              ? (widget.errorBorderColor ?? Colors.red)
              : (_borderColorAnimation.value ?? Theme.of(context).primaryColor),
          width: 2.0,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: widget.errorBorderColor ?? Colors.red,
          width: 2.0,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: widget.errorBorderColor ?? Colors.red,
          width: 2.0,
        ),
      ),
    );
  }

  BoxDecoration _buildContainerDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      boxShadow: _focusAnimation.value > 0
          ? [
              BoxShadow(
                color:
                    (widget.focusedBorderColor ??
                            Theme.of(context).primaryColor)
                        .withValues(alpha: 0.2 * _focusAnimation.value),
                blurRadius: 8 * _focusAnimation.value,
                spreadRadius: 2 * _focusAnimation.value,
              ),
            ]
          : null,
    );
  }

  Widget _buildErrorWidget() {
    return AnimatedContainer(
      duration: AppAnimations.fastDuration,
      curve: AppAnimations.errorCurve,
      height: _errorAnimation.value * 20,
      child: Transform.translate(
        offset: Offset(0, -5 + (5 * _errorAnimation.value)),
        child: Opacity(
          opacity: _errorAnimation.value,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(
              _errorText!,
              style: TextStyle(
                color: widget.errorBorderColor ?? Colors.red,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _triggerErrorHapticFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 200);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_focusAnimation, _errorAnimation]),
      builder: (context, child) {
        // Cache expensive computations
        final inputDecoration = computeOnce(
          'inputDecoration',
          () => _buildInputDecoration(),
          dependencies: [
            widget.labelText,
            widget.hintText,
            widget.helperText,
            widget.prefixIcon,
            widget.suffixIcon,
            widget.showOptimisticFeedback,
            widget.entityId,
            widget.errorBorderColor,
            widget.enabledBorderColor,
            _hasError,
            _borderColorAnimation.value,
          ],
        );

        final containerDecoration = computeOnce(
          'containerDecoration',
          () => _buildContainerDecoration(),
          dependencies: [_focusAnimation.value, widget.focusedBorderColor],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: 1.0 + (_focusAnimation.value * 0.02),
              child: Container(
                decoration: containerDecoration,
                child: TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  validator: _validateInput,
                  onChanged: widget.onChanged,
                  onSaved: widget.onSaved,
                  onTap: widget.onTap,
                  readOnly: widget.readOnly,
                  maxLines: widget.maxLines,
                  minLines: widget.minLines,
                  decoration: inputDecoration,
                ),
              ),
            ),
            if (_hasError && _errorText != null)
              buildOnce(
                'errorWidget',
                () => _buildErrorWidget(),
                dependencies: [
                  _errorText,
                  _errorAnimation.value,
                  widget.errorBorderColor,
                ],
              ),
          ],
        );
      },
    );
  }
}

/// An animated dropdown form field with smooth transitions
class AnimatedDropdownField<T> extends StatefulWidget {
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final String? labelText;
  final String? hintText;
  final Widget? prefixIcon;
  final void Function(T?)? onChanged;
  final String? Function(T?)? validator;
  final bool enableHapticFeedback;
  final Duration animationDuration;

  const AnimatedDropdownField({
    super.key,
    this.value,
    required this.items,
    this.labelText,
    this.hintText,
    this.prefixIcon,
    this.onChanged,
    this.validator,
    this.enableHapticFeedback = true,
    this.animationDuration = AppAnimations.normalDuration,
  });

  @override
  State<AnimatedDropdownField<T>> createState() =>
      _AnimatedDropdownFieldState<T>();
}

class _AnimatedDropdownFieldState<T> extends State<AnimatedDropdownField<T>>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.interactionCurve,
      ),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: AppAnimations.defaultCurve,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    if (widget.enableHapticFeedback) {
      _triggerDropdownHapticFeedback();
    }
  }

  Future<void> _triggerDropdownHapticFeedback() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 50);
    } else {
      HapticFeedback.selectionClick();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: DropdownButtonFormField<T>(
            value: widget.value,
            items: widget.items,
            onChanged: (value) {
              _handleTap();
              widget.onChanged?.call(value);
            },
            validator: widget.validator,
            decoration: InputDecoration(
              labelText: widget.labelText,
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon,
              suffixIcon: Transform.rotate(
                angle: _rotationAnimation.value * 3.14159,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.grey),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).primaryColor,
                  width: 2.0,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
