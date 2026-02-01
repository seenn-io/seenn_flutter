import 'job_status.dart';
import 'stage_info.dart';
import 'queue_info.dart';
import 'job_result.dart';
import 'job_error.dart';
import 'parent_child.dart';

/// Main job object - matches @seenn/types SeennJob
class SeennJob {
  /// Unique job identifier (ULID format)
  final String jobId;

  /// User who owns this job
  final String userId;

  /// Application ID
  final String appId;

  /// Current job status
  final JobStatus status;

  /// Human-readable job title
  final String title;

  /// Job type for categorization
  final String jobType;

  /// Workflow ID for ETA tracking (default: jobType)
  final String? workflowId;

  /// Progress percentage (0-100)
  final int progress;

  /// Current status message
  final String? message;

  /// Stage information for multi-step jobs
  final StageInfo? stage;

  /// Estimated completion timestamp (ISO 8601)
  final String? estimatedCompletionAt;

  /// ETA confidence score (0.0 - 1.0)
  final double? etaConfidence;

  /// Number of historical jobs used to calculate ETA
  final int? etaBasedOn;

  /// Queue position info
  final QueueInfo? queue;

  /// Job result on completion
  final JobResult? result;

  /// Error details on failure
  final JobError? error;

  /// Custom metadata
  final Map<String, dynamic>? metadata;

  /// Parent info (if this is a child job)
  final ParentInfo? parent;

  /// Children stats (if this is a parent job)
  final ChildrenStats? children;

  /// Progress calculation mode for parent jobs
  final ChildProgressMode? childProgressMode;

  /// Job creation timestamp (ISO 8601)
  final DateTime createdAt;

  /// Last update timestamp (ISO 8601)
  final DateTime updatedAt;

  /// When the job started running (ISO 8601)
  final DateTime? startedAt;

  /// Job completion timestamp (ISO 8601)
  final DateTime? completedAt;

  const SeennJob({
    required this.jobId,
    required this.userId,
    required this.appId,
    required this.status,
    required this.title,
    required this.jobType,
    this.workflowId,
    required this.progress,
    this.message,
    this.stage,
    this.estimatedCompletionAt,
    this.etaConfidence,
    this.etaBasedOn,
    this.queue,
    this.result,
    this.error,
    this.metadata,
    this.parent,
    this.children,
    this.childProgressMode,
    required this.createdAt,
    required this.updatedAt,
    this.startedAt,
    this.completedAt,
  });

