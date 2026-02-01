import 'dart:async';
import 'dart:io';
import '../models/job.dart';
import '../models/job_status.dart';
import 'live_activity_service.dart';
import 'ongoing_notification_service.dart';

/// Unified cross-platform job notification service
///
/// Automatically uses the appropriate native notification system:
/// - iOS: Live Activity (Lock Screen, Dynamic Island)
/// - Android: Ongoing Notification (persistent notification drawer)
class JobNotificationService {
  final LiveActivityService _liveActivityService = LiveActivityService();
  final OngoingNotificationService _ongoingNotificationService =
      OngoingNotificationService();

  /// Get the current platform
  String get platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'other';
  }

  /// Check if job notifications are supported on this device
  Future<bool> isSupported() async {
    if (Platform.isIOS) {
      return await _liveActivityService.isSupported();
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.isSupported();
    }
    return false;
  }

  /// Check if notifications are enabled by the user
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isIOS) {
      return await _liveActivityService.areActivitiesEnabled();
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.areNotificationsEnabled();
    }
    return false;
  }

  /// Start a job notification
  Future<JobNotificationResult> start({
    required String jobId,
    required String title,
    required String jobType,
    int initialProgress = 0,
    String? initialMessage,
  }) async {
    if (Platform.isIOS) {
      final result = await _liveActivityService.startActivity(
        jobId: jobId,
        title: title,
        jobType: jobType,
        initialProgress: initialProgress,
        initialMessage: initialMessage,
      );
      return JobNotificationResult(
        success: result.success,
        activityId: result.activityId,
        jobId: result.jobId,
        error: result.error,
        isUnsupported: result.isUnsupported,
      );
    } else if (Platform.isAndroid) {
      final result = await _ongoingNotificationService.startNotification(
        jobId: jobId,
        title: title,
        jobType: jobType,
        initialProgress: initialProgress,
        initialMessage: initialMessage,
      );
      return JobNotificationResult(
        success: result.success,
        activityId: result.notificationId?.toString(),
        jobId: result.jobId,
        error: result.error,
        isUnsupported: result.isUnsupported,
      );
    }
    return JobNotificationResult.unsupported();
  }

  /// Start a job notification from a SeennJob
  Future<JobNotificationResult> startFromJob(SeennJob job) async {
    return start(
      jobId: job.jobId,
      title: job.title,
      jobType: job.jobType,
      initialProgress: job.progress,
      initialMessage: job.message,
    );
  }

  /// Update a job notification
  Future<bool> update({
    required String jobId,
    required int progress,
    required String status,
    String? message,
    String? stageName,
    int? stageIndex,
    int? stageTotal,
    int? estimatedEndTime,
    String? resultUrl,
  }) async {
    if (Platform.isIOS) {
      return await _liveActivityService.updateActivity(
        jobId: jobId,
        progress: progress,
        status: status,
        message: message,
        stageName: stageName,
        stageIndex: stageIndex,
        stageTotal: stageTotal,
        eta: estimatedEndTime,
        resultUrl: resultUrl,
      );
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.updateNotification(
        jobId: jobId,
        progress: progress,
        status: status,
        message: message,
        stageName: stageName,
        stageIndex: stageIndex,
        stageTotal: stageTotal,
        estimatedEndTime: estimatedEndTime,
      );
    }
    return false;
  }

  /// Update a job notification from a SeennJob
  Future<bool> updateFromJob(SeennJob job) async {
    return update(
      jobId: job.jobId,
      progress: job.progress,
      status: job.status.name,
      message: job.message,
      stageName: job.stage?.name,
      stageIndex: job.stage?.current,
      stageTotal: job.stage?.total,
      estimatedEndTime: job.estimatedCompletionTime != null
          ? (job.estimatedCompletionTime!.millisecondsSinceEpoch / 1000).round()
          : null,
      resultUrl: job.resultUrl,
    );
  }

  /// End a job notification
  Future<bool> end({
    required String jobId,
    required int finalProgress,
    required String finalStatus,
    String? message,
    String? resultUrl,
    String? errorMessage,
    int? dismissAfter,
  }) async {
    // Default dismiss times: iOS 5min (300s), Android 5s (5000ms)
    final dismissMs = dismissAfter ?? (Platform.isIOS ? 300000 : 5000);

    if (Platform.isIOS) {
      return await _liveActivityService.endActivity(
        jobId: jobId,
        finalProgress: finalProgress,
        finalStatus: finalStatus,
        message: message,
        resultUrl: resultUrl,
        errorMessage: errorMessage,
        dismissAfter: dismissMs / 1000, // iOS uses seconds
      );
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.endNotification(
        jobId: jobId,
        finalProgress: finalProgress,
        finalStatus: finalStatus,
        message: message,
        resultUrl: resultUrl,
        errorMessage: errorMessage,
        dismissAfter: dismissMs,
      );
    }
    return false;
  }

  /// End a job notification from a SeennJob
  Future<bool> endFromJob(SeennJob job) async {
    return end(
      jobId: job.jobId,
      finalProgress: job.progress,
      finalStatus: job.status.name,
      message: job.message,
      resultUrl: job.resultUrl,
      errorMessage: job.errorMessage,
    );
  }

  /// Cancel a job notification immediately
  Future<bool> cancel(String jobId) async {
    if (Platform.isIOS) {
      return await _liveActivityService.cancelActivity(jobId);
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.cancelNotification(jobId);
    }
    return false;
  }

  /// Check if a notification is active for a job
  Future<bool> isActive(String jobId) async {
    if (Platform.isIOS) {
      return await _liveActivityService.isActivityActive(jobId);
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.isNotificationActive(jobId);
    }
    return false;
  }

  /// Get all active notification job IDs
  Future<List<String>> getActiveIds() async {
    if (Platform.isIOS) {
      return await _liveActivityService.getActiveActivityIds();
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.getActiveNotificationIds();
    }
    return [];
  }

  /// Cancel all notifications
  Future<bool> cancelAll() async {
    if (Platform.isIOS) {
      return await _liveActivityService.cancelAllActivities();
    } else if (Platform.isAndroid) {
      return await _ongoingNotificationService.cancelAllNotifications();
    }
    return false;
  }

  /// Automatically sync notification with job state
  ///
  /// Call this whenever the job state changes.
  /// Returns true if notification was updated, false otherwise.
  Future<bool> syncWithJob(
    SeennJob job, {
    bool autoStart = true,
    bool autoEnd = true,
  }) async {
    final isCurrentlyActive = await isActive(job.jobId);

    // Start notification if job is pending/running and not started
    if ((job.status == JobStatus.pending || job.status == JobStatus.running) &&
        !isCurrentlyActive &&
        autoStart) {
      final result = await startFromJob(job);
      return result.success;
    }

    // Update if running and already started
    if (job.status == JobStatus.running && isCurrentlyActive) {
      return await updateFromJob(job);
    }

    // End if completed/failed and was started
    if (job.isTerminal && isCurrentlyActive && autoEnd) {
      return await endFromJob(job);
    }

    return false;
  }
}

/// Result from starting a job notification
class JobNotificationResult {
  final bool success;
  final String? activityId;
  final String? jobId;
  final String? error;
  final bool isUnsupported;

  JobNotificationResult({
    required this.success,
    this.activityId,
    this.jobId,
    this.error,
    this.isUnsupported = false,
  });

  factory JobNotificationResult.unsupported() {
    return JobNotificationResult(
      success: false,
      error: 'Job notifications are not supported on this platform',
      isUnsupported: true,
    );
  }
}
