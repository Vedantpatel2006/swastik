import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/themes/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../shared/widgets/animations/transition_manager.dart';
import '../../../shared/widgets/error/index.dart';
import '../../../shared/widgets/auth/optimized_auth_widgets.dart';
import '../widgets/auth/google_sign_in_button.dart';
import '../services/auth_wrapper.dart';
import '../../../shared/widgets/performance/build_optimization_mixin.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with BuildOptimizationMixin<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _emailError;
  String? _passwordError;

  static const _rememberMeKey = 'login_remember_me';
  static const _savedEmailKey = 'login_saved_email';

  @override
  void initState() {
    super.initState();
    _loadRememberMe();
  }

  Future<void> _loadRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_rememberMeKey) ?? false;
    if (remembered && mounted) {
      final savedEmail = prefs.getString(_savedEmailKey) ?? '';
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _saveRememberMe(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedEmailKey, email);
    } else {
      await prefs.remove(_rememberMeKey);
      await prefs.remove(_savedEmailKey);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail(String value) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    final oldError = _emailError;

    setState(() {
      final trimmedValue = value.trim();
      if (trimmedValue.isEmpty) {
        _emailError = 'Please enter your email';
      } else if (!emailRegex.hasMatch(trimmedValue)) {
        _emailError = 'Please enter a valid email';
      } else {
        _emailError = null;
      }
    });

    if (oldError != _emailError && _emailError != null) {
      _triggerHapticFeedback();
    }

    // Invalidate form field cache if error state changed
    if (oldError != _emailError) {
      invalidateCache('emailField');
      invalidateCache('signInButton');
    }
  }

  void _validatePassword(String value) {
    final oldError = _passwordError;

    setState(() {
      if (value.isEmpty) {
        _passwordError = 'Please enter your password';
      } else if (value.length < 6) {
        _passwordError = 'Password must be at least 6 characters';
      } else {
        _passwordError = null;
      }
    });

    if (oldError != _passwordError && _passwordError != null) {
      _triggerHapticFeedback();
    }

    // Invalidate form field cache if error state changed
    if (oldError != _passwordError) {
      invalidateCache('passwordField');
      invalidateCache('signInButton');
    }
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  Future<void> _handleLogin() async {
    // Validate fields
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);

    if (_emailError != null || _passwordError != null) {
      _triggerHapticFeedback();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = context.read<AuthProvider>();
      await auth.signInWithEmailAndPassword(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Persist remember-me preference
        await _saveRememberMe(_emailController.text.trim().toLowerCase());

        // Show success feedback
        await context.showSuccess(
          title: 'Welcome Back!',
          message: 'You have successfully signed in.',
          autoHideDuration: const Duration(seconds: 1),
        );

        // Use AuthWrapper for proper role-based routing
        if (mounted) {
          Navigator.of(context).pushReplacementWithTransition(
            const AuthWrapper(),
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

        // Check if error is about email verification
        if (e.toString().contains('verify your email')) {
          await _showEmailVerificationDialog();
        } else {
          // Show animated error dialog
          await context.showError(
            title: 'Sign In Failed',
            message: e.toString(),
            onRetry: _handleLogin,
            type: ErrorDisplayType.error,
          );
        }
      }
    }
  }

  Future<void> _showEmailVerificationDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.lightOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.email_outlined,
                color: AppColors.lightOrange,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Email Not Verified',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please verify your email address before signing in.',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.lightOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.lightOrange,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Check your inbox for the verification link.',
                      style: TextStyle(color: Colors.grey[800], fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _resendVerificationEmail();
            },
            child: const Text(
              'Resend Email',
              style: TextStyle(
                color: AppColors.lightOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.lightOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resendVerificationEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      await context.showError(
        title: 'Missing Information',
        message: 'Please enter your email and password first.',
        type: ErrorDisplayType.warning,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await context.read<AuthProvider>().resendVerificationForEmail(
        _emailController.text.trim().toLowerCase(),
        _passwordController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        await context.showSuccess(
          title: 'Email Sent!',
          message: 'Verification email has been sent. Please check your inbox.',
          autoHideDuration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _triggerHapticFeedback();

        await context.showError(
          title: 'Failed to Send',
          message: e.toString(),
          type: ErrorDisplayType.error,
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController(text: _emailController.text);
    String? dialogEmailError;
    bool isDialogLoading = false;

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Reset Password',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  enabled: !isDialogLoading,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    errorText: dialogEmailError,
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.borderGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.lightOrange,
                        width: 2,
                      ),
                    ),
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      final trimmedValue = value.trim();
                      if (trimmedValue.isEmpty) {
                        dialogEmailError = 'Please enter your email';
                      } else if (!emailRegex.hasMatch(trimmedValue)) {
                        dialogEmailError = 'Please enter a valid email';
                      } else {
                        dialogEmailError = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDialogLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.secondaryText),
                ),
              ),
              ElevatedButton(
                onPressed: isDialogLoading
                    ? null
                    : () async {
                        final email = emailController.text.trim().toLowerCase();
                        if (email.isEmpty || !emailRegex.hasMatch(email)) {
                          HapticFeedback.lightImpact();
                          setDialogState(() {
                            dialogEmailError = email.isEmpty
                                ? 'Please enter your email'
                                : 'Please enter a valid email';
                          });
                          return;
                        }

                        setDialogState(() {
                          isDialogLoading = true;
                        });

                        try {
                          await context.read<AuthProvider>().resetPassword(
                            email,
                          );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            await context.showSuccess(
                              title: 'Email Sent!',
                              message:
                                  'Check your inbox for password reset instructions.',
                              autoHideDuration: const Duration(seconds: 3),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            HapticFeedback.lightImpact();
                            await context.showError(
                              title: 'Reset Failed',
                              message: e.toString(),
                              type: ErrorDisplayType.error,
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.lightOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isDialogLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text('Send Reset Link'),
              ),
            ],
          ),
        ),
      );
    } finally {
      emailController.dispose();
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
                  // Back button
                  buildOnce(
                    'backButton',
                    () => Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primaryText,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    dependencies: const [],
                  ),

                  const SizedBox(height: 20),

                  // Header
                  buildOnce(
                    'header',
                    () => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back!',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your spiritual journey',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    dependencies: const [],
                  ),

                  const SizedBox(height: 40),
                  buildOnce(
                    'emailField',
                    () => AnimatedFormField(
                      controller: _emailController,
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      hasError: _emailError != null,
                      errorText: _emailError,
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      onChanged: _validateEmail,
                    ),
                    dependencies: [_emailError],
                  ),
                  const SizedBox(height: 16),
                  AnimatedFormField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    hasError: _passwordError != null,
                    errorText: _passwordError,
                    prefixIcon: Icons.lock_outline,
                    suffixIcon: _isPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    onSuffixIconPressed: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                    obscureText: !_isPasswordVisible,
                    onChanged: _validatePassword,
                  ),
                  const SizedBox(height: 12),
                  // Remember Me and Forgot Password
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                          activeColor: AppColors.lightOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Remember me',
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 14,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showForgotPasswordDialog,
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.lightOrange,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Sign In Button with loading state
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.lightOrange,
                          AppColors.primaryOrange,
                        ],
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
                      onPressed:
                          (_isLoading ||
                              _emailError != null ||
                              _passwordError != null)
                          ? null
                          : _handleLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        disabledForegroundColor: Colors.white.withValues(
                          alpha: 0.6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Optimized error display — must listen to error state changes
                  OptimizedAuthErrorDisplay(
                    onRetry: _handleLogin,
                    onDismiss: () => context.read<AuthProvider>().clearError(),
                  ),

                  const SizedBox(height: 8),

                  // Divider with "OR"
                  buildOnce(
                    'divider',
                    () => Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.borderGray,
                          ),
                        ),
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
                        Expanded(
                          child: Container(
                            height: 1,
                            color: AppColors.borderGray,
                          ),
                        ),
                      ],
                    ),
                    dependencies: const [],
                  ),

                  const SizedBox(height: 24),

                  // Google Sign-In Button
                  buildOnce(
                    'googleSignIn',
                    () =>
                        const GoogleSignInButton(text: 'Continue with Google'),
                    dependencies: const [],
                  ),

                  const SizedBox(height: 24),
                  buildOnce(
                    'signUpLink',
                    () => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.grey),
                        ),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            Navigator.of(context).pushReplacementWithTransition(
                              const SignUpScreen(),
                              transitionType: TransitionType.fade,
                              duration: const Duration(milliseconds: 250),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppColors.lightOrange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    dependencies: const [],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
