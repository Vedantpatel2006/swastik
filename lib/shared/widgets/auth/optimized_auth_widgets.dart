import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:swastik/core/themes/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/auth_provider_selectors.dart';
import '../../../shared/models/user_role.dart';

/// Optimized auth button that only rebuilds when loading state changes
class OptimizedAuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  const OptimizedAuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    // Only listen to loading state changes
    final isLoading = AuthSelectors.isLoading(context);

    return Container(
      width: width ?? double.infinity,
      height: height ?? 56,
      decoration: BoxDecoration(
        gradient: backgroundColor == null
            ? const LinearGradient(
                colors: [AppColors.primaryOrange, AppColors.lightOrange],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: backgroundColor,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AppColors.primaryOrange).withValues(
              alpha: 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: foregroundColor ?? Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
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
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

/// Optimized error display that only rebuilds when error state changes
class OptimizedAuthErrorDisplay extends StatelessWidget {
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const OptimizedAuthErrorDisplay({super.key, this.onRetry, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    // Only listen to error state changes
    final errorState = AuthSelectors.errorState(context);

    if (!errorState.hasError || errorState.errorMessage == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorState.errorMessage!,
              style: const TextStyle(
                color: Color(0xFFEF4444),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 8),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16),
              color: const Color(0xFFEF4444),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            ),
          ],
        ],
      ),
    );
  }
}

/// Optimized user info display that only rebuilds when user info changes
class OptimizedUserInfoDisplay extends StatelessWidget {
  final bool showRole;
  final bool showEmail;
  final TextStyle? nameStyle;
  final TextStyle? emailStyle;
  final TextStyle? roleStyle;

  const OptimizedUserInfoDisplay({
    super.key,
    this.showRole = true,
    this.showEmail = true,
    this.nameStyle,
    this.emailStyle,
    this.roleStyle,
  });

  @override
  Widget build(BuildContext context) {
    // Only listen to user info changes
    final userInfo = AuthSelectors.userInfo(context);

    if (userInfo == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (userInfo.displayName != null)
          Text(
            userInfo.displayName!,
            style:
                nameStyle ??
                const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
          ),
        if (showEmail && userInfo.email != null) ...[
          const SizedBox(height: 2),
          Text(
            userInfo.email!,
            style:
                emailStyle ??
                const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
          ),
        ],
        if (showRole && userInfo.role != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: userInfo.role!.isAdmin
                  ? const Color(0xFFDCFDF7)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              userInfo.role!.displayName,
              style:
                  roleStyle ??
                  TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: userInfo.role!.isAdmin
                        ? const Color(0xFF059669)
                        : const Color(0xFF6B7280),
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Optimized auth state wrapper that only rebuilds when auth state changes
class OptimizedAuthStateWrapper extends StatelessWidget {
  final Widget Function(BuildContext context, bool isAuthenticated) builder;
  final Widget? loadingWidget;

  const OptimizedAuthStateWrapper({
    super.key,
    required this.builder,
    this.loadingWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Only listen to auth state changes (authentication + loading)
    final authState = AuthSelectors.authState(context);

    if (authState.isLoading) {
      return loadingWidget ??
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
          );
    }

    return builder(context, authState.isAuthenticated);
  }
}

/// Optimized role-based widget that only rebuilds when user role changes
class OptimizedRoleBasedWidget extends StatefulWidget {
  final Widget Function(BuildContext context, UserRole role) builder;
  final Widget? loadingWidget;
  final Widget? unauthenticatedWidget;

  const OptimizedRoleBasedWidget({
    super.key,
    required this.builder,
    this.loadingWidget,
    this.unauthenticatedWidget,
  });

  @override
  State<OptimizedRoleBasedWidget> createState() =>
      _OptimizedRoleBasedWidgetState();
}

class _OptimizedRoleBasedWidgetState extends State<OptimizedRoleBasedWidget> {
  // If cachedUserRole is still null after this duration, fall back to UserRole.user
  // rather than showing a spinner forever.
  static const _roleTimeout = Duration(seconds: 5);
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_roleTimeout, () {
      if (mounted) {
        // Use context.read (safe outside build) instead of context.select
        // (which is only valid inside the build method).
        final role = context.read<AuthProvider>().cachedUserRole;
        if (role == null) {
          setState(() => _timedOut = true);
          debugPrint(
            '⚠️ OptimizedRoleBasedWidget: role cache timeout — defaulting to user',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check authentication first
    final isAuthenticated = AuthSelectors.isAuthenticated(context);

    if (!isAuthenticated) {
      return widget.unauthenticatedWidget ?? const SizedBox.shrink();
    }

    // Only listen to role changes for authenticated users
    final role = AuthSelectors.cachedUserRole(context);

    if (role == null) {
      // If we've waited long enough, fall back to user role instead of
      // showing a spinner indefinitely (e.g. Firestore fetch failed silently).
      if (_timedOut) {
        return widget.builder(context, UserRole.user);
      }
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
            ),
          );
    }

    return widget.builder(context, role);
  }
}

/// Optimized conditional widget based on authentication status
class OptimizedAuthConditional extends StatelessWidget {
  final Widget authenticatedChild;
  final Widget unauthenticatedChild;
  final Widget? loadingChild;

  const OptimizedAuthConditional({
    super.key,
    required this.authenticatedChild,
    required this.unauthenticatedChild,
    this.loadingChild,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedAuthStateWrapper(
      loadingWidget: loadingChild,
      builder: (context, isAuthenticated) {
        return isAuthenticated ? authenticatedChild : unauthenticatedChild;
      },
    );
  }
}

/// Button style enum for AnimatedRetryButton
enum RetryButtonStyle { filled, outlined, text }

/// Animated retry button with loading state
class AnimatedRetryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final RetryButtonStyle style;
  final BorderRadius? borderRadius;
  final double? width;
  final double? height;

  const AnimatedRetryButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.style = RetryButtonStyle.filled,
    this.borderRadius,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBackgroundColor = backgroundColor ?? AppColors.primaryOrange;
    final effectiveForegroundColor = foregroundColor ?? Colors.white;

    return SizedBox(
      width: width,
      height: height ?? 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: style == RetryButtonStyle.filled
              ? effectiveBackgroundColor
              : Colors.transparent,
          foregroundColor: effectiveForegroundColor,
          disabledBackgroundColor: style == RetryButtonStyle.filled
              ? effectiveBackgroundColor.withValues(alpha: 0.6)
              : Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius ?? BorderRadius.circular(16),
            side: style == RetryButtonStyle.outlined
                ? BorderSide(color: effectiveBackgroundColor, width: 2)
                : BorderSide.none,
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    effectiveForegroundColor,
                  ),
                ),
              )
            : Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: effectiveForegroundColor,
                ),
              ),
      ),
    );
  }
}
