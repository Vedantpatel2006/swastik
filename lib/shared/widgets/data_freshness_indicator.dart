import 'package:flutter/material.dart';
import 'dart:async';
import '../../features/temple/services/user_temple_service.dart';
import '../../features/user/services/user_preferences_service.dart';
import '../../features/temple/services/favorites_service.dart';
import '../services/offline/offline_manager.dart';
import 'performance/build_optimization_mixin.dart';

/// Widget that shows data freshness information
class DataFreshnessIndicator extends StatefulWidget {
  final bool showLastSync;
  final bool showRefreshButton;
  final EdgeInsets? padding;
  final TextStyle? textStyle;
  final Color? iconColor;

  const DataFreshnessIndicator({
    super.key,
    this.showLastSync = true,
    this.showRefreshButton = true,
    this.padding,
    this.textStyle,
    this.iconColor,
  });

  @override
  State<DataFreshnessIndicator> createState() => _DataFreshnessIndicatorState();
}

class _DataFreshnessIndicatorState extends State<DataFreshnessIndicator>
    with BuildOptimizationMixin<DataFreshnessIndicator> {
  final UserTempleService _templeService = UserTempleService();
  final UserPreferencesService _preferencesService = UserPreferencesService();
  final FavoritesService _favoritesService = FavoritesService();

  bool _isRefreshing = false;
  DateTime? _lastSyncTime;
  bool _isDataStale = false;
  bool _isOnline = true;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _checkDataFreshness();
    _listenToSyncStatus();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _listenToSyncStatus() {
    _syncSubscription = _templeService.syncStatusStream.listen((status) {
      if (mounted) {
        _checkDataFreshness();
      }
    });
  }

  Future<void> _checkDataFreshness() async {
    try {
      final templeFreshness = await _templeService.getDataFreshness();
      final preferencesFreshness = await _preferencesService.getDataFreshness();

      if (mounted) {
        final oldLastSyncTime = _lastSyncTime;
        final oldIsDataStale = _isDataStale;
        final oldIsOnline = _isOnline;

        setState(() {
          _lastSyncTime = templeFreshness['lastSyncTime'] != null
              ? DateTime.parse(templeFreshness['lastSyncTime'])
              : null;
          _isDataStale =
              templeFreshness['isStale'] == true ||
              preferencesFreshness['isStale'] == true;
          _isOnline = templeFreshness['isOnline'] == true;
        });

        // Invalidate cache if state changed
        if (oldLastSyncTime != _lastSyncTime ||
            oldIsDataStale != _isDataStale ||
            oldIsOnline != _isOnline) {
          invalidateAllCaches();
        }
      }
    } catch (e) {
      debugPrint('DataFreshnessIndicator: Error checking freshness - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isDataStale && _isOnline) {
      return const SizedBox.shrink();
    }

    // Cache expensive computations outside build()
    final statusIcon = computeOnce(
      'statusIcon',
      _getStatusIcon,
      dependencies: [_isOnline, _isDataStale],
    );
    final backgroundColor = computeOnce(
      'backgroundColor',
      _getBackgroundColor,
      dependencies: [_isOnline, _isDataStale],
    );
    final borderColor = computeOnce(
      'borderColor',
      _getBorderColor,
      dependencies: [_isOnline, _isDataStale],
    );
    final iconColor = computeOnce(
      'iconColor',
      _getIconColor,
      dependencies: [_isOnline, _isDataStale],
    );
    final textColor = computeOnce(
      'textColor',
      _getTextColor,
      dependencies: [_isOnline, _isDataStale],
    );
    final statusText = computeOnce(
      'statusText',
      _getStatusText,
      dependencies: [_isOnline, _isDataStale],
    );
    final formattedSyncTime = _lastSyncTime != null
        ? computeOnce(
            'formattedSyncTime',
            _formatLastSyncTime,
            dependencies: [_lastSyncTime],
          )
        : null;

    return Container(
      padding:
          widget.padding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: widget.iconColor ?? iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  statusText,
                  style:
                      widget.textStyle ??
                      TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                ),
                if (widget.showLastSync &&
                    _lastSyncTime != null &&
                    formattedSyncTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Last synced: $formattedSyncTime',
                    style: TextStyle(
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.showRefreshButton && _isOnline) ...[
            const SizedBox(width: 8),
            buildOnce(
              'refreshButton',
              () => _buildRefreshButton(iconColor),
              dependencies: [_isRefreshing, iconColor],
            ),
          ],
        ],
      ),
    );
  }

  IconData _getStatusIcon() {
    if (!_isOnline) {
      return Icons.cloud_off;
    } else if (_isDataStale) {
      return Icons.schedule;
    } else {
      return Icons.check_circle;
    }
  }

  Color _getBackgroundColor() {
    if (!_isOnline) {
      return Colors.grey.withValues(alpha: 0.1);
    } else if (_isDataStale) {
      return Colors.amber.withValues(alpha: 0.1);
    } else {
      return Colors.green.withValues(alpha: 0.1);
    }
  }

  Color _getBorderColor() {
    if (!_isOnline) {
      return Colors.grey.withValues(alpha: 0.3);
    } else if (_isDataStale) {
      return Colors.amber.withValues(alpha: 0.3);
    } else {
      return Colors.green.withValues(alpha: 0.3);
    }
  }

  Color _getIconColor() {
    if (!_isOnline) {
      return Colors.grey;
    } else if (_isDataStale) {
      return Colors.amber.shade700;
    } else {
      return Colors.green;
    }
  }

  Color _getTextColor() {
    if (!_isOnline) {
      return Colors.grey.shade700;
    } else if (_isDataStale) {
      return Colors.amber.shade800;
    } else {
      return Colors.green.shade700;
    }
  }

  String _getStatusText() {
    if (!_isOnline) {
      return 'Offline - Using cached data';
    } else if (_isDataStale) {
      return 'Data may be outdated';
    } else {
      return 'Data is up to date';
    }
  }

  String _formatLastSyncTime() {
    if (_lastSyncTime == null) return 'Never';

    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildRefreshButton(Color iconColor) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isRefreshing ? null : _refreshData,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: _isRefreshing
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                ),
              )
            : Icon(Icons.refresh, size: 12, color: iconColor),
      ),
    );
  }

  Future<void> _refreshData() async {
    if (_isRefreshing || !_isOnline) return;

    setState(() {
      _isRefreshing = true;
    });

    // Invalidate refresh button cache when refreshing state changes
    invalidateCache('refreshButton');

    try {
      // Force sync all services
      await Future.wait([
        _templeService.forceSyncAll(),
        _preferencesService.forceSyncAll(),
        _favoritesService.forceSyncAll(),
      ]);

      // Clear caches to force fresh data
      await _templeService.clearCache();
      await _preferencesService.clearCache();

      // Recheck freshness
      await _checkDataFreshness();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh data: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });

        // Invalidate refresh button cache when refreshing state changes
        invalidateCache('refreshButton');
      }
    }
  }
}

