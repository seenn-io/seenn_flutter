import 'job_status.dart';
import 'job_result.dart';
import 'job_error.dart';

/// How parent job progress is calculated from children
enum ChildProgressMode {
  average,
  weighted,
  sequential;

  static ChildProgressMode fromString(String value) {
    return ChildProgressMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ChildProgressMode.average,
    );
  }
}

/// Parent info for child jobs - matches @seenn/types ParentInfo
class ParentInfo {
  /// Parent job ID
  final String parentJobId;

  /// Child index within parent (0-based)
  final int childIndex;

  const ParentInfo({
    required this.parentJobId,
    required this.childIndex,
  });

  factory ParentInfo.fromJson(Map<String, dynamic> json) {
    return ParentInfo(
      parentJobId: json['parentJobId'] as String,
      childIndex: json['childIndex'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'parentJobId': parentJobId,
        'childIndex': childIndex,
      };
}

/// Children stats for parent jobs - matches @seenn/types ChildrenStats
class ChildrenStats {
  /// Total number of children
  final int total;

  /// Number of completed children
  final int completed;

  /// Number of failed children
  final int failed;

  /// Number of running children
  final int running;

  /// Number of pending children
  final int pending;

  const ChildrenStats({
    required this.total,
    required this.completed,
    required this.failed,
    required this.running,
    required this.pending,
  });

  factory ChildrenStats.fromJson(Map<String, dynamic> json) {
    return ChildrenStats(
      total: json['total'] as int,
      completed: json['completed'] as int? ?? 0,
      failed: json['failed'] as int? ?? 0,
      running: json['running'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'total': total,
        'completed': completed,
        'failed': failed,
        'running': running,
        'pending': pending,
      };

  /// Progress as percentage (0-100)
  double get progress => total > 0 ? (completed / total) * 100 : 0;

  /// Check if all children are done (completed or failed)
  bool get allDone => completed + failed >= total;
}

/// Summary of a child job - matches @seenn/types ChildJobSummary
class ChildJobSummary {
  /// Child job ID
  final String id;

  /// Child index within parent (0-based)
  final int childIndex;

  /// Child job title
  final String title;

  /// Child job status
  final JobStatus status;

  /// Child progress (0-100)
  final int progress;

  /// Child status message
  final String? message;

  /// Child result
  final JobResult? result;

  /// Child error
  final JobError? error;

  /// Child creation timestamp
  final DateTime createdAt;

  /// Child last update timestamp
  final DateTime updatedAt;

  /// Child completion timestamp
  final DateTime? completedAt;

  const ChildJobSummary({
    required this.id,
    required this.childIndex,
    required this.title,
    required this.status,
    required this.progress,
    this.message,
    this.result,
    this.error,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory ChildJobSummary.fromJson(Map<String, dynamic> json) {
    return ChildJobSummary(
      id: json['id'] as String,
      childIndex: json['childIndex'] as int,
      title: json['title'] as String,
      status: JobStatus.fromString(json['status'] as String),
      progress: json['progress'] as int? ?? 0,
      message: json['message'] as String?,
      result: json['result'] != null
          ? JobResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? JobError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'childIndex': childIndex,
        'title': title,
        'status': status.name,
        'progress': progress,
        if (message != null) 'message': message,
        if (result != null) 'result': result!.toJson(),
        if (error != null) 'error': error!.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };
}
