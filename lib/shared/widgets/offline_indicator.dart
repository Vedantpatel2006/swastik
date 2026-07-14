import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/offline/offline_manager.dart';

/// Widget that shows offline status and sync information
class OfflineIndicator extends StatefulWidget {
  final bool showSyncStatus;
  final EdgeInsets? padding;
  final Color? backgroundColor;
  final Color? textColor;

  const OfflineIndicator({
    super.key,
    this.showSyncStatus = true,
    this.padding,
    this.backgroundColor,
    this.textColor,
  });

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator>
    with TickerProviderStateMixin {
  final OfflineManager _offlineManager = OfflineManager();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeOfflineManager();
    _listenToConnectivity();
    _listenToSyncStatus();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _pulseController.repeat(reverse: true);
  }

  Future<void> _initializeOfflineManager() async {
    try {
      await _offlineManager.initialize();
      if (mounted) {
        setState(() {
          _isOnline = _offlineManager.isOnline;
          _pendingSyncCount = _offlineManager.pendingSyncCount;
        });
      }
    } catch (e) {
      // Handle initialization error
    }
  }

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<SyncStatus>? _syncSubscription;

  void _listenToConnectivity() {
    // Register connectivity stream with automatic cleanup (requirement 3.1, 3.2)
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (result) {
        if (mounted) {
          final isOnline = result != ConnectivityResult.none;
          setState(() {
            _isOnline = isOnline;
          });

          if (isOnline) {
            _slideController.forward();
          } else {
            _slideController.reverse();
          }
        }
      },
    );
  }

  void _listenToSyncStatus() {
    // Register sync status stream with automatic cleanup (requirement 3.1, 3.2)
    _syncSubscription = _offlineManager.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
          _pendingSyncCount = _offlineManager.pendingSyncCount;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline &&
        _syncStatus == SyncStatus.synced &&
        _pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildStatusIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getStatusTitle(),
                      style: TextStyle(
                        color: widget.textColor ?? Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.showSyncStatus &&
                        _getStatusSubtitle().isNotEmpty)
                      Text(
                        _getStatusSubtitle(),
                        style: TextStyle(
                          color: (widget.textColor ?? Colors.white).withValues(
                            alpha: 0.8,
                          ),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (_syncStatus == SyncStatus.syncing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.textColor ?? Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    Widget icon;

    switch (_syncStatus) {
      case SyncStatus.syncing:
        iconData = Icons.sync;
        break;
      case SyncStatus.failed:
        iconData = Icons.sync_problem;
        break;
      case SyncStatus.conflict:
        iconData = Icons.warning;
        break;
      default:
        iconData = _isOnline ? Icons.cloud_done : Icons.cloud_off;
    }

    icon = Icon(iconData, color: widget.textColor ?? Colors.white, size: 20);

    if (_syncStatus == SyncStatus.syncing) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _pulseAnimation.value, child: icon);
        },
      );
    }

    return icon;
  }

  Color _getBackgroundColor() {
    if (!_isOnline) {
      return const Color(0xFFEF4444); // Red for offline
    }

    switch (_syncStatus) {
      case SyncStatus.syncing:
        return const Color(0xFFFF7A00); // Blue for syncing
      case SyncStatus.failed:
        return const Color(0xFFEF4444); // Red for failed
      case SyncStatus.conflict:
        return const Color(0xFFF59E0B); // Amber for conflict
      case SyncStatus.pending:
        return const Color(0xFF8B5CF6); // Purple for pending
      default:
        return const Color(0xFF10B981); // Green for synced
    }
  }

  String _getStatusTitle() {
    if (!_isOnline) {
      return 'Offline Mode';
    }

    switch (_syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing...';
      case SyncStatus.failed:
        return 'Sync Failed';
      case SyncStatus.conflict:
        return 'Sync Conflict';
      case SyncStatus.pending:
        return 'Sync Pending';
      default:
        return 'Online';
    }
  }

  String _getStatusSubtitle() {
    if (!_isOnline && _pendingSyncCount > 0) {
      return '$_pendingSyncCount changes will sync when online';
    }

    switch (_syncStatus) {
      case SyncStatus.syncing:
        return 'Syncing $_pendingSyncCount items';
      case SyncStatus.failed:
        return 'Tap to retry sync';
      case SyncStatus.conflict:
        return 'Manual resolution required';
      case SyncStatus.pending:
        return '$_pendingSyncCount items pending';
      default:
        return '';
    }
  }
}

/// Compact offline indicator for app bars
class CompactOfflineIndicator extends StatefulWidget {
  final VoidCallback? onTap;

  const CompactOfflineIndicator({super.key, this.onTap});

  @override
  State<CompactOfflineIndicator> createState() =>
      _CompactOfflineIndicatorState();
}

class _CompactOfflineIndicatorState extends State<CompactOfflineIndicator>
    with SingleTickerProviderStateMixin {
  final OfflineManager _offlineManager = OfflineManager();
  final Connectivity _connectivity = Connectivity();

  bool _isOnline = true;
  SyncStatus _syncStatus = SyncStatus.synced;
  int _pendingSyncCount = 0;

  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  StreamSubscription<SyncStatus>? _syncSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeOfflineManager();
    _listenToConnectivity();
    _listenToSyncStatus();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );
  }

  Future<void> _initializeOfflineManager() async {
    try {
      await _offlineManager.initialize();
      if (mounted) {
        setState(() {
          _isOnline = _offlineManager.isOnline;
          _pendingSyncCount = _offlineManager.pendingSyncCount;
        });
      }
    } catch (e) {
      // Handle initialization error
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (mounted) {
        setState(() {
          _isOnline = result != ConnectivityResult.none;
        });
      }
    });
  }

  void _listenToSyncStatus() {
    _syncSubscription = _offlineManager.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _syncStatus = status;
          _pendingSyncCount = _offlineManager.pendingSyncCount;
        });

        if (status == SyncStatus.syncing) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _connectivitySubscription?.cancel();
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOnline &&
        _syncStatus == SyncStatus.synced &&
        _pendingSyncCount == 0) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _getBackgroundColor().withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getBackgroundColor(), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            if (_pendingSyncCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                _pendingSyncCount.toString(),
                style: TextStyle(
                  color: _getBackgroundColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;

    if (!_isOnline) {
      iconData = Icons.cloud_off;
    } else {
      switch (_syncStatus) {
        case SyncStatus.syncing:
          iconData = Icons.sync;
          break;
        case SyncStatus.failed:
          iconData = Icons.sync_problem;
          break;
        case SyncStatus.conflict:
          iconData = Icons.warning;
          break;
        default:
          iconData = Icons.cloud_done;
      }
    }

    Widget icon = Icon(iconData, color: _getBackgroundColor(), size: 16);

    if (_syncStatus == SyncStatus.syncing) {
      return AnimatedBuilder(
        animation: _rotationAnimation,
        builder: (context, child) {
          return Transform.rotate(
            angle: _rotationAnimation.value * 2 * 3.14159,
            child: icon,
          );
        },
      );
    }

    return icon;
  }

  Color _getBackgroundColor() {
    if (!_isOnline) {
      return const Color(0xFFEF4444);
    }

    switch (_syncStatus) {
      case SyncStatus.syncing:
        return const Color(0xFFFF7A00);
      case SyncStatus.failed:
        return const Color(0xFFEF4444);
      case SyncStatus.conflict:
        return const Color(0xFFF59E0B);
      case SyncStatus.pending:
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF10B981);
    }
  }
}
