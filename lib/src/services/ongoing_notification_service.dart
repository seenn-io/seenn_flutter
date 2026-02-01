import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../models/job.dart';

/// Service for managing Android Ongoing Notifications
class OngoingNotificationService {
  static const MethodChannel _methodChannel =
      MethodChannel('io.seenn/flutter_plugin');

  /// Check if Ongoing Notifications are supported on this device
  Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('isOngoingNotificationSupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if notifications are enabled by the user
  Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return false;

    try {
      final result =
          await _methodChannel.invokeMethod<bool>('areNotificationsEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start an Ongoing Notification for a job
  ///
  /// Returns the notification result with ID if successful
  Future<OngoingNotificationResult> startNotification({
    required String jobId,
    required String title,
    required String jobType,
    int initialProgress = 0,
    String? initialMessage,
  }) async {
    if (!Platform.isAndroid) {
      return OngoingNotificationResult.unsupported();
    }

    try {
      final result =
          await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'startOngoingNotification',
        {
          'jobId': jobId,
          'title': title,
          'jobType': jobType,
          'initialProgress': initialProgress,
          'initialMessage': initialMessage,
        },
      );

      if (result != null) {
        return OngoingNotificationResult.success(
          notificationId: result['notificationId'] as int,
          jobId: result['jobId'] as String,
        );
      }
      return OngoingNotificationResult.error('Unknown error');
    } on PlatformException catch (e) {
      return OngoingNotificationResult.error(
          e.message ?? 'Failed to start notification');
    }
  }

  /// Start an Ongoing Notification from a SeennJob
  Future<OngoingNotificationResult> startNotificationFromJob(
      SeennJob job) async {
    return startNotification(
      jobId: job.jobId,
      title: job.title,
      jobType: job.jobType,
      initialProgress: job.progress,
      initialMessage: job.message,
    );
  }

  /// Update an Ongoing Notification
  Future<bool> updateNotification({
    required String jobId,
    required int progress,
    required String status,
    String? message,
    String? stageName,
    int? stageIndex,
    int? stageTotal,
    int? estimatedEndTime,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'updateOngoingNotification',
        {
          'jobId': jobId,
          'progress': progress,
          'status': status,
          'message': message,
          'stageName': stageName,
          'stageIndex': stageIndex,
          'stageTotal': stageTotal,
          'estimatedEndTime': estimatedEndTime,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to update Ongoing Notification: ${e.message}');
      return false;
    }
  }

  /// Update an Ongoing Notification from a SeennJob
  Future<bool> updateNotificationFromJob(SeennJob job) async {
    return updateNotification(
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
    );
  }

  /// End an Ongoing Notification
  Future<bool> endNotification({
    required String jobId,
    required int finalProgress,
    required String finalStatus,
    String? message,
    String? resultUrl,
    String? errorMessage,
    int dismissAfter = 5000,
  }) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'endOngoingNotification',
        {
          'jobId': jobId,
          'finalProgress': finalProgress,
          'finalStatus': finalStatus,
          'message': message,
          'resultUrl': resultUrl,
          'errorMessage': errorMessage,
          'dismissAfter': dismissAfter,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to end Ongoing Notification: ${e.message}');
      return false;
    }
  }

  /// End an Ongoing Notification from a SeennJob
  Future<bool> endNotificationFromJob(SeennJob job) async {
    return endNotification(
      jobId: job.jobId,
      finalProgress: job.progress,
      finalStatus: job.status.name,
      message: job.message,
      resultUrl: job.resultUrl,
      errorMessage: job.errorMessage,
    );
  }

  /// Cancel an Ongoing Notification immediately
  Future<bool> cancelNotification(String jobId) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'cancelOngoingNotification',
        {'jobId': jobId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to cancel Ongoing Notification: ${e.message}');
      return false;
    }
  }

  /// Check if an Ongoing Notification is active for a job
  Future<bool> isNotificationActive(String jobId) async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isNotificationActive',
        {'jobId': jobId},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get all active Ongoing Notification job IDs
  Future<List<String>> getActiveNotificationIds() async {
    if (!Platform.isAndroid) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getActiveNotificationIds',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException {
      return [];
    }
  }

  /// Cancel all Ongoing Notifications
  Future<bool> cancelAllNotifications() async {
    if (!Platform.isAndroid) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'cancelAllNotifications',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to cancel all Ongoing Notifications: ${e.message}');
      return false;
    }
  }
}

/// Result from starting an Ongoing Notification
class OngoingNotificationResult {
  final bool success;
  final int? notificationId;
  final String? jobId;
  final String? error;
  final bool isUnsupported;

  OngoingNotificationResult._({
    required this.success,
    this.notificationId,
    this.jobId,
    this.error,
    this.isUnsupported = false,
  });

  factory OngoingNotificationResult.success({
    required int notificationId,
    required String jobId,
  }) {
    return OngoingNotificationResult._(
      success: true,
      notificationId: notificationId,
      jobId: jobId,
    );
  }

  factory OngoingNotificationResult.error(String error) {
    return OngoingNotificationResult._(
      success: false,
      error: error,
    );
  }

  factory OngoingNotificationResult.unsupported() {
    return OngoingNotificationResult._(
      success: false,
      error: 'Ongoing Notifications are not supported on this platform',
      isUnsupported: true,
    );
  }
}
