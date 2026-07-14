import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/services/accessibility_service.dart';
import '../../../shared/widgets/accessibility/accessible_button.dart';

/// Enhanced temple card with comprehensive accessibility features
class AccessibilityEnhancedTempleCard extends StatefulWidget {
  final String templeId;
  final String templeName;
  final String location;
  final String? distance;
  final double? rating;
  final bool isLive;
  final bool isFavorite;
  final List<String> features;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onLiveDarshanTap;

  const AccessibilityEnhancedTempleCard({
    super.key,
    required this.templeId,
    required this.templeName,
    required this.location,
    this.distance,
    this.rating,
    this.isLive = false,
    this.isFavorite = false,
    this.features = const [],
    this.onTap,
    this.onFavoriteToggle,
    this.onLiveDarshanTap,
  });

  @override
  State<AccessibilityEnhancedTempleCard> createState() => _AccessibilityEnhancedTempleCardState();
}

class _AccessibilityEnhancedTempleCardState extends State<AccessibilityEnhancedTempleCard> {
  final FocusNode _cardFocusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _cardFocusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _cardFocusNode.removeListener(_onFocusChange);
    _cardFocusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _cardFocusNode.hasFocus;
    });

    if (_isFocused) {
      _announceCardContent();
    }
  }

  void _announceCardContent() {
    final accessibilityService = AccessibilityService.instance;
    final semanticLabel = accessibilityService.createTempleSemanticLabel(
      widget.templeName,
      location: widget.location,
      distance: widget.distance,
      isLive: widget.isLive,
      isFavorite: widget.isFavorite,
    );
    
    accessibilityService.announceToScreenReader(semanticLabel);
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityService = AccessibilityService.instance;
    final theme = Theme.of(context);
    
    // Create comprehensive semantic label
    final semanticLabel = accessibilityService.createTempleSemanticLabel(
      widget.templeName,
      location: widget.location,
      distance: widget.distance,
      isLive: widget.isLive,
      isFavorite: widget.isFavorite,
    );

    // Enhanced card with accessibility features
    return Semantics(
      label: semanticLabel,
      button: true,
      enabled: widget.onTap != null,
      child: Focus(
        focusNode: _cardFocusNode,
        onKeyEvent: _handleKeyPress,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            onLongPress: _showContextMenu,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 88.0, // Minimum touch target size
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isFocused 
                      ? theme.primaryColor
                      : (_isHovered ? theme.primaryColor.withValues(alpha: 0.5) : Colors.transparent),
                  width: _isFocused ? 3 : (_isHovered ? 2 : 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isFocused ? 0.2 : 0.1),
                    blurRadius: _isFocused ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 8),
                    _buildLocation(),
                    if (widget.features.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildFeatures(),
                    ],
                    const SizedBox(height: 12),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.templeName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                semanticsLabel: 'Temple name: ${widget.templeName}',
              ),
              if (widget.rating != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 16,
                      color: Colors.amber[600],
                      semanticLabel: 'Rating',
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.rating!.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall,
                      semanticsLabel: '${widget.rating!.toStringAsFixed(1)} stars',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (widget.isLive) _buildLiveIndicator(),
      ],
    );
  }

  Widget _buildLiveIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            semanticsLabel: 'Live darshan available',
          ),
        ],
      ),
    );
  }

  Widget _buildLocation() {
    return Row(
      children: [
        Icon(
          Icons.location_on,
          size: 16,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          semanticLabel: 'Location',
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            widget.location,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            semanticsLabel: 'Located at ${widget.location}',
          ),
        ),
        if (widget.distance != null) ...[
          const SizedBox(width: 8),
          Text(
            widget.distance!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
            semanticsLabel: '${widget.distance} away',
          ),
        ],
      ],
    );
  }

  Widget _buildFeatures() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: widget.features.take(3).map((feature) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            feature,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).primaryColor,
            ),
            semanticsLabel: 'Feature: $feature',
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.isLive) ...[
          Expanded(
            child: AccessibleButton(
              onPressed: widget.onLiveDarshanTap,
              semanticLabel: 'Watch live darshan for ${widget.templeName}',
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44), // Minimum touch target
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_arrow, size: 18),
                  SizedBox(width: 4),
                  Text('Watch Live'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        AccessibleIconButton(
          onPressed: widget.onFavoriteToggle,
          semanticLabel: widget.isFavorite 
              ? 'Remove ${widget.templeName} from favorites'
              : 'Add ${widget.templeName} to favorites',
          icon: Icon(
            widget.isFavorite ? Icons.favorite : Icons.favorite_border,
            color: widget.isFavorite ? Colors.red : null,
          ),
          iconSize: 24,
        ),
      ],
    );
  }

  KeyEventResult _handleKeyPress(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      // Handle Enter/Space for activation
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }

      // Handle F key for favorite toggle
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        widget.onFavoriteToggle?.call();
        return KeyEventResult.handled;
      }

      // Handle L key for live darshan
      if (event.logicalKey == LogicalKeyboardKey.keyL && widget.isLive) {
        widget.onLiveDarshanTap?.call();
        return KeyEventResult.handled;
      }

      // Handle M key for context menu
      if (event.logicalKey == LogicalKeyboardKey.keyM) {
        _showContextMenu();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _showContextMenu() {
    final accessibilityService = AccessibilityService.instance;
    accessibilityService.announceToScreenReader('Context menu opened for ${widget.templeName}');
    
    showModalBottomSheet(
      context: context,
      builder: (context) => AccessibilityContextMenu(
        templeName: widget.templeName,
        isLive: widget.isLive,
        isFavorite: widget.isFavorite,
        onViewDetails: widget.onTap,
        onToggleFavorite: widget.onFavoriteToggle,
        onWatchLive: widget.onLiveDarshanTap,
      ),
    );
  }
}

