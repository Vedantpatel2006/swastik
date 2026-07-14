import 'package:flutter/material.dart';
import 'package:swastik/core/themes/app_colors.dart';

/// Reusable app logo widget with different variants and sizes
class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final LogoVariant variant;
  final bool showText;
  final Color? textColor;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.variant = LogoVariant.main,
    this.showText = false,
    this.textColor,
  });

  /// Small logo for app bars
  const AppLogo.small({
    super.key,
    this.variant = LogoVariant.main,
    this.showText = false,
    this.textColor,
  }) : width = 28,
       height = 28;

  /// Medium logo for cards and lists
  const AppLogo.medium({
    super.key,
    this.variant = LogoVariant.main,
    this.showText = false,
    this.textColor,
  }) : width = 56,
       height = 56;

  /// Large logo for splash screens and headers
  const AppLogo.large({
    super.key,
    this.variant = LogoVariant.main,
    this.showText = true,
    this.textColor,
  }) : width = 100,
       height = 100;

  /// Extra large logo for onboarding
  const AppLogo.extraLarge({
    super.key,
    this.variant = LogoVariant.main,
    this.showText = true,
    this.textColor,
  }) : width = 140,
       height = 140;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: SizedBox(
            width: width,
            height: height,
            child: Image.asset(
              _getLogoPath(),
              width: width,
              height: height,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: height,
                  color: AppColors.primaryOrange,
                  child: Icon(
                    Icons.temple_hindu,
                    color: Colors.white,
                    size: (width ?? 32) * 0.6,
                  ),
                );
              },
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            'SWASTIK',
            style: TextStyle(
              fontSize: _getTextSize(),
              fontWeight: FontWeight.w900,
              color: textColor ?? AppColors.primaryOrange,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Temple Discovery App',
            style: TextStyle(
              fontSize: _getTextSize() * 0.6,
              fontWeight: FontWeight.w500,
              color: textColor ?? const Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }

  String _getLogoPath() {
    switch (variant) {
      case LogoVariant.main:
        return 'assets/images/logos/app_launcher_icon.png';
      case LogoVariant.organization:
        return 'assets/images/logos/app_launcher_icon.png';
    }
  }

  double _getTextSize() {
    if (width == null) return 16;
    if (width! <= 32) return 12;
    if (width! <= 64) return 14;
    if (width! <= 120) return 18;
    return 24;
  }
}

/// Different logo variants available
enum LogoVariant { main, organization }

/// Animated logo widget for splash screens
class AnimatedAppLogo extends StatefulWidget {
  final double size;
  final LogoVariant variant;
  final bool showText;
  final Color? textColor;
  final Duration animationDuration;

  const AnimatedAppLogo({
    super.key,
    this.size = 120,
    this.variant = LogoVariant.main,
    this.showText = true,
    this.textColor,
    this.animationDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<AnimatedAppLogo> createState() => _AnimatedAppLogoState();
}

class _AnimatedAppLogoState extends State<AnimatedAppLogo>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(
        milliseconds: widget.animationDuration.inMilliseconds ~/ 2,
      ),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // Start animations
    _scaleController.forward();
    Future.delayed(
      Duration(milliseconds: widget.animationDuration.inMilliseconds ~/ 3),
      () {
        if (mounted) {
          _fadeController.forward();
        }
      },
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ScaleTransition(
          scale: _scaleAnimation,
          child: AppLogo(
            width: widget.size,
            height: widget.size,
            variant: widget.variant,
            showText: false,
          ),
        ),
        if (widget.showText) ...[
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Text(
                  'Swastik',
                  style: TextStyle(
                    fontSize: widget.size * 0.2,
                    fontWeight: FontWeight.bold,
                    color: widget.textColor ?? const Color(0xFF111827),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Temple Management System',
                  style: TextStyle(
                    fontSize: widget.size * 0.12,
                    color: (widget.textColor ?? const Color(0xFF111827))
                        .withValues(alpha: 0.7),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
