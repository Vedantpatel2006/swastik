import 'package:flutter/material.dart';
import '../services/realtime_live_provider.dart';

/// Real-Time Live Indicator Widget
/// 
/// This widget demonstrates the correct way to use the new real-time system:
/// 1. ONLY listens to Firestore via RealtimeLiveProvider
/// 2. NEVER calls YouTube API
/// 3. Shows live status with proper error handling
/// 4. Handles stale data gracefully
/// 
/// Replace your existing live indicators with this pattern.
class RealtimeLiveIndicator extends StatefulWidget {
  final String templeId;
  final Widget Function(BuildContext context, bool isLive, bool isStale)? builder;
  final bool showStaleIndicator;

  const RealtimeLiveIndicator({
    super.key,
    required this.templeId,
    this.builder,
    this.showStaleIndicator = true,
  });

  @override
  State<RealtimeLiveIndicator> createState() => _RealtimeLiveIndicatorState();
}

class _RealtimeLiveIndicatorState extends State<RealtimeLiveIndicator>
    with SingleTickerProviderStateMixin {
  final RealtimeLiveProvider _liveProvider = RealtimeLiveProvider();
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup pulse animation for live indicator
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<LiveStatus>(
      stream: _liveProvider.watchLiveStatus(widget.templeId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorIndicator();
        }

        if (!snapshot.hasData) {
          return _buildLoadingIndicator();
        }

        final liveStatus = snapshot.data!;
        
        // Start/stop animation based on live status
        if (liveStatus.isLive && !liveStatus.isStale) {
          if (!_animationController.isAnimating) {
            _animationController.repeat(reverse: true);
          }
        } else {
          _animationController.stop();
          _animationController.reset();
        }

        // Use custom builder if provided
        if (widget.builder != null) {
          return widget.builder!(context, liveStatus.isLive, liveStatus.isStale);
        }

        // Default live indicator
        return _buildDefaultIndicator(liveStatus);
      },
    );
  }

  Widget _buildDefaultIndicator(LiveStatus liveStatus) {
    if (!liveStatus.isLive) {
      return const SizedBox.shrink(); // Hide when not live
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: liveStatus.isStale ? Colors.orange : Colors.red,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (liveStatus.isStale ? Colors.orange : Colors.red).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  liveStatus.isStale ? 'LIVE?' : 'LIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.showStaleIndicator && liveStatus.isStale) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: 12,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      ),
    );
  }

  Widget _buildErrorIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.error_outline,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

/// Live Count Badge Widget
/// Shows total number of live temples
class LiveCountBadge extends StatelessWidget {
  final Widget child;
  final bool showZero;

  const LiveCountBadge({
    super.key,
    required this.child,
    this.showZero = false,
  });

  @override
  Widget build(BuildContext context) {
    final liveProvider = RealtimeLiveProvider();

    return StreamBuilder<int>(
      stream: liveProvider.watchLiveCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        
        if (count == 0 && !showZero) {
          return child;
        }

        return Badge(
          label: Text(count.toString()),
          backgroundColor: Colors.red,
          textColor: Colors.white,
          child: child,
        );
      },
    );
  }
}

/// Global Live Indicator
/// Shows if ANY temple is live (for app bar, navigation, etc.)
class GlobalLiveIndicator extends StatelessWidget {
  final Widget Function(BuildContext context, bool anyLive)? builder;

  const GlobalLiveIndicator({
    super.key,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final liveProvider = RealtimeLiveProvider();

    return StreamBuilder<bool>(
      stream: liveProvider.watchAnyTempleLive(),
      builder: (context, snapshot) {
        final anyLive = snapshot.data ?? false;

        if (builder != null) {
          return builder!(context, anyLive);
        }

        // Default global indicator
        if (!anyLive) {
          return const SizedBox.shrink();
        }

        return Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}

/// Live Temples List Widget
/// Shows all currently live temples
class LiveTemplesList extends StatelessWidget {
  final Widget Function(BuildContext context, List<LiveStatus> liveTemples)? builder;

  const LiveTemplesList({
    super.key,
    this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final liveProvider = RealtimeLiveProvider();

    return StreamBuilder<List<LiveStatus>>(
      stream: liveProvider.watchAllLiveTemples(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Error loading live temples'),
          );
        }

        final liveTemples = snapshot.data ?? [];

        if (builder != null) {
          return builder!(context, liveTemples);
        }

        // Default list
        if (liveTemples.isEmpty) {
          return const Center(
            child: Text('No temples are currently live'),
          );
        }

        return ListView.builder(
          itemCount: liveTemples.length,
          itemBuilder: (context, index) {
            final temple = liveTemples[index];
            return ListTile(
              leading: const Icon(Icons.circle, color: Colors.red, size: 12),
              title: Text('Temple ${temple.templeId}'),
              subtitle: Text('Live since ${temple.lastUpdated?.toString() ?? 'Unknown'}'),
              trailing: temple.isStale 
                  ? const Icon(Icons.warning, color: Colors.orange)
                  : null,
            );
          },
        );
      },
    );
  }
}