/// Compact version of the data freshness indicator
class CompactDataFreshnessIndicator extends StatelessWidget {
  final VoidCallback? onTap;
  final Color? color;

  const CompactDataFreshnessIndicator({super.key, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DataFreshnessIndicator(
        showLastSync: false,
        showRefreshButton: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        textStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
        iconColor: color,
      ),
    );
  }
}

/// Badge version for showing data freshness status
class DataFreshnessBadge extends StatefulWidget {
  final Widget child;
  final bool showBadge;

  const DataFreshnessBadge({
    super.key,
    required this.child,
    this.showBadge = true,
  });

  @override
  State<DataFreshnessBadge> createState() => _DataFreshnessBadgeState();
}

class _DataFreshnessBadgeState extends State<DataFreshnessBadge> {
  final UserTempleService _templeService = UserTempleService();
  bool _isDataStale = false;
  bool _isOnline = true;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _checkDataFreshness();
    _listenToSyncStatus();
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  void _listenToSyncStatus() {
    _syncSubscription = _templeService.syncStatusStream.listen((status) {
      if (mounted) {
        _checkDataFreshness();
      }
    });
  }

  Future<void> _checkDataFreshness() async {
    try {
      final freshness = await _templeService.getDataFreshness();

      if (mounted) {
        setState(() {
          _isDataStale = freshness['isStale'] == true;
          _isOnline = freshness['isOnline'] == true;
        });
      }
    } catch (e) {
      debugPrint('DataFreshnessBadge: Error checking freshness - $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBadge || (!_isDataStale && _isOnline)) {
      return widget.child;
    }

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.amber : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        ),
      ],
    );
  }
}
