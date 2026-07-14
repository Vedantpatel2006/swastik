import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
/// Widget that conditionally shows content based on user role
class RoleBasedWidget extends StatelessWidget {
  final Widget? adminWidget;
  final Widget? userWidget;
  final Widget? fallbackWidget;
  final bool showFallbackForUnauthorized;

  const RoleBasedWidget({
    super.key,
    this.adminWidget,
    this.userWidget,
    this.fallbackWidget,
    this.showFallbackForUnauthorized = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: context.read<AuthProvider>().isAdmin,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final isAdmin = snapshot.data ?? false;

        if (isAdmin && adminWidget != null) {
          return adminWidget!;
        } else if (!isAdmin && userWidget != null) {
          return userWidget!;
        } else if (showFallbackForUnauthorized && fallbackWidget != null) {
          return fallbackWidget!;
        }

        return const SizedBox.shrink();
      },
    );
  }
}

/// Widget that shows content only to admins
class AdminOnlyWidget extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const AdminOnlyWidget({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    return RoleBasedWidget(
      adminWidget: child,
      fallbackWidget: fallback ?? const SizedBox.shrink(),
    );
  }
}

/// Widget that shows content only to regular users
class UserOnlyWidget extends StatelessWidget {
  final Widget child;
  final Widget? fallback;

  const UserOnlyWidget({super.key, required this.child, this.fallback});

  @override
  Widget build(BuildContext context) {
    return RoleBasedWidget(
      userWidget: child,
      fallbackWidget: fallback ?? const SizedBox.shrink(),
    );
  }
}
