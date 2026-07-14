import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../shared/models/temple.dart';
import '../../../core/themes/app_colors.dart';
import '../../../core/services/accessibility_service.dart';
import '../services/realtime_live_provider.dart';
import '../services/temple_status_service.dart';
import '../services/temple_share_service.dart';
import '../../../shared/widgets/animations/app_animations.dart';
import 'temple_image_section.dart';
import 'temple_content_section.dart';

/// Temple card widget for displaying temple information in lists
/// Optimized with shared animation controllers for memory efficiency
class TempleCard extends StatefulWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLiveDarshanTap;
  final VoidCallback? onBookingTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final bool showBookingButton;
  final bool showStatusIndicator;
  final bool showShareButton;
  final int? animationIndex; // For staggered animations

  const TempleCard({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.onBookingTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.showBookingButton = true,
    this.showStatusIndicator = true,
    this.showShareButton = true,
    this.animationIndex,
    this.margin,
  });

  final EdgeInsetsGeometry? margin;

  @override
  State<TempleCard> createState() => _TempleCardState();
}

/// Extension to provide visibility control for animation optimization
extension TempleCardVisibility on TempleCard {
  /// Set visibility for animation pausing when card goes off-screen
  /// This should be called by parent widgets (like ListView) to optimize animations
  void setVisibility(BuildContext context, bool isVisible) {
    final state = context.findAncestorStateOfType<_TempleCardState>();
    state?.setCardVisibility(isVisible);
  }
}

class _TempleCardState extends State<TempleCard> with TickerProviderStateMixin {
  AnimationController? _cardController;
  AnimationController? _liveIndicatorController;
  AnimationController? _favoriteController;

  StreamSubscription<LiveStatus>? _liveDarshanSubscription;
  LiveDarshanInfo? _currentLiveDarshanInfo;
  bool _isLive = false;
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();

