import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/job.dart';
import '../models/job_status.dart';
import '../models/stage_info.dart';
import '../state/state_manager.dart';

/// Service for managing and subscribing to job updates
class JobsService {
  final StateManager _stateManager;

  JobsService(this._stateManager);

  /// Get stream for all jobs
  Stream<Map<String, SeennJob>> get all$ => _stateManager.jobs$;

  /// Get all current jobs (sync)
  Map<String, SeennJob> get all => _stateManager.jobs;

  /// Subscribe to a specific job
  /// Returns a JobTracker with multiple convenient streams
  JobTracker subscribe(String jobId) {
    return JobTracker(
      jobId: jobId,
      stateManager: _stateManager,
    );
  }

  /// Get job by ID (sync)
  SeennJob? get(String jobId) => _stateManager.getJob(jobId);

  /// Get stream for specific job
  Stream<SeennJob?> stream(String jobId) => _stateManager.jobStream(jobId);

  /// Get jobs filtered by status
  List<SeennJob> byStatus(JobStatus status) {
    return _stateManager.jobs.values
        .where((job) => job.status == status)
        .toList();
  }

  /// Get stream of jobs filtered by status
  Stream<List<SeennJob>> byStatus$(JobStatus status) {
    return _stateManager.jobs$
        .map((jobs) =>
            jobs.values.where((job) => job.status == status).toList())
        .distinct();
  }

  /// Get active (non-terminal) jobs
  List<SeennJob> get active {
    return _stateManager.jobs.values.where((job) => !job.isTerminal).toList();
  }

  /// Get stream of active jobs
  Stream<List<SeennJob>> get active$ {
    return _stateManager.jobs$
        .map((jobs) => jobs.values.where((job) => !job.isTerminal).toList())
        .distinct();
  }

  /// Get parent jobs (jobs with children)
  List<SeennJob> get parents {
    return _stateManager.jobs.values.where((job) => job.isParent).toList();
  }

  /// Get stream of parent jobs
  Stream<List<SeennJob>> get parents$ {
    return _stateManager.jobs$
        .map((jobs) => jobs.values.where((job) => job.isParent).toList())
        .distinct();
  }

  /// Get child jobs (jobs with parent)
  List<SeennJob> get children {
    return _stateManager.jobs.values.where((job) => job.isChild).toList();
  }

  /// Get stream of child jobs
  Stream<List<SeennJob>> get children$ {
    return _stateManager.jobs$
        .map((jobs) => jobs.values.where((job) => job.isChild).toList())
        .distinct();
  }

  /// Get children of a specific parent job
  List<SeennJob> childrenOf(String parentJobId) {
    return _stateManager.jobs.values
        .where((job) => job.parent?.parentJobId == parentJobId)
        .toList();
  }

  /// Get stream of children of a specific parent job
  Stream<List<SeennJob>> childrenOf$(String parentJobId) {
    return _stateManager.jobs$
        .map((jobs) => jobs.values
            .where((job) => job.parent?.parentJobId == parentJobId)
            .toList())
        .distinct();
  }

  /// Clear specific job from local state
  void clear(String jobId) {
    _stateManager.removeJob(jobId);
  }

  /// Clear all jobs from local state
  void clearAll() {
    _stateManager.clear();
  }
}

/// Job tracker returned by JobsService.subscribe()
/// Provides convenient streams for tracking a specific job
class JobTracker {
  final String jobId;
  final StateManager _stateManager;

  JobTracker({
    required this.jobId,
    required StateManager stateManager,
  }) : _stateManager = stateManager;

  /// Stream of job updates (emits whenever job changes)
  Stream<SeennJob> get onUpdate {
    return _stateManager.jobStream(jobId).whereNotNull();
  }

  /// Stream of progress updates
  Stream<ProgressUpdate> get onProgress {
    return onUpdate
        .map((job) => ProgressUpdate(
              progress: job.progress,
              message: job.message,
              stage: job.stage,
              etaRemaining: job.etaRemaining,
              etaFormatted: job.etaFormatted,
              etaConfidence: job.etaConfidence,
            ))
        .distinct();
  }

  /// Stream of child progress updates (for parent jobs with children)
  Stream<ChildProgressUpdate> get onChildProgress {
    return onUpdate.where((job) => job.hasChildren).map((job) {
      final children = job.children!;
      return ChildProgressUpdate(
        parentProgress: job.progress,
        total: children.total,
        completed: children.completed,
        failed: children.failed,
        running: children.running,
        pending: children.pending,
      );
    }).distinct();
  }

  /// Stream that emits when job completes
  Stream<SeennJob> get onComplete {
    return onUpdate.where((job) => job.status == JobStatus.completed);
  }

  /// Stream that emits when job fails
  Stream<SeennJob> get onFailed {
    return onUpdate.where((job) => job.status == JobStatus.failed);
  }

  /// Stream that emits when job is cancelled
  Stream<SeennJob> get onCancelled {
    return onUpdate.where((job) => job.status == JobStatus.cancelled);
  }

  /// Stream that emits when job reaches terminal state (completed, failed, or cancelled)
  Stream<SeennJob> get onTerminal {
    return onUpdate.where((job) => job.isTerminal);
  }

  /// Get current job state (sync)
  SeennJob? get current => _stateManager.getJob(jobId);

  /// Check if job exists in state
  bool get exists => current != null;

  /// Check if job is completed
  bool get isCompleted => current?.status == JobStatus.completed;

  /// Check if job is failed
  bool get isFailed => current?.status == JobStatus.failed;

  /// Check if job is cancelled
  bool get isCancelled => current?.status == JobStatus.cancelled;

  /// Check if job is in terminal state
  bool get isTerminal => current?.isTerminal ?? false;
}

/// Progress update data
class ProgressUpdate {
  final int progress;
  final String? message;
  final StageInfo? stage;
  final int? etaRemaining;
  final String? etaFormatted;
  final double? etaConfidence;

  const ProgressUpdate({
    required this.progress,
    this.message,
    this.stage,
    this.etaRemaining,
    this.etaFormatted,
    this.etaConfidence,
  });

  /// Legacy getter for eta in seconds
  int? get eta => etaRemaining != null ? (etaRemaining! / 1000).round() : null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProgressUpdate &&
          progress == other.progress &&
          message == other.message &&
          etaRemaining == other.etaRemaining;

  @override
  int get hashCode => Object.hash(progress, message, etaRemaining);
}

/// Child progress update data (for parent jobs)
class ChildProgressUpdate {
  final int parentProgress;
  final int total;
  final int completed;
  final int failed;
  final int running;
  final int pending;

  const ChildProgressUpdate({
    required this.parentProgress,
    required this.total,
    required this.completed,
    required this.failed,
    required this.running,
    required this.pending,
  });

  /// Legacy getters for backwards compatibility
  int get childrenCompleted => completed;
  int get childrenTotal => total;

  /// Percentage of children completed (0-100)
  double get percentComplete => total > 0 ? (completed / total) * 100 : 0;

  /// Check if all children are done (completed or failed)
  bool get allDone => completed + failed >= total;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChildProgressUpdate &&
          parentProgress == other.parentProgress &&
          total == other.total &&
          completed == other.completed &&
          failed == other.failed &&
          running == other.running &&
          pending == other.pending;

  @override
  int get hashCode =>
      Object.hash(parentProgress, total, completed, failed, running, pending);
}

// Note: Using RxDart's whereNotNull() extension
