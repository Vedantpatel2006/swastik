import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

/// Safe image widget that handles loading errors gracefully
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SafeNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNullOrEmpty) {
      return _buildErrorWidget(context);
    }

    Widget imageWidget = Image.network(
      imageUrl!,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? _buildLoadingWidget(context, loadingProgress);
      },
      errorBuilder: (context, error, stackTrace) {
        ErrorHandler.handleError(
          error,
          stackTrace: stackTrace,
          context: 'SafeNetworkImage',
        );
        return errorWidget ?? _buildErrorWidget(context);
      },
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildLoadingWidget(BuildContext context, ImageChunkEvent progress) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: CircularProgressIndicator(
          value: progress.expectedTotalBytes != null
              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
              : null,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_not_supported,
        color: Colors.grey,
      ),
    );
  }
}

/// Safe text widget that handles null values
class SafeText extends StatelessWidget {
  final String? text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final String fallbackText;

  const SafeText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    this.fallbackText = '',
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.safeValue.isNotEmpty ? text! : fallbackText,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Safe distance display widget
class SafeDistanceWidget extends StatelessWidget {
  final double? distance;
  final String unit;
  final TextStyle? style;

  const SafeDistanceWidget({
    super.key,
    required this.distance,
    this.unit = 'km',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (distance == null) {
      return const SizedBox.shrink();
    }

    return Text(
      '${distance!.toStringAsFixed(1)} $unit',
      style: style ?? TextStyle(
        fontSize: 12,
        color: Colors.grey[600],
      ),
    );
  }
}

/// Safe button widget with error handling
class SafeButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final bool enabled;
  final String? disabledMessage;

  const SafeButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.enabled = true,
    this.disabledMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: enabled && onPressed != null
          ? () {
              ErrorHandler.safeExecuteSync(
                () => onPressed!(),
                context: 'SafeButton.onPressed',
                showErrorToUser: true,
                buildContext: context,
              );
            }
          : null,
      style: style,
      child: child,
    );
  }
}

/// Safe async button widget with loading state
class SafeAsyncButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final Widget child;
  final Widget? loadingChild;
  final ButtonStyle? style;
  final bool enabled;

  const SafeAsyncButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.loadingChild,
    this.style,
    this.enabled = true,
  });

  @override
  State<SafeAsyncButton> createState() => _SafeAsyncButtonState();
}

class _SafeAsyncButtonState extends State<SafeAsyncButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.enabled && widget.onPressed != null && !_isLoading
          ? _handlePress
          : null,
      style: widget.style,
      child: _isLoading
          ? (widget.loadingChild ?? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          : widget.child,
    );
  }

  Future<void> _handlePress() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    await ErrorHandler.safeExecute(
      () => widget.onPressed!(),
      context: 'SafeAsyncButton.onPressed',
      showErrorToUser: true,
      buildContext: context,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

/// Safe list view with error handling
class SafeListView<T> extends StatelessWidget {
  final List<T>? items;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const SafeListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.emptyWidget,
    this.errorWidget,
    this.controller,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final safeItems = items.safeValue;

    if (safeItems.isEmpty) {
      return emptyWidget ?? const Center(
        child: Text('No items to display'),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: safeItems.length,
      itemBuilder: (context, index) {
        return ErrorHandler.safeExecuteSync(
          () => itemBuilder(context, safeItems[index], index),
          context: 'SafeListView.itemBuilder',
          fallbackValue: const SizedBox.shrink(),
        ) ?? const SizedBox.shrink();
      },
    );
  }
}