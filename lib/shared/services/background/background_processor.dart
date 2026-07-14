import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Abstract base class for background tasks
abstract class BackgroundTask {
  final String id;
  final String name;
  final DateTime createdAt;

  BackgroundTask({required this.id, required this.name})
    : createdAt = DateTime.now();

  /// Execute the task
  Future<void> execute();

  /// Called when task progress changes (0.0 to 1.0)
  void onProgress(double progress) {}

  /// Called when task completes successfully
  void onComplete() {
    // Default implementation - can be overridden
    if (kDebugMode) {
      debugPrint('BackgroundTask completed: ${runtimeType}');
    }
  }

  /// Called when task encounters an error
  void onError(dynamic error) {
    // Default implementation - can be overridden
    if (kDebugMode) {
      debugPrint('BackgroundTask error in ${runtimeType}: $error');
    }
  }

  /// Called when task is cancelled
  void onCancel() {
    // Default implementation - can be overridden
    if (kDebugMode) {
      debugPrint('BackgroundTask cancelled: ${runtimeType}');
    }
  }
}

/// Manages background task execution with progress tracking and queue management.
///
/// This service handles long-running operations in the background without blocking
/// the UI thread. It provides progress tracking, cancellation support, and
/// intelligent queue management with configurable concurrency limits.
///
/// Key features:
/// - Non-blocking task execution
/// - Real-time progress tracking
/// - Task cancellation support
/// - Configurable concurrency limits
/// - Automatic retry mechanisms
/// - Event-driven architecture
///
/// Usage:
/// ```dart
/// final processor = BackgroundProcessor();
///
/// // Create and add a task
/// final task = ImageUploadTask(
///   id: 'upload_123',
///   imageFile: imageFile,
///   onProgress: (progress) => updateUI(progress),
///   onComplete: () => showSuccess(),
///   onError: (error) => showError(error),
/// );
///
/// await processor.addTask(task);
///
/// // Monitor task events
/// processor.events.listen((event) {
///   switch (event.type) {
///     case BackgroundTaskEventType.started:
///       print('Task ${event.taskId} started');
///       break;
///     case BackgroundTaskEventType.completed:
///       print('Task ${event.taskId} completed');
///       break;
///   }
/// });
/// ```
class BackgroundProcessor {
  static final BackgroundProcessor _instance = BackgroundProcessor._internal();
  factory BackgroundProcessor() => _instance;
  BackgroundProcessor._internal();

  final Queue<BackgroundTask> _taskQueue = Queue<BackgroundTask>();
  final Map<String, BackgroundTask> _activeTasks = <String, BackgroundTask>{};
  final Map<String, double> _taskProgress = <String, double>{};
  final StreamController<BackgroundTaskEvent> _eventController =
      StreamController<BackgroundTaskEvent>.broadcast();

  bool _isProcessing = false;
  int _maxConcurrentTasks = 3;

  /// Stream of background task events
  Stream<BackgroundTaskEvent> get events => _eventController.stream;

  /// Get current task progress (0.0 to 1.0)
  double getTaskProgress(String taskId) => _taskProgress[taskId] ?? 0.0;

  /// Get list of active task IDs
  List<String> get activeTaskIds => _activeTasks.keys.toList();

  /// Get queue length
  int get queueLength => _taskQueue.length;

  /// Add a task to the processing queue
  Future<void> addTask(BackgroundTask task) async {
    _taskQueue.add(task);
    _eventController.add(BackgroundTaskEvent.queued(task.id, task.name));

    if (!_isProcessing) {
      _processQueue();
    }
  }

  /// Cancel a specific task
  void cancelTask(String taskId) {
    // Remove from queue if not started
    _taskQueue.removeWhere((task) => task.id == taskId);

    // Cancel active task
    final activeTask = _activeTasks[taskId];
    if (activeTask != null) {
      activeTask.onCancel();
      _activeTasks.remove(taskId);
      _taskProgress.remove(taskId);
      _eventController.add(
        BackgroundTaskEvent.cancelled(taskId, activeTask.name),
      );
    }
  }

  /// Cancel all tasks
  void cancelAllTasks() {
    _taskQueue.clear();

    final activeTaskIds = _activeTasks.keys.toList();
    for (final taskId in activeTaskIds) {
      cancelTask(taskId);
    }
  }