  factory SeennJob.fromJson(Map<String, dynamic> json) {
    return SeennJob(
      jobId: json['jobId'] as String,
      userId: json['userId'] as String,
      appId: json['appId'] as String,
      status: JobStatus.fromString(json['status'] as String),
      title: json['title'] as String,
      jobType: json['jobType'] as String? ?? json['type'] as String? ?? 'job',
      workflowId: json['workflowId'] as String?,
      progress: json['progress'] as int? ?? 0,
      message: json['message'] as String?,
      stage: json['stage'] != null
          ? StageInfo.fromJson(json['stage'] as Map<String, dynamic>)
          : null,
      estimatedCompletionAt: json['estimatedCompletionAt'] as String?,
      etaConfidence: (json['etaConfidence'] as num?)?.toDouble(),
      etaBasedOn: json['etaBasedOn'] as int?,
      queue: json['queue'] != null
          ? QueueInfo.fromJson(json['queue'] as Map<String, dynamic>)
          : null,
      result: json['result'] != null
          ? JobResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? JobError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
      parent: json['parent'] != null
          ? ParentInfo.fromJson(json['parent'] as Map<String, dynamic>)
          : null,
      children: json['children'] != null
          ? ChildrenStats.fromJson(json['children'] as Map<String, dynamic>)
          : null,
      childProgressMode: json['childProgressMode'] != null
          ? ChildProgressMode.fromString(json['childProgressMode'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'jobId': jobId,
        'userId': userId,
        'appId': appId,
        'status': status.name,
        'title': title,
        'jobType': jobType,
        if (workflowId != null) 'workflowId': workflowId,
        'progress': progress,
        if (message != null) 'message': message,
        if (stage != null) 'stage': stage!.toJson(),
        if (estimatedCompletionAt != null)
          'estimatedCompletionAt': estimatedCompletionAt,
        if (etaConfidence != null) 'etaConfidence': etaConfidence,
        if (etaBasedOn != null) 'etaBasedOn': etaBasedOn,
        if (queue != null) 'queue': queue!.toJson(),
        if (result != null) 'result': result!.toJson(),
        if (error != null) 'error': error!.toJson(),
        if (metadata != null) 'metadata': metadata,
        if (parent != null) 'parent': parent!.toJson(),
        if (children != null) 'children': children!.toJson(),
        if (childProgressMode != null)
          'childProgressMode': childProgressMode!.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };

  // ===========================================
  // Computed Properties
  // ===========================================

  /// Check if job is in terminal state
  bool get isTerminal => status.isTerminal;

  /// Check if this is a child job
  bool get isChild => parent != null;

  /// Check if this is a parent job
  bool get isParent => children != null;

  /// Check if job has children
  bool get hasChildren => children != null && children!.total > 0;

  /// Child completion progress (0-100)
  double? get childProgress => children?.progress;

  /// Get result URL if available
  String? get resultUrl => result?.url;

  /// Get error message if available
  String? get errorMessage => error?.message;

  // ===========================================
  // ETA Helpers
  // ===========================================

  /// Get estimated completion time as DateTime
  DateTime? get estimatedCompletionTime => estimatedCompletionAt != null
      ? DateTime.tryParse(estimatedCompletionAt!)
      : null;

  /// Get remaining time in milliseconds (null if no ETA)
  int? get etaRemaining {
    final eta = estimatedCompletionTime;
    if (eta == null) return null;
    final now = DateTime.now();
    final diff = eta.difference(now).inMilliseconds;
    return diff > 0 ? diff : 0;
  }

  /// Check if job is past its estimated completion time
  bool get isPastEta {
    final eta = estimatedCompletionTime;
    if (eta == null) return false;
    return DateTime.now().isAfter(eta);
  }

  /// Get formatted ETA remaining (e.g., "2m 30s")
  String? get etaFormatted {
    final remaining = etaRemaining;
    if (remaining == null) return null;

    final seconds = (remaining / 1000).round();
    if (seconds <= 0) return 'any moment';

    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }

  // ===========================================
  // Legacy Getters (backwards compatibility)
  // ===========================================

  /// Legacy: job type (use jobType instead)
  String? get type => jobType;

  /// Legacy: parent job ID (use parent?.parentJobId instead)
  String? get parentJobId => parent?.parentJobId;

  /// Legacy: child count (use children?.total instead)
  int? get childCount => children?.total;

  /// Legacy: completed children (use children?.completed instead)
  int? get childCompleted => children?.completed;

  /// Legacy: eta in seconds (use etaRemaining instead)
  int? get eta => etaRemaining != null ? (etaRemaining! / 1000).round() : null;

  // ===========================================
  // Copy With
  // ===========================================

  SeennJob copyWith({
    String? jobId,
    String? userId,
    String? appId,
    JobStatus? status,
    String? title,
    String? jobType,
    String? workflowId,
    int? progress,
    String? message,
    StageInfo? stage,
    String? estimatedCompletionAt,
    double? etaConfidence,
    int? etaBasedOn,
    QueueInfo? queue,
    JobResult? result,
    JobError? error,
    Map<String, dynamic>? metadata,
    ParentInfo? parent,
    ChildrenStats? children,
    ChildProgressMode? childProgressMode,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return SeennJob(
      jobId: jobId ?? this.jobId,
      userId: userId ?? this.userId,
      appId: appId ?? this.appId,
      status: status ?? this.status,
      title: title ?? this.title,
      jobType: jobType ?? this.jobType,
      workflowId: workflowId ?? this.workflowId,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      stage: stage ?? this.stage,
      estimatedCompletionAt:
          estimatedCompletionAt ?? this.estimatedCompletionAt,
      etaConfidence: etaConfidence ?? this.etaConfidence,
      etaBasedOn: etaBasedOn ?? this.etaBasedOn,
      queue: queue ?? this.queue,
      result: result ?? this.result,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
      parent: parent ?? this.parent,
      children: children ?? this.children,
      childProgressMode: childProgressMode ?? this.childProgressMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
