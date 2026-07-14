import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/themes/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/animations/transition_manager.dart';
import '../../../shared/widgets/error/index.dart';
import '../widgets/auth/google_sign_in_button.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _acceptedTerms = false;

  // Password strength
  double _passwordStrength = 0.0;
  String _passwordStrengthText = '';
  Color _passwordStrengthColor = Colors.grey;
  bool _hasStartedTypingPassword = false;

  // Password requirements
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  // Form validation states
  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
  bool _isLoading = false;

  // Debounce timers
  Timer? _nameDebounce;
  Timer? _emailDebounce;

  // Regex patterns (compiled once)
  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );
  static final _nameRegex = RegExp(r'^[a-zA-Z\s]+$');
  static final _lowercaseRegex = RegExp(r'[a-z]');
  static final _uppercaseRegex = RegExp(r'[A-Z]');
  static final _numberRegex = RegExp(r'[0-9]');
  static final _specialCharRegex = RegExp(r'[!@#$%^&*(),.?":{}|<>]');

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameDebounce?.cancel();
    _emailDebounce?.cancel();
    super.dispose();
  }

  void _validateName(String value) {
    // Cancel previous timer
    _nameDebounce?.cancel();

    // Debounce validation
    _nameDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final trimmedValue = value.trim();
      setState(() {
        if (trimmedValue.isEmpty) {
          _nameError = 'Please enter your name';
        } else if (trimmedValue.length < 2) {
          _nameError = 'Name must be at least 2 characters';
        } else if (!_nameRegex.hasMatch(trimmedValue)) {
          _nameError = 'Name can only contain letters and spaces';
        } else {
          _nameError = null;
        }
      });
    });
  }

  void _validateEmail(String value) {
    // Cancel previous timer
    _emailDebounce?.cancel();

    // Debounce validation
    _emailDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final lowercaseEmail = value.toLowerCase().trim();
      setState(() {
        if (lowercaseEmail.isEmpty) {
          _emailError = 'Please enter your email';
        } else if (!_emailRegex.hasMatch(lowercaseEmail)) {
          _emailError = 'Please enter a valid email';
        } else {
          _emailError = null;
        }
      });
    });
  }

  void _validatePassword(String value) {
    // Mark that user has started typing password
    if (value.isNotEmpty && !_hasStartedTypingPassword) {
      setState(() {
        _hasStartedTypingPassword = true;
      });
    }

    // Calculate password strength and requirements
    _calculatePasswordStrength(value);

    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Please enter a password';
      } else if (value.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });
    // Also validate confirm password if it has a value
    if (_confirmPasswordController.text.isNotEmpty) {
      _validateConfirmPassword(_confirmPasswordController.text);
    }
  }

  void _calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _passwordStrengthText = '';
        _passwordStrengthColor = Colors.grey;
        _hasMinLength = false;
        _hasUppercase = false;
        _hasLowercase = false;
        _hasNumber = false;
        _hasSpecialChar = false;
      });
      return;
    }

    double strength = 0.0;

    // Check requirements using pre-compiled regex
    final hasMinLength = password.length >= 6;
    final hasLowercase = _lowercaseRegex.hasMatch(password);
    final hasUppercase = _uppercaseRegex.hasMatch(password);
    final hasNumber = _numberRegex.hasMatch(password);
    final hasSpecialChar = _specialCharRegex.hasMatch(password);

    // Length check
    if (hasMinLength) strength += 0.2;
    if (password.length >= 8) strength += 0.1;
    if (password.length >= 12) strength += 0.1;

    // Contains lowercase
    if (hasLowercase) strength += 0.15;

    // Contains uppercase
    if (hasUppercase) strength += 0.15;

    // Contains numbers
    if (hasNumber) strength += 0.15;

    // Contains special characters
    if (hasSpecialChar) strength += 0.15;

    setState(() {
      _passwordStrength = strength;
      _hasMinLength = hasMinLength;
      _hasLowercase = hasLowercase;
      _hasUppercase = hasUppercase;
      _hasNumber = hasNumber;
      _hasSpecialChar = hasSpecialChar;

      if (strength <= 0.3) {
        _passwordStrengthText = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (strength <= 0.6) {
        _passwordStrengthText = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else if (strength <= 0.8) {
        _passwordStrengthText = 'Good';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrengthText = 'Strong';
        _passwordStrengthColor = Colors.green;
      }
    });
  }

  void _validateConfirmPassword(String value) {
    setState(() {
      if (value.isEmpty) {
        _confirmPasswordError = 'Please confirm your password';
      } else if (value != _passwordController.text) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  Future<void> _handleSignUp() async {
    // Cancel any pending debounce timers
    _nameDebounce?.cancel();
    _emailDebounce?.cancel();

    // Validate all fields immediately
    final trimmedName = _nameController.text.trim();
    final lowercaseEmail = _emailController.text.toLowerCase().trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // Immediate validation
    setState(() {
      if (trimmedName.isEmpty) {
        _nameError = 'Please enter your name';
      } else if (trimmedName.length < 2) {
        _nameError = 'Name must be at least 2 characters';
      } else if (!_nameRegex.hasMatch(trimmedName)) {
        _nameError = 'Name can only contain letters and spaces';
      } else {
        _nameError = null;
      }

      if (lowercaseEmail.isEmpty) {
        _emailError = 'Please enter your email';
      } else if (!_emailRegex.hasMatch(lowercaseEmail)) {
        _emailError = 'Please enter a valid email';
      } else {
        _emailError = null;
      }

      if (password.isEmpty) {
        _passwordError = 'Please enter a password';
      } else if (password.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }

      if (confirmPassword.isEmpty) {
        _confirmPasswordError = 'Please confirm your password';
      } else if (confirmPassword != password) {
        _confirmPasswordError = 'Passwords do not match';
      } else {
        _confirmPasswordError = null;
      }
    });

    if (_nameError != null ||
        _emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      _triggerHapticFeedback();
      return;
    }

    if (!_acceptedTerms) {
      _triggerHapticFeedback();
      await context.showError(
        title: 'Terms Required',
        message: 'Please accept the Terms & Conditions to continue.',
        type: ErrorDisplayType.warning,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<AuthProvider>().signUpWithEmailAndPassword(
        lowercaseEmail,
        password,
        displayName: trimmedName,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show verification message
        await context.showSuccess(
          title: 'Verify Your Email',
          message:
              'We\'ve sent a verification link to $lowercaseEmail. Please check your inbox and verify your email to continue.',
          autoHideDuration: const Duration(seconds: 4),
        );

        // Navigate to login — user must verify email before signing in.
        // AuthWrapper is NOT used here because the new account is signed out
        // immediately after creation to enforce email verification.
        if (mounted) {
          Navigator.of(context).pushReplacementWithTransition(
            const LoginScreen(),
            transitionType: TransitionType.fade,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _triggerHapticFeedback();
        // Show animated error dialog
        await context.showError(
          title: 'Sign Up Failed',
          message: e.toString(),
          onRetry: _handleSignUp,
          type: ErrorDisplayType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF8F0), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BackButton(),
                  const SizedBox(height: 20),
                  const _Header(),
                  const SizedBox(height: 40),
                  _NameField(
                    controller: _nameController,
                    errorText: _nameError,
                    onChanged: _validateName,
                    onError: _triggerHapticFeedback,
                  ),
                  const SizedBox(height: 16),
                  _EmailField(
                    controller: _emailController,
                    errorText: _emailError,
                    onChanged: _validateEmail,
                    onError: _triggerHapticFeedback,
                  ),
                  const SizedBox(height: 16),
                  _PasswordField(
                    controller: _passwordController,
                    errorText: _passwordError,
                    isPasswordVisible: _isPasswordVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    onChanged: _validatePassword,
                    onError: _triggerHapticFeedback,
                  ),
                  if (_hasStartedTypingPassword) ...[
                    const SizedBox(height: 8),
                    _PasswordStrengthMeter(
                      strength: _passwordStrength,
                      strengthText: _passwordStrengthText,
                      strengthColor: _passwordStrengthColor,
                    ),
                    const SizedBox(height: 8),
                    _PasswordRequirements(
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasLowercase: _hasLowercase,
                      hasNumber: _hasNumber,
                      hasSpecialChar: _hasSpecialChar,
                    ),
                  ],
                  const SizedBox(height: 16),
                  _ConfirmPasswordField(
                    controller: _confirmPasswordController,
                    errorText: _confirmPasswordError,
                    isPasswordVisible: _isConfirmPasswordVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                    onChanged: _validateConfirmPassword,
                    onError: _triggerHapticFeedback,
                  ),
                  const SizedBox(height: 16),
                  _TermsCheckbox(
                    acceptedTerms: _acceptedTerms,
                    onChanged: (value) {
                      setState(() {
                        _acceptedTerms = value;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  _SignUpButton(
                    isLoading: _isLoading,
                    isEnabled: _acceptedTerms,
                    onPressed: _handleSignUp,
                  ),
                  const SizedBox(height: 24),
                  const _Divider(),
                  const SizedBox(height: 24),
                  const GoogleSignInButton(text: 'Sign up with Google'),
                  const SizedBox(height: 24),
                  const _SignInPrompt(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Extracted Widget Components
class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
        onPressed: () => Navigator.of(context).pop(),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Account',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.primaryText,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Join our spiritual community',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _NameField extends StatefulWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onError;

  const _NameField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    this.onError,
  });

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final charCount = widget.controller.text.length;
    const maxChars = 50;

    return Semantics(
      label: 'Full Name field',
      hint: 'Enter your full name, maximum 50 characters',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AnimatedFormField(
            controller: widget.controller,
            labelText: 'Full Name',
            hintText: 'Enter your full name',
            hasError: widget.errorText != null,
            errorText: widget.errorText,
            prefixIcon: Icons.person_outlined,
            keyboardType: TextInputType.name,
            maxLines: 1,
            onChanged: (value) {
              if (widget.errorText != null) widget.onError?.call();
              widget.onChanged(value);
            },
          ),
          const SizedBox(height: 4),
          Text(
            '$charCount/$maxChars',
            style: TextStyle(
              fontSize: 12,
              color: charCount > maxChars
                  ? Colors.red
                  : AppColors.disabledText,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onError;

  const _EmailField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedFormField(
      controller: controller,
      labelText: 'Email',
      hintText: 'Enter your email',
      hasError: errorText != null,
      errorText: errorText,
      prefixIcon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      onChanged: (value) {
        if (errorText != null) onError?.call();
        onChanged(value);
      },
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final bool isPasswordVisible;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String> onChanged;
  final VoidCallback? onError;

  const _PasswordField({
    required this.controller,
    required this.errorText,
    required this.isPasswordVisible,
    required this.onToggleVisibility,
    required this.onChanged,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Password field',
      hint: 'Enter a password with at least 6 characters',
      child: AnimatedFormField(
        controller: controller,
        labelText: 'Password',
        hintText: 'At least 6 characters',
        hasError: errorText != null,
        errorText: errorText,
        prefixIcon: Icons.lock_outline,
        suffixIcon: isPasswordVisible ? Icons.visibility_off : Icons.visibility,
        onSuffixIconPressed: onToggleVisibility,
        obscureText: !isPasswordVisible,
        onChanged: (value) {
          if (errorText != null) onError?.call();
          onChanged(value);
        },
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  final double strength;
  final String strengthText;
  final Color strengthColor;

  const _PasswordStrengthMeter({
    required this.strength,
    required this.strengthText,
    required this.strengthColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Password strength: $strengthText',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: strength,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                strengthText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: strengthColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirements extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSpecialChar;

  const _PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSpecialChar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password must contain:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: 8),
          _RequirementItem(text: 'At least 6 characters', isMet: hasMinLength),
          _RequirementItem(
            text: 'One uppercase letter (A-Z)',
            isMet: hasUppercase,
          ),
          _RequirementItem(
            text: 'One lowercase letter (a-z)',
            isMet: hasLowercase,
          ),
          _RequirementItem(text: 'One number (0-9)', isMet: hasNumber),
          _RequirementItem(
            text: 'One special character (!@#\$%^&*)',
            isMet: hasSpecialChar,
          ),
        ],
      ),
    );
  }
}

class _RequirementItem extends StatelessWidget {
  final String text;
  final bool isMet;

  const _RequirementItem({required this.text, required this.isMet});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isMet ? Colors.green : Colors.grey[400],
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: isMet ? Colors.green : Colors.grey[600],
              fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfirmPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String? errorText;
  final bool isPasswordVisible;
  final VoidCallback onToggleVisibility;
  final ValueChanged<String> onChanged;
  final VoidCallback? onError;

  const _ConfirmPasswordField({
    required this.controller,
    required this.errorText,
    required this.isPasswordVisible,
    required this.onToggleVisibility,
    required this.onChanged,
    this.onError,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Confirm password field',
      hint: 'Re-enter your password to confirm',
      child: AnimatedFormField(
        controller: controller,
        labelText: 'Confirm Password',
        hintText: 'Re-enter your password',
        hasError: errorText != null,
        errorText: errorText,
        prefixIcon: Icons.lock_outlined,
        suffixIcon: isPasswordVisible
            ? Icons.visibility_outlined
            : Icons.visibility_off_outlined,
        onSuffixIconPressed: onToggleVisibility,
        obscureText: !isPasswordVisible,
        onChanged: (value) {
          if (errorText != null) onError?.call();
          onChanged(value);
        },
      ),
    );
  }
}

class _TermsCheckbox extends StatelessWidget {
  final bool acceptedTerms;
  final ValueChanged<bool> onChanged;

  const _TermsCheckbox({required this.acceptedTerms, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: acceptedTerms,
            onChanged: (value) => onChanged(value ?? false),
            activeColor: AppColors.lightOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'I have read and agree to the '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => _showTermsDialog(context),
                    child: const Text(
                      'Terms & Conditions',
                      style: TextStyle(
                        color: AppColors.lightOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const TextSpan(text: ' and '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: () => _showPrivacyDialog(context),
                    child: const Text(
                      'Privacy Policy',
                      style: TextStyle(
                        color: AppColors.lightOrange,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.lightOrange, AppColors.primaryOrange],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Terms & Conditions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _TermsSection(
                      title: '1. Acceptance of Terms',
                      content:
                          'By creating an account and using this application, you confirm that you are at least 13 years of age and agree to be bound by these Terms & Conditions. If you do not agree, please do not use this app.',
                    ),
                    _TermsSection(
                      title: '2. Account Registration',
                      content:
                          '• You must provide accurate, complete, and current information during registration.\n'
                          '• You are responsible for maintaining the confidentiality of your account credentials.\n'
                          '• You must notify us immediately of any unauthorized use of your account.\n'
                          '• One person may not maintain more than one account.',
                    ),
                    _TermsSection(
                      title: '3. Temple Services & Bookings',
                      content:
                          '• Darshan bookings are subject to availability and temple schedules.\n'
                          '• Bookings must be made in good faith for genuine spiritual purposes.\n'
                          '• Cancellations must be made at least 24 hours in advance for a refund.\n'
                          '• The temple reserves the right to cancel or reschedule services due to religious events, maintenance, or unforeseen circumstances.\n'
                          '• Dress code and conduct guidelines of the temple must be followed during visits.',
                    ),
                    _TermsSection(
                      title: '4. Donations',
                      content:
                          '• All donations made through this app are voluntary and non-refundable unless processed in error.\n'
                          '• Donations are used solely for temple maintenance, religious activities, and community welfare.\n'
                          '• Tax receipts may be issued as per applicable laws; contact the temple administration for details.\n'
                          '• We do not store your full payment card details; all transactions are processed through secure payment gateways.',
                    ),
                    _TermsSection(
                      title: '5. Community Guidelines',
                      content:
                          '• Treat all community members with respect and dignity.\n'
                          '• Do not post or share offensive, defamatory, or inappropriate content.\n'
                          '• Respect the sanctity and religious sentiments of all faiths.\n'
                          '• Spam, solicitation, or commercial promotion is strictly prohibited.\n'
                          '• Violations may result in account suspension or permanent ban.',
                    ),
                    _TermsSection(
                      title: '6. Live Darshan & Media',
                      content:
                          '• Live darshan streams are provided for personal, non-commercial spiritual use only.\n'
                          '• Recording, redistribution, or broadcasting of live streams without written permission is prohibited.\n'
                          '• Stream availability may vary due to technical or religious reasons.',
                    ),
                    _TermsSection(
                      title: '7. Intellectual Property',
                      content:
                          '• All content including images, videos, text, and logos are the property of the temple or its licensors.\n'
                          '• You may not reproduce, distribute, or create derivative works without prior written consent.',
                    ),
                    _TermsSection(
                      title: '8. Limitation of Liability',
                      content:
                          '• We strive to provide accurate information but do not guarantee the completeness or accuracy of all content.\n'
                          '• We are not liable for any indirect, incidental, or consequential damages arising from your use of the app.\n'
                          '• Service availability is not guaranteed and may be interrupted for maintenance.',
                    ),
                    _TermsSection(
                      title: '9. Modifications',
                      content:
                          'We reserve the right to update these Terms & Conditions at any time. Continued use of the app after changes constitutes acceptance of the revised terms. We will notify users of significant changes via email or in-app notification.',
                    ),
                    _TermsSection(
                      title: '10. Governing Law',
                      content:
                          'These terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of the courts in the temple\'s registered state.',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Last updated: MAY 2026',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.disabledText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.lightOrange, AppColors.primaryOrange],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.privacy_tip_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _TermsSection(
                      title: '1. Information We Collect',
                      content:
                          '• Personal details: name, email address, phone number.\n'
                          '• Profile information you choose to provide.\n'
                          '• Booking and donation transaction history.\n'
                          '• Device information and usage analytics to improve the app.\n'
                          '• Location data (only when you grant permission) for nearby temple features.',
                    ),
                    _TermsSection(
                      title: '2. How We Use Your Information',
                      content:
                          '• To create and manage your account.\n'
                          '• To process bookings, donations, and send confirmations.\n'
                          '• To send important notifications about temple events and your bookings.\n'
                          '• To improve app features and user experience.\n'
                          '• To comply with legal obligations.',
                    ),
                    _TermsSection(
                      title: '3. Data Sharing',
                      content:
                          '• We do not sell your personal data to third parties.\n'
                          '• Data may be shared with payment processors (e.g., Razorpay) solely to complete transactions.\n'
                          '• We may share anonymized, aggregated data for analytics purposes.\n'
                          '• Data may be disclosed if required by law or court order.',
                    ),
                    _TermsSection(
                      title: '4. Data Security',
                      content:
                          '• Your data is stored securely using industry-standard encryption.\n'
                          '• Passwords are hashed and never stored in plain text.\n'
                          '• We use Firebase Authentication and Supabase with row-level security.\n'
                          '• We regularly review our security practices to protect your information.',
                    ),
                    _TermsSection(
                      title: '5. Notifications',
                      content:
                          '• We may send push notifications for booking confirmations, event reminders, and temple updates.\n'
                          '• You can manage notification preferences in your account settings at any time.',
                    ),
                    _TermsSection(
                      title: '6. Your Rights',
                      content:
                          '• Access: You may request a copy of the personal data we hold about you.\n'
                          '• Correction: You may update your profile information at any time.\n'
                          '• Deletion: You may request deletion of your account and associated data.\n'
                          '• Opt-out: You may unsubscribe from marketing communications at any time.',
                    ),
                    _TermsSection(
                      title: '7. Cookies & Analytics',
                      content:
                          'We use analytics tools to understand how users interact with the app. This data is anonymized and used only to improve the user experience.',
                    ),
                    _TermsSection(
                      title: '8. Children\'s Privacy',
                      content:
                          'This app is not directed at children under 13. We do not knowingly collect personal information from children. If you believe a child has provided us with personal data, please contact us immediately.',
                    ),
                    _TermsSection(
                      title: '9. Contact Us',
                      content:
                          'For any privacy-related questions or requests, please contact the temple administration through the Help & Support section in the app.',
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Last updated: MAY 2026',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.disabledText,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lightOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text(
                    'I Understand',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable section widget for Terms & Privacy dialogs
class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignUpButton extends StatelessWidget {
  final bool isLoading;
  final bool isEnabled;
  final VoidCallback onPressed;

  const _SignUpButton({
    required this.isLoading,
    required this.isEnabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.lightOrange, AppColors.primaryOrange],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.lightOrange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (isLoading || !isEnabled) ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Account',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.borderGray)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.borderGray)),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(color: Colors.grey),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            Navigator.of(context).pushReplacementWithTransition(
              const LoginScreen(),
              transitionType: TransitionType.fade,
              duration: const Duration(milliseconds: 250),
            );
          },
          child: const Text(
            'Sign In',
            style: TextStyle(
              color: AppColors.lightOrange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