/// Accessibility-enhanced context menu
class AccessibilityContextMenu extends StatelessWidget {
  final String templeName;
  final bool isLive;
  final bool isFavorite;
  final VoidCallback? onViewDetails;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onWatchLive;

  const AccessibilityContextMenu({
    super.key,
    required this.templeName,
    required this.isLive,
    required this.isFavorite,
    this.onViewDetails,
    this.onToggleFavorite,
    this.onWatchLive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            templeName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
            semanticsLabel: 'Context menu for $templeName',
          ),
          const SizedBox(height: 16),
          AccessibleButton(
            onPressed: () {
              Navigator.pop(context);
              onViewDetails?.call();
            },
            semanticLabel: 'View details for $templeName',
            child: const Row(
              children: [
                Icon(Icons.info_outline),
                SizedBox(width: 12),
                Text('View Details'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (isLive) ...[
            AccessibleButton(
              onPressed: () {
                Navigator.pop(context);
                onWatchLive?.call();
              },
              semanticLabel: 'Watch live darshan for $templeName',
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 12),
                  Text('Watch Live Darshan'),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          AccessibleButton(
            onPressed: () {
              Navigator.pop(context);
              onToggleFavorite?.call();
            },
            semanticLabel: isFavorite 
                ? 'Remove $templeName from favorites'
                : 'Add $templeName to favorites',
            child: Row(
              children: [
                Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                const SizedBox(width: 12),
                Text(isFavorite ? 'Remove from Favorites' : 'Add to Favorites'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AccessibleTextButton(
            onPressed: () => Navigator.pop(context),
            semanticLabel: 'Close context menu',
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Enhanced search field with comprehensive accessibility
class AccessibilityEnhancedSearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String? hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onVoiceSearch;
  final VoidCallback? onClear;
  final bool showVoiceButton;
  final bool autofocus;

  const AccessibilityEnhancedSearchField({
    super.key,
    this.controller,
    this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onVoiceSearch,
    this.onClear,
    this.showVoiceButton = true,
    this.autofocus = false,
  });

  @override
  State<AccessibilityEnhancedSearchField> createState() => _AccessibilityEnhancedSearchFieldState();
}

class _AccessibilityEnhancedSearchFieldState extends State<AccessibilityEnhancedSearchField> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() {
        _hasText = hasText;
      });
    }
    widget.onChanged?.call(_controller.text);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      AccessibilityService.instance.announceToScreenReader(
        'Search field focused. ${widget.hintText ?? "Enter search terms"}',
      );
    }
  }

  void _clearSearch() {
    _controller.clear();
    widget.onClear?.call();
    AccessibilityService.instance.announceToScreenReader('Search cleared');
    
    // Provide haptic feedback
    AccessibilityService.instance.provideAccessibleHapticFeedback(
      context,
      type: 'lightImpact',
    );
  }

  void _triggerVoiceSearch() {
    widget.onVoiceSearch?.call();
    AccessibilityService.instance.announceToScreenReader('Voice search activated');
    
    // Provide haptic feedback
    AccessibilityService.instance.provideAccessibleHapticFeedback(
      context,
      type: 'mediumImpact',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Search temples. ${widget.hintText ?? "Enter temple name or location"}',
      textField: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56), // Larger touch target
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            hintText: widget.hintText ?? 'Search temples...',
            prefixIcon: const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.search, size: 24),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_hasText)
                  Semantics(
                    label: 'Clear search',
                    button: true,
                    child: IconButton(
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                      tooltip: 'Clear search',
                      iconSize: 24,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
                if (widget.showVoiceButton)
                  Semantics(
                    label: 'Voice search',
                    button: true,
                    child: IconButton(
                      onPressed: _triggerVoiceSearch,
                      icon: const Icon(Icons.mic),
                      tooltip: 'Voice search',
                      iconSize: 24,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                  ),
              ],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Enhanced filter chip with accessibility features
class AccessibilityEnhancedFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final String? semanticLabel;

  const AccessibilityEnhancedFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.onSelected,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? '${isSelected ? "Selected" : "Unselected"} filter: $label',
      button: true,
      selected: isSelected,
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          onSelected?.call(selected);
          
          // Announce state change
          final message = selected ? 'Selected $label filter' : 'Deselected $label filter';
          AccessibilityService.instance.announceToScreenReader(message);
          
          // Provide haptic feedback
          AccessibilityService.instance.provideAccessibleHapticFeedback(
            context,
            type: 'lightImpact',
          );
        },
        materialTapTargetSize: MaterialTapTargetSize.padded,
        visualDensity: VisualDensity.comfortable,
      ),
    );
  }
}

/// Enhanced slider with accessibility features
class AccessibilityEnhancedSlider extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String label;
  final String semanticLabel;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;

  const AccessibilityEnhancedSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.label,
    required this.semanticLabel,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  State<AccessibilityEnhancedSlider> createState() => _AccessibilityEnhancedSliderState();
}

class _AccessibilityEnhancedSliderState extends State<AccessibilityEnhancedSlider> {
  late double _currentValue;
  bool _isChanging = false;

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
  }

  @override
  void didUpdateWidget(AccessibilityEnhancedSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && !_isChanging) {
      _currentValue = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Semantics(
          label: '${widget.semanticLabel}. Current value: ${_currentValue.round()}',
          slider: true,
          value: _currentValue.round().toString(),
          increasedValue: ((_currentValue + 1).clamp(widget.min, widget.max)).round().toString(),
          decreasedValue: ((_currentValue - 1).clamp(widget.min, widget.max)).round().toString(),
          child: Slider(
            value: _currentValue,
            min: widget.min,
            max: widget.max,
            divisions: widget.divisions,
            label: _currentValue.round().toString(),
            onChanged: (value) {
              setState(() {
                _currentValue = value;
                _isChanging = true;
              });
              widget.onChanged?.call(value);
            },
            onChangeEnd: (value) {
              _isChanging = false;
              widget.onChangeEnd?.call(value);
              
              // Announce final value
              AccessibilityService.instance.announceToScreenReader(
                '${widget.semanticLabel} set to ${value.round()}',
              );
              
              // Provide haptic feedback
              AccessibilityService.instance.provideAccessibleHapticFeedback(
                context,
                type: 'lightImpact',
              );
            },
          ),
        ),
        Text(
          '${widget.min.round()} - ${widget.max.round()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}