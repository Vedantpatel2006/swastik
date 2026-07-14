import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../shared/widgets/error/index.dart';
import '../../services/auth_wrapper.dart';
import '../../../../shared/widgets/animations/transition_manager.dart';

class GoogleSignInButton extends StatefulWidget {
  final String text;
  final bool isCompact;

  const GoogleSignInButton({
    super.key,
    this.text = 'Continue with Google',
    this.isCompact = false,
  });

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signInWithGoogle();

      if (!mounted) return;

      // Show success feedback
      await context.showSuccess(
        title: 'Welcome!',
        message: 'You have successfully signed in with Google.',
        autoHideDuration: const Duration(seconds: 1),
      );

      if (mounted) {
        Navigator.of(context).pushReplacementWithTransition(
          const AuthWrapper(),
          transitionType: TransitionType.fade,
        );
      }
    } catch (e) {
      if (mounted) {
        // Show animated error dialog
        await context.showError(
          title: 'Google Sign-In Failed',
          message: e.toString(),
          onRetry: _handleGoogleSignIn,
          type: ErrorDisplayType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            height: widget.isCompact ? 48 : 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(widget.isCompact ? 12 : 16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isLoading ? null : _handleGoogleSignIn,
                borderRadius: BorderRadius.circular(widget.isCompact ? 12 : 16),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.isCompact ? 16 : 20,
                    vertical: widget.isCompact ? 12 : 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey[600]!,
                            ),
                          ),
                        )
                      else
                        GoogleIcon(size: 20),
                      const SizedBox(width: 12),
                      Text(
                        _isLoading ? 'Signing in...' : widget.text,
                        style: TextStyle(
                          fontSize: widget.isCompact ? 14 : 16,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF374151),
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

class GoogleIcon extends StatelessWidget {
  final double size;

  const GoogleIcon({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      child: CustomPaint(painter: GoogleIconPainter()),
    );
  }
}

class GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Simple Google "G" representation
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF4285F4);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Draw main circle
    canvas.drawCircle(center, radius, paint);

    // Draw white inner circle to create "G" shape
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, radius * 0.5, whitePaint);

    // Draw the "G" opening
    final rect = Rect.fromLTWH(
      center.dx - radius * 0.2,
      center.dy - radius * 0.1,
      radius * 0.6,
      radius * 0.2,
    );
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
