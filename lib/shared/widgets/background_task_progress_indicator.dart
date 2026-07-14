import 'dart:async';
import 'package:flutter/material.dart';
import '../services/background/background_processor.dart';

/// Widget that displays progress for background tasks
class BackgroundTaskProgressIndicator extends StatefulWidget {
  final String? taskId;
  final bool showAllTasks;
  final Widget? child;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final Color progressColor;
  final double borderRadius;

  const BackgroundTaskProgressIndicator({
    super.key,
    this.taskId,
    this.showAllTasks = false,
    this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.backgroundColor = const Color(0xFF1F2937),
    this.progressColor = const Color(0xFFFF7A00),
    this.borderRadius = 8.0,
  });

  @override
  State<BackgroundTaskProgressIndicator> createState() =>
      _BackgroundTaskProgressIndicatorState();
}

class _BackgroundTaskProgressIndicatorState
    extends State<BackgroundTaskProgressIndicator>
    with TickerProviderStateMixin {
  final BackgroundProcessor _backgroundProcessor = BackgroundProcessor();
  StreamSubscription<BackgroundTaskEvent>? _eventSubscription;
  final Map<String, TaskProgressInfo> _taskProgress = {};
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _setupEventListener();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  void _setupEventListener() {
    _eventSubscription = _backgroundProcessor.events.listen((event) {
      if (widget.taskId != null && event.taskId != widget.taskId) return;

      setState(() {
        switch (event.type) {
          case BackgroundTaskEventType.queued:
            _taskProgress[event.taskId] = TaskProgressInfo(
              taskId: event.taskId,
              taskName: event.taskName,
              progress: 0.0,
              status: TaskStatus.queued,
            );
            _fadeController.forward();
            break;

          case BackgroundTaskEventType.started:
            _taskProgress[event.taskId] = TaskProgressInfo(
              taskId: event.taskId,
              taskName: event.taskName,
              progress: 0.0,
              status: TaskStatus.running,
            );
            _fadeController.forward();
            break;

          case BackgroundTaskEventType.progress:
            final existing = _taskProgress[event.taskId];
            if (existing != null) {
              _taskProgress[event.taskId] = existing.copyWith(
                progress: event.progress ?? 0.0,
              );
            }
            break;

          case BackgroundTaskEventType.completed:
            final existing = _taskProgress[event.taskId];
            if (existing != null) {
              _taskProgress[event.taskId] = existing.copyWith(
                progress: 1.0,
                status: TaskStatus.completed,
              );
              // Remove completed task after a delay
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _taskProgress.remove(event.taskId);
                    if (_taskProgress.isEmpty) {
                      _fadeController.reverse();
                    }
                  });
                }
              });
            }
            break;

          case BackgroundTaskEventType.error:
            final existing = _taskProgress[event.taskId];
            if (existing != null) {
              _taskProgress[event.taskId] = existing.copyWith(
                status: TaskStatus.error,
                error: event.error?.toString(),
              );
              // Remove error task after a delay
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) {
                  setState(() {
                    _taskProgress.remove(event.taskId);
                    if (_taskProgress.isEmpty) {
                      _fadeController.reverse();
                    }
                  });
                }
              });
            }
            break;

          case BackgroundTaskEventType.cancelled:
            _taskProgress.remove(event.taskId);
            if (_taskProgress.isEmpty) {
              _fadeController.reverse();
            }
            break;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_taskProgress.isEmpty) {
      return widget.child ?? const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (widget.child != null) widget.child!,
        Positioned(
          bottom: 16,
          left: 16,
          right: 16,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _taskProgress.values
                    .map((task) => _buildTaskProgressItem(task))
                    .toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskProgressItem(TaskProgressInfo task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStatusIcon(task.status),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.taskName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (task.status == TaskStatus.running)
                Text(
                  '${(task.progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              if (task.status == TaskStatus.running)
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white70,
                    size: 16,
                  ),
                  onPressed: () => _backgroundProcessor.cancelTask(task.taskId),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
            ],
          ),
          if (task.status == TaskStatus.running) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(widget.progressColor),
              minHeight: 3,
            ),
          ],
          if (task.error != null) ...[
            const SizedBox(height: 4),
            Text(
              task.error!,
              style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.queued:
        return const Icon(Icons.schedule, color: Colors.orange, size: 16);
      case TaskStatus.running:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
          ),
        );
      case TaskStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 16);
      case TaskStatus.error:
        return const Icon(Icons.error, color: Color(0xFFEF4444), size: 16);
    }
  }
}

/// Information about a background task's progress
class TaskProgressInfo {
  final String taskId;
  final String taskName;
  final double progress;
  final TaskStatus status;
  final String? error;

  TaskProgressInfo({
    required this.taskId,
    required this.taskName,
    required this.progress,
    required this.status,
    this.error,
  });

  TaskProgressInfo copyWith({
    String? taskId,
    String? taskName,
    double? progress,
    TaskStatus? status,
    String? error,
  }) {
    return TaskProgressInfo(
      taskId: taskId ?? this.taskId,
      taskName: taskName ?? this.taskName,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }
}

/// Status of a background task
enum TaskStatus { queued, running, completed, error }
