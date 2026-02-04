import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'errors/error_codes.dart';
import 'services/live_activity_service.dart';
import 'models/live_activity_cta.dart';
import 'models/push_authorization.dart';

/// Standalone Live Activity API for iOS
///
/// Use this class when you want to control Live Activities without
/// configuring Seenn or connecting to any server. Perfect for:
/// - BYO Backend: You manage job state in your own database
/// - APNs Direct: You send Live Activity push updates from your backend
/// - No Server: Testing or prototyping without backend infrastructure
///
/// ## Example
///
/// ```dart
/// import 'package:seenn_flutter/seenn_flutter.dart';
///
/// // No Seenn.configure() needed!
///
/// // Start a Live Activity
/// final result = await LiveActivity.start(
///   jobId: 'job_123',
///   title: 'Processing your video...',
///   jobType: 'video-processing',
///   initialProgress: 0,
/// );
///
/// if (result.success) {
///   print('Activity started: ${result.activityId}');
/// } else {
///   print('Error [${result.code}]: ${result.error}');
/// }
///
/// // Update from your own state management
/// await LiveActivity.update(
///   jobId: 'job_123',
///   progress: 50,
///   status: 'running',
///   message: 'Encoding frames...',
/// );
///
/// // End with CTA button
/// await LiveActivity.end(
///   jobId: 'job_123',
///   finalProgress: 100,
///   finalStatus: 'completed',
///   message: 'Video ready!',
///   ctaButton: LiveActivityCTAButton(
///     text: 'Watch Now',
///     deepLink: 'myapp://videos/job_123',
///   ),
/// );
/// ```
///
/// ## Push Token Handling
///
/// When using standalone mode with your own backend, you need to:
/// 1. Listen to push tokens via [onPushToken]
/// 2. Send tokens to your backend for APNs updates
///
/// ```dart
/// // Listen for push tokens (both Live Activity and device tokens)
/// final subscription = LiveActivity.onPushToken.listen((token) {
///   if (token.isLiveActivity) {
///     // Live Activity token - for updating a specific Live Activity
///     myApi.registerLiveActivityToken(
///       jobId: token.jobId!,
///       token: token.token,
///     );
///   } else if (token.isDevice) {
///     // Device token - for regular push notifications
///     myApi.registerDevicePushToken(token: token.token);
///   }
/// });
///
/// // Don't forget to cancel when done
/// subscription.cancel();
/// ```
class LiveActivity {
  static final LiveActivityService _service = LiveActivityService();
  static bool _initialized = false;

  // Validation helpers
  static String? _validateJobId(String? jobId) {
    if (jobId == null || jobId.trim().isEmpty) {
      return 'jobId is required and cannot be empty';
    }
    if (jobId.length > 128) {
      return 'jobId must be 128 characters or less';
    }
    return null;
  }

  static String? _validateTitle(String? title) {
    if (title == null || title.trim().isEmpty) {
      return 'title is required and cannot be empty';
    }
    return null;
  }

  static String? _validateProgress(int? progress) {
    if (progress == null) return null;
    if (progress < 0 || progress > 100) {
      return 'progress must be between 0 and 100';
    }
    return null;
  }

  static String? _validateStatus(String? status, List<String> allowed) {
    if (status == null || status.trim().isEmpty) {
      return 'status is required';
    }
    if (!allowed.contains(status)) {
      return 'status must be one of: ${allowed.join(", ")}';
    }
    return null;
  }

  static void _logWarning(String message) {
    if (kDebugMode) {
      print('[Seenn] $message');
    }
  }

  /// Initialize the Live Activity event listener
  ///
  /// Call this once at app startup if you want to receive push token events.
  /// This is optional - you only need it if your backend handles APNs push.
  static void initialize() {
    if (_initialized) return;
    _service.initialize();
    _initialized = true;
  }

  /// Stream of push tokens (both Live Activity and device tokens)
  ///
  /// Subscribe to this stream to receive:
  /// - Live Activity push tokens (for updating specific Live Activities)
  /// - Device push tokens (for regular push notifications)
  ///
  /// Use [LiveActivityPushToken.isLiveActivity] or [LiveActivityPushToken.isDevice]
  /// to determine the token type.
  static Stream<LiveActivityPushToken> get onPushToken => _service.pushTokens;