    _initializeAnimations();
    _initializeLiveDarshanStream();
  }

  void _initializeAnimations() {
    // Initialize live status from temple data
    _currentLiveDarshanInfo = widget.temple.liveDarshan;
    _isLive = widget.temple.liveDarshan?.isCurrentlyLive == true;

    if (widget.onFavoriteToggle != null) {
      _favoriteController = AnimationController(
        vsync: this,
        duration: AppAnimations.normalDuration,
      );
    }

    if (widget.animationIndex != null) {
      _cardController = AnimationController(
        vsync: this,
        duration: AppAnimations.fastDuration,
      );
      _cardController!.forward();
    }

    if (widget.showLiveIndicator && _isLive) {
      _liveIndicatorController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      _liveIndicatorController!.repeat();
    }

    setCardVisibility(_isVisible);
  }

  void _initializeLiveDarshanStream() {
    // Subscribe to real-time live status updates (NEW SYSTEM)
    if (widget.temple.liveDarshan?.isConfiguredByAdmin == true) {
      try {
        // Import the new provider at the top of the file:
        // import '../services/realtime_live_provider.dart';

        final liveProvider = RealtimeLiveProvider();
        final subscription = liveProvider
            .watchLiveStatus(widget.temple.id)
            .listen(
              (liveStatus) {
                if (mounted) {
                  setState(() {
                    final wasLive = _isLive;
                    _isLive =
                        liveStatus.isLive &&
                        !liveStatus.isStale; // Don't show live if data is stale

                    // Start or stop live indicator animation based on live status
                    if (_isLive && !wasLive) {
                      _liveIndicatorController ??= AnimationController(
                        vsync: this,
                        duration: const Duration(milliseconds: 1500),
                      );
                      if (_isVisible) {
                        _liveIndicatorController!.repeat();
                      }
                    } else if (!_isLive && wasLive) {
                      _liveIndicatorController?.stop();
                      _liveIndicatorController?.reset();
                    }
                  });
                }
              },
              onError: (error) {
                // Handle stream errors gracefully
                debugPrint('Error watching live status: $error');
              },
            );

        _liveDarshanSubscription = subscription;
      } catch (error) {
        debugPrint('RealtimeLiveProvider error: $error');
      }
    }
  }

  void setCardVisibility(bool isVisible) {
    if (_isVisible != isVisible) {
      _isVisible = isVisible;

      if (!isVisible && _liveIndicatorController != null) {
        _liveIndicatorController!.stop();
      } else if (isVisible && _liveIndicatorController != null && _isLive) {
        _liveIndicatorController!.repeat();
      }
    }
  }

  @override
  void dispose() {
    _cardController?.dispose();
    _liveIndicatorController?.dispose();
    _favoriteController?.dispose();
    _liveDarshanSubscription?.cancel();
    super.dispose();
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          // Open/Closed Status
          if (widget.showStatusIndicator)
            _buildStatusIndicator(),
          
          const Spacer(),
          
          // Quick Booking Button
          if (widget.showBookingButton && widget.temple.acceptsBookings)
            _buildBookingButton(),
          
          if (widget.showBookingButton && widget.temple.acceptsBookings && widget.showShareButton)
            const SizedBox(width: 8),
          
          // Share Button
          if (widget.showShareButton)
            _buildShareButton(),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final status = TempleStatusService.getTempleStatus(widget.temple);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: status.statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status.statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: status.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.getStatusWithTime(),
            style: TextStyle(
              color: status.statusColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onBookingTap?.call();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppColors.orangeGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryOrange.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              const Text(
                'Book',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          TempleShareService.shareTemple(widget.temple, context: context);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
          child: Icon(
            Icons.share,
            size: 16,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;
    final semanticLabel = accessibilityService.createTempleSemanticLabel(
      widget.temple.name,
      location: widget.temple.location.address,
      distance: widget.showDistance && widget.temple.distanceFromUser != null
          ? '${widget.temple.distanceFromUser!.toStringAsFixed(1)} km'
          : null,
      isLive:
          widget.showLiveIndicator &&
          widget.temple.liveDarshan?.isCurrentlyLive == true,
      isFavorite: widget.temple.isFavorite,
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: widget.onTap != null,
      onTap: widget.onTap != null
          ? () {
              accessibilityService.provideAccessibleHapticFeedback(
                context,
                type: 'lightImpact',
              );
              widget.onTap!();
            }
          : null,
      child: Container(
        margin:
            widget.margin ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap != null
                ? () {
                    accessibilityService.provideAccessibleHapticFeedback(
                      context,
                      type: 'lightImpact',
                    );
                    widget.onTap!();
                  }
                : null,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TempleImageSection(
                  temple: widget.temple,
                  showLiveIndicator: widget.showLiveIndicator,
                  showFavoriteButton: widget.onFavoriteToggle != null,
                  isLive: _isLive,
                  currentLiveDarshanInfo: _currentLiveDarshanInfo,
                  liveIndicatorController: _liveIndicatorController,
                  favoriteController: _favoriteController,
                  onLiveDarshanTap: widget.onLiveDarshanTap,
                  onFavoriteToggle: widget.onFavoriteToggle != null
                      ? () {
                          HapticFeedback.selectionClick();
                          widget.onFavoriteToggle!();
                        }
                      : null,
                ),
                TempleContentSection(
                  temple: widget.temple,
                  showLiveIndicator: widget.showLiveIndicator,
                  showDistance: widget.showDistance,
                  currentLiveDarshanInfo: _currentLiveDarshanInfo,
                  isLive: _isLive,
                  liveIndicatorController: _liveIndicatorController,
                  onLiveDarshanTap: widget.onLiveDarshanTap,
                ),
                // Action buttons row
                if (widget.showBookingButton || widget.showStatusIndicator || widget.showShareButton)
                  _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visibility-aware temple card wrapper for use in scrollable lists
/// Automatically pauses animations when cards go off-screen (requirement 2.3)
class VisibilityAwareTempleCard extends StatefulWidget {
  final Temple temple;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLiveDarshanTap;
  final VoidCallback? onBookingTap;
  final bool showDistance;
  final bool showLiveIndicator;
  final bool showBookingButton;
  final bool showStatusIndicator;
  final bool showShareButton;
  final int? animationIndex;

  const VisibilityAwareTempleCard({
    super.key,
    required this.temple,
    this.onTap,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
    this.onBookingTap,
    this.showDistance = true,
    this.showLiveIndicator = true,
    this.showBookingButton = true,
    this.showStatusIndicator = true,
    this.showShareButton = true,
    this.animationIndex,
  });

  @override
  State<VisibilityAwareTempleCard> createState() =>
      _VisibilityAwareTempleCardState();
}

class _VisibilityAwareTempleCardState extends State<VisibilityAwareTempleCard> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    // Schedule visibility check after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVisibility();
    });
  }

  void _checkVisibility() {
    if (!mounted) return;

    final renderBox = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final screenHeight = MediaQuery.of(context).size.height;

    // Check if card is visible on screen (with some buffer)
    final isVisible =
        position.dy < screenHeight + 100 && position.dy + size.height > -100;

    if (_isVisible != isVisible) {
      setState(() {
        _isVisible = isVisible;
      });

      // Notify the temple card about visibility change
      final cardState = _cardKey.currentContext
          ?.findAncestorStateOfType<_TempleCardState>();
      cardState?.setCardVisibility(isVisible);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Check visibility on scroll
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkVisibility();
        });
        return false;
      },
      child: TempleCard(
        key: _cardKey,
        temple: widget.temple,
        onTap: widget.onTap,
        onFavoriteToggle: widget.onFavoriteToggle != null
            ? () {
                HapticFeedback.selectionClick();
                widget.onFavoriteToggle!();
              }
            : null,
        onLiveDarshanTap: widget.onLiveDarshanTap,
        onBookingTap: widget.onBookingTap,
        showDistance: widget.showDistance,
        showLiveIndicator: widget.showLiveIndicator,
        showBookingButton: widget.showBookingButton,
        showStatusIndicator: widget.showStatusIndicator,
        showShareButton: widget.showShareButton,
        animationIndex: widget.animationIndex,
      ),
    );
  }
}
