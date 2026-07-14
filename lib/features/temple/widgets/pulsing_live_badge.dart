import 'package:flutter/material.dart';
import '../../../core/themes/app_colors.dart';

/// Animated pulsing LIVE badge — shown on cards and overlaid on images.
///
/// [asOverlay] — when true, adds a semi-transparent rounded-rect background
/// suitable for overlaying on top of an image (grid / horizontal cards).
/// When false (default), renders a plain pill for inline use.
class PulsingLiveBadge extends StatefulWidget {
  final bool asOverlay;

  const PulsingLiveBadge({super.key, this.asOverlay = false});

  @override
  State<PulsingLiveBadge> createState() => _PulsingLiveBadgeState();
}

class _PulsingLiveBadgeState extends State<PulsingLiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);

    _pulse = Tween<double>(
      begin: 0.25,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.asOverlay
            ? AppColors.liveRed.withValues(alpha: 0.92)
            : AppColors.liveRed,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) =>
                Opacity(opacity: _pulse.value, child: child),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