  /// Check if Live Activities are supported on this device
  ///
  /// Returns false on Android and iOS versions before 16.2
  static Future<bool> isSupported() => _service.isSupported();

  /// Check if Live Activities are enabled by the user
  ///
  /// User can disable Live Activities in iOS Settings
  static Future<bool> areActivitiesEnabled() => _service.areActivitiesEnabled();

  /// Check if the native Live Activity bridge is registered
  ///
  /// The bridge must be registered in AppDelegate for Live Activities to work.
  /// See: https://docs.seenn.io/client/flutter#live-activity-setup
  static Future<bool> isBridgeRegistered() => _service.isBridgeRegistered();

  /// Start a new Live Activity
  ///
  /// Returns [LiveActivityResult] with success status, activity ID, and error code.
  ///
  /// - [jobId]: Unique identifier for this job/activity (required, max 128 chars)
  /// - [title]: Title shown in the Live Activity (required)
  /// - [jobType]: Type identifier (e.g., 'video-processing', 'image-generation')
  /// - [initialProgress]: Starting progress (0-100)
  /// - [initialMessage]: Optional initial status message
  ///
  /// ## Example
  ///
  /// ```dart
  /// final result = await LiveActivity.start(
  ///   jobId: 'job_123',
  ///   title: 'Processing...',
  ///   jobType: 'video',
  /// );
  ///
  /// if (!result.success) {
  ///   if (result.code == SeennErrorCode.invalidJobId) {
  ///     print('Invalid job ID');
  ///   } else if (result.code == SeennErrorCode.platformNotSupported) {
  ///     print('Not on iOS');
  ///   }
  /// }
  /// ```
  static Future<LiveActivityResult> start({
    required String jobId,
    required String title,
    required String jobType,
    int initialProgress = 0,
    String? initialMessage,
  }) async {
    // Platform check
    if (!Platform.isIOS) {
      _logWarning('LiveActivity.start() is only supported on iOS. Call ignored.');
      return LiveActivityResult.unsupported();
    }

    // Validate jobId
    final jobIdError = _validateJobId(jobId);
    if (jobIdError != null) {
      return LiveActivityResult.validationError(
        jobIdError,
        SeennErrorCode.invalidJobId,
      );
    }

    // Validate title
    final titleError = _validateTitle(title);
    if (titleError != null) {
      return LiveActivityResult.validationError(
        titleError,
        SeennErrorCode.invalidTitle,
      );
    }

    // Validate progress
    final progressError = _validateProgress(initialProgress);
    if (progressError != null) {
      return LiveActivityResult.validationError(
        progressError,
        SeennErrorCode.invalidProgress,
      );
    }

    return _service.startActivity(
      jobId: jobId,
      title: title,
      jobType: jobType,
      initialProgress: initialProgress,
      initialMessage: initialMessage,
    );
  }

  /// Update an existing Live Activity
  ///
  /// Returns [LiveActivityResult] with success status and error code.
  ///
  /// - [jobId]: Job ID to update (required)
  /// - [progress]: Current progress (0-100, required)
  /// - [status]: Current status ('pending', 'running', 'completed', 'failed')
  /// - [message]: Optional status message
  /// - [stageName]: Optional current stage name
  /// - [stageIndex]: Optional current stage index (1-based)
  /// - [stageTotal]: Optional total number of stages
  /// - [eta]: Optional estimated completion time (Unix timestamp in seconds)
  /// - [resultUrl]: Optional result URL (for completed jobs)
  static Future<LiveActivityResult> update({
    required String jobId,
    required int progress,
    required String status,
    String? message,
    String? stageName,
    int? stageIndex,
    int? stageTotal,
    int? eta,
    String? resultUrl,
  }) async {
    // Platform check
    if (!Platform.isIOS) {
      _logWarning('LiveActivity.update() is only supported on iOS. Call ignored.');
      return LiveActivityResult.unsupported();
    }

    // Validate jobId
    final jobIdError = _validateJobId(jobId);
    if (jobIdError != null) {
      return LiveActivityResult.validationError(
        jobIdError,
        SeennErrorCode.invalidJobId,
      );
    }

    // Validate progress
    final progressError = _validateProgress(progress);
    if (progressError != null) {
      return LiveActivityResult.validationError(
        progressError,
        SeennErrorCode.invalidProgress,
      );
    }

    // Validate status
    final statusError = _validateStatus(
      status,
      ['pending', 'running', 'completed', 'failed'],
    );
    if (statusError != null) {
      return LiveActivityResult.validationError(
        statusError,
        SeennErrorCode.invalidStatus,
      );
    }

    final success = await _service.updateActivity(
      jobId: jobId,
      progress: progress,
      status: status,
      message: message,
      stageName: stageName,
      stageIndex: stageIndex,
      stageTotal: stageTotal,
      eta: eta,
      resultUrl: resultUrl,
    );

    if (success) {
      return LiveActivityResult(success: true, jobId: jobId);
    }
    return LiveActivityResult.error(
      'Activity not found or update failed',
      code: SeennErrorCode.activityNotFound,
    );
  }