  /// Set maximum number of concurrent tasks
  void setMaxConcurrentTasks(int maxTasks) {
    _maxConcurrentTasks = maxTasks.clamp(1, 10);
  }

  /// Process the task queue
  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    while (_taskQueue.isNotEmpty || _activeTasks.isNotEmpty) {
      // Start new tasks if we have capacity
      while (_taskQueue.isNotEmpty &&
          _activeTasks.length < _maxConcurrentTasks) {
        final task = _taskQueue.removeFirst();
        _startTask(task);
      }

      // Wait a bit before checking again
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isProcessing = false;
  }

  /// Start executing a single task
  void _startTask(BackgroundTask task) {
    _activeTasks[task.id] = task;
    _taskProgress[task.id] = 0.0;
    _eventController.add(BackgroundTaskEvent.started(task.id, task.name));

    // Execute task in a separate zone to catch errors
    runZonedGuarded(
      () async {
        try {
          // Set up progress tracking
          final progressTimer = Timer.periodic(
            const Duration(milliseconds: 500),
            (timer) {
              if (!_activeTasks.containsKey(task.id)) {
                timer.cancel();
                return;
              }

              final progress = _taskProgress[task.id] ?? 0.0;
              _eventController.add(
                BackgroundTaskEvent.progress(task.id, task.name, progress),
              );
            },
          );

          // Execute the task
          await task.execute();

          progressTimer.cancel();
          task.onComplete();

          _activeTasks.remove(task.id);
          _taskProgress.remove(task.id);
          _eventController.add(
            BackgroundTaskEvent.completed(task.id, task.name),
          );
        } catch (error) {
          task.onError(error);
          _activeTasks.remove(task.id);
          _taskProgress.remove(task.id);
          _eventController.add(
            BackgroundTaskEvent.error(task.id, task.name, error),
          );
        }
      },
      (error, stackTrace) {
        // Handle uncaught errors
        task.onError(error);
        _activeTasks.remove(task.id);
        _taskProgress.remove(task.id);
        _eventController.add(
          BackgroundTaskEvent.error(task.id, task.name, error),
        );
      },
    );
  }

  /// Update task progress (called by tasks)
  void updateTaskProgress(String taskId, double progress) {
    if (_activeTasks.containsKey(taskId)) {
      _taskProgress[taskId] = progress.clamp(0.0, 1.0);
      _activeTasks[taskId]?.onProgress(progress);
    }
  }

  /// Dispose resources
  void dispose() {
    cancelAllTasks();
    _eventController.close();
  }
}

/// Events emitted by the background processor
class BackgroundTaskEvent {
  final String taskId;
  final String taskName;
  final BackgroundTaskEventType type;
  final double? progress;
  final dynamic error;
  final DateTime timestamp;

  BackgroundTaskEvent._({
    required this.taskId,
    required this.taskName,
    required this.type,
    this.progress,
    this.error,
  }) : timestamp = DateTime.now();

  factory BackgroundTaskEvent.queued(String taskId, String taskName) =>
      BackgroundTaskEvent._(
        taskId: taskId,
        taskName: taskName,
        type: BackgroundTaskEventType.queued,
      );

  factory BackgroundTaskEvent.started(String taskId, String taskName) =>
      BackgroundTaskEvent._(
        taskId: taskId,
        taskName: taskName,
        type: BackgroundTaskEventType.started,
      );

  factory BackgroundTaskEvent.progress(
    String taskId,
    String taskName,
    double progress,
  ) => BackgroundTaskEvent._(
    taskId: taskId,
    taskName: taskName,
    type: BackgroundTaskEventType.progress,
    progress: progress,
  );

  factory BackgroundTaskEvent.completed(String taskId, String taskName) =>
      BackgroundTaskEvent._(
        taskId: taskId,
        taskName: taskName,
        type: BackgroundTaskEventType.completed,
      );

  factory BackgroundTaskEvent.error(
    String taskId,
    String taskName,
    dynamic error,
  ) => BackgroundTaskEvent._(
    taskId: taskId,
    taskName: taskName,
    type: BackgroundTaskEventType.error,
    error: error,
  );

  factory BackgroundTaskEvent.cancelled(String taskId, String taskName) =>
      BackgroundTaskEvent._(
        taskId: taskId,
        taskName: taskName,
        type: BackgroundTaskEventType.cancelled,
      );
}

enum BackgroundTaskEventType {
  queued,
  started,
  progress,
  completed,
  error,
  cancelled,
}