  /// End a Live Activity
  ///
  /// Returns [LiveActivityResult] with success status and error code.
  ///
  /// - [jobId]: Job ID to end (required)
  /// - [finalProgress]: Final progress value (default: 100 for completed)
  /// - [finalStatus]: Final status ('completed', 'failed', 'cancelled')
  /// - [message]: Optional final message
  /// - [resultUrl]: Optional result URL (for completed jobs)
  /// - [errorMessage]: Optional error message (for failed jobs)
  /// - [dismissAfter]: Seconds to keep on screen after ending (default: 300 = 5 min)
  /// - [ctaButton]: Optional CTA button to show on completion
  static Future<LiveActivityResult> end({
    required String jobId,
    required int finalProgress,
    required String finalStatus,
    String? message,
    String? resultUrl,
    String? errorMessage,
    double dismissAfter = 300,
    LiveActivityCTAButton? ctaButton,
  }) async {
    // Platform check
    if (!Platform.isIOS) {
      _logWarning('LiveActivity.end() is only supported on iOS. Call ignored.');
      return LiveActivityResult.unsupported();
    }

    // Validate jobId
    final jobIdError = _validateJobId(jobId);
    if (jobIdError != null) {
      return LiveActivityResult.validationError(
        jobIdError,
        SeennErrorCode.invalidJobId,
      );
    }

    // Validate finalProgress
    final progressError = _validateProgress(finalProgress);
    if (progressError != null) {
      return LiveActivityResult.validationError(
        progressError,
        SeennErrorCode.invalidProgress,
      );
    }

    // Validate finalStatus
    final statusError = _validateStatus(
      finalStatus,
      ['completed', 'failed', 'cancelled'],
    );
    if (statusError != null) {
      return LiveActivityResult.validationError(
        statusError,
        SeennErrorCode.invalidStatus,
      );
    }

    final success = await _service.endActivity(
      jobId: jobId,
      finalProgress: finalProgress,
      finalStatus: finalStatus,
      message: message,
      resultUrl: resultUrl,
      errorMessage: errorMessage,
      dismissAfter: dismissAfter,
      ctaButton: ctaButton,
    );

    if (success) {
      return LiveActivityResult(success: true, jobId: jobId);
    }
    return LiveActivityResult.error(
      'Activity not found or end failed',
      code: SeennErrorCode.activityNotFound,
    );
  }

  /// Check if a Live Activity is currently active for a job
  static Future<bool> isActive(String jobId) async {
    if (!Platform.isIOS) return false;

    final jobIdError = _validateJobId(jobId);
    if (jobIdError != null) {
      _logWarning('isActive: $jobIdError');
      return false;
    }

    return _service.isActivityActive(jobId);
  }

  /// Get all active Live Activity job IDs
  static Future<List<String>> getActiveIds() => _service.getActiveActivityIds();

  /// Cancel a specific Live Activity immediately
  ///
  /// Unlike [end], this removes the activity without any dismissal animation.
  static Future<LiveActivityResult> cancel(String jobId) async {
    if (!Platform.isIOS) {
      _logWarning('LiveActivity.cancel() is only supported on iOS. Call ignored.');
      return LiveActivityResult.unsupported();
    }

    final jobIdError = _validateJobId(jobId);
    if (jobIdError != null) {
      return LiveActivityResult.validationError(
        jobIdError,
        SeennErrorCode.invalidJobId,
      );
    }

    final success = await _service.cancelActivity(jobId);
    if (success) {
      return LiveActivityResult(success: true, jobId: jobId);
    }
    return LiveActivityResult.error(
      'Activity not found',
      code: SeennErrorCode.activityNotFound,
    );
  }

  /// Cancel all Live Activities immediately
  static Future<LiveActivityResult> cancelAll() async {
    if (!Platform.isIOS) {
      _logWarning('LiveActivity.cancelAll() is only supported on iOS. Call ignored.');
      return LiveActivityResult.unsupported();
    }

    final success = await _service.cancelAllActivities();
    return LiveActivityResult(success: success);
  }

  // MARK: - Push Authorization (iOS 12+)

  /// Get current push notification authorization status
  ///
  /// Returns [PushAuthorizationInfo] with status and capabilities.
  /// On Android, returns [PushAuthorizationInfo.unsupported()].
  ///
  /// ## Example
  ///
  /// ```dart
  /// final info = await LiveActivity.getPushAuthorizationStatus();
  /// print(info.status); // PushAuthorizationStatus.provisional
  /// print(info.isProvisional); // true
  /// print(info.canRequestFullAuthorization); // true
  /// ```
  static Future<PushAuthorizationInfo> getPushAuthorizationStatus() =>
      _service.getPushAuthorizationStatus();

  /// Request provisional push authorization (iOS 12+)
  ///
  /// Provisional push allows sending "quiet" notifications without
  /// showing a permission prompt. Notifications appear only in
  /// Notification Center without sounds or banners.
  ///
  /// When users see their first notification, they can choose
  /// "Keep" or "Turn Off" to finalize their preference.
  ///
  /// Returns true if provisional authorization was granted.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Request provisional push - no prompt shown!
  /// final granted = await LiveActivity.requestProvisionalPushAuthorization();
  /// if (granted) {
  ///   print('Provisional push enabled');
  /// }
  /// ```
  static Future<bool> requestProvisionalPushAuthorization() {
    if (!Platform.isIOS) {
      _logWarning('requestProvisionalPushAuthorization() is only supported on iOS. Call ignored.');
      return Future.value(false);
    }
    return _service.requestProvisionalPushAuthorization();
  }

  /// Request standard push authorization (shows permission prompt)
  ///
  /// This shows the standard iOS permission prompt asking users
  /// to allow notifications with alerts, sounds, and badges.
  ///
  /// Returns true if full authorization was granted.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final granted = await LiveActivity.requestStandardPushAuthorization();
  /// if (granted) {
  ///   print('Full push access granted');
  /// }
  /// ```
  static Future<bool> requestStandardPushAuthorization() {
    if (!Platform.isIOS) {
      _logWarning('requestStandardPushAuthorization() is only supported on iOS. Call ignored.');
      return Future.value(false);
    }
    return _service.requestStandardPushAuthorization();
  }

  /// Upgrade from provisional to standard push authorization
  ///
  /// If the user currently has provisional authorization, this
  /// shows the standard permission prompt to upgrade to full access.
  ///
  /// Returns true if upgrade was successful.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final info = await LiveActivity.getPushAuthorizationStatus();
  /// if (info.canRequestFullAuthorization) {
  ///   final upgraded = await LiveActivity.upgradeToStandardPush();
  ///   if (upgraded) {
  ///     print('Upgraded to full push access');
  ///   }
  /// }
  /// ```
  static Future<bool> upgradeToStandardPush() {
    if (!Platform.isIOS) {
      _logWarning('upgradeToStandardPush() is only supported on iOS. Call ignored.');
      return Future.value(false);
    }
    return _service.requestStandardPushAuthorization();
  }

  /// Refresh device push token if authorization is already granted
  ///
  /// Call this on app launch to ensure you have the latest device
  /// push token even if permission was granted in a previous session.
  /// The token will be delivered via [onPushToken] stream.
  ///
  /// Returns true if token refresh was triggered, false if not authorized.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // On app launch
  /// final refreshed = await LiveActivity.refreshDevicePushToken();
  /// if (refreshed) {
  ///   print('Token refresh triggered');
  /// }
  /// ```
  static Future<bool> refreshDevicePushToken() {
    if (!Platform.isIOS) return Future.value(false);
    return _service.refreshDevicePushToken();
  }

  /// Dispose resources
  ///
  /// Call this when you're done using Live Activities to clean up.
  static void dispose() {
    _service.dispose();
    _initialized = false;
  }
}
