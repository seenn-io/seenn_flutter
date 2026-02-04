import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/job.dart';
import '../models/live_activity_cta.dart';
import '../models/push_authorization.dart';

/// Service for managing iOS Live Activities
class LiveActivityService {
  static const MethodChannel _methodChannel =
      MethodChannel('io.seenn/live_activity');
  static const EventChannel _eventChannel =
      EventChannel('io.seenn/live_activity_events');

  final _pushTokenController =
      StreamController<LiveActivityPushToken>.broadcast();

  StreamSubscription? _eventSubscription;

  SeennConfig? _config;
  String? _apiKey;
  String? _userId;
  String? _deviceId;

  /// Stream of push tokens for Live Activities
  Stream<LiveActivityPushToken> get pushTokens => _pushTokenController.stream;

  /// Configure the Live Activity service
  void configure({
    required SeennConfig config,
    required String apiKey,
    required String userId,
    String? deviceId,
  }) {
    _config = config;
    _apiKey = apiKey;
    _userId = userId;
    _deviceId = deviceId;
  }

  /// Initialize the Live Activity service
  void initialize() {
    if (!Platform.isIOS) return;

    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final type = event['type'] as String?;
          final token = event['token'] as String?;

          if (type == 'pushToken' && token != null) {
            // Live Activity push token
            final jobId = event['jobId'] as String?;
            if (jobId != null) {
              _pushTokenController.add(LiveActivityPushToken.liveActivity(
                jobId: jobId,
                token: token,
              ));
            }
          } else if (type == 'devicePushToken' && token != null) {
            // Device push token
            _pushTokenController.add(LiveActivityPushToken.device(
              token: token,
            ));
          }
        }
      },
      onError: (error) {
        print('[Seenn] Live Activity event error: $error');
      },
    );
  }

  /// Check if Live Activities are supported on this device
  Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;

    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isLiveActivitySupported');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if Live Activities are enabled by the user
  Future<bool> areActivitiesEnabled() async {
    if (!Platform.isIOS) return false;

    try {
      final result =
          await _methodChannel.invokeMethod<bool>('areActivitiesEnabled');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Check if the native Live Activity bridge is registered
  ///
  /// The bridge must be registered in your AppDelegate for Live Activities to work.
  /// See: https://docs.seenn.io/client/flutter#live-activity-setup
  Future<bool> isBridgeRegistered() async {
    if (!Platform.isIOS) return false;

    try {
      final result =
          await _methodChannel.invokeMethod<bool>('isBridgeRegistered');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // MARK: - Push Authorization (iOS 12+)

  /// Get current push notification authorization status
  ///
  /// Returns [PushAuthorizationInfo] with status and capabilities.
  /// On Android, returns [PushAuthorizationInfo.unsupported()].
  Future<PushAuthorizationInfo> getPushAuthorizationStatus() async {
    if (!Platform.isIOS) {
      return PushAuthorizationInfo.unsupported();
    }

    try {
      final result = await _methodChannel
          .invokeMethod<Map<dynamic, dynamic>>('getPushAuthorizationStatus');
      if (result != null) {
        return PushAuthorizationInfo.fromMap(Map<String, dynamic>.from(result));
      }
      return PushAuthorizationInfo.unsupported();
    } catch (e) {
      return PushAuthorizationInfo.unsupported();
    }
  }

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
  Future<bool> requestProvisionalPushAuthorization() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('requestProvisionalPushAuthorization');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Request standard push authorization (shows permission prompt)
  ///
  /// This shows the standard iOS permission prompt asking users
  /// to allow notifications with alerts, sounds, and badges.
  ///
  /// Returns true if full authorization was granted.
  Future<bool> requestStandardPushAuthorization() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('requestStandardPushAuthorization');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Refresh device push token if authorization is already granted
  ///
  /// Call this on app launch to ensure you have the latest device
  /// push token even if permission was granted in a previous session.
  /// The token will be delivered via [pushTokens] stream.
  ///
  /// Returns true if token refresh was triggered, false if not authorized.
  Future<bool> refreshDevicePushToken() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel
          .invokeMethod<bool>('refreshDevicePushToken');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Start a Live Activity for a job
  ///
  /// Returns the activity ID if successful
  Future<LiveActivityResult> startActivity({
    required String jobId,
    required String title,
    required String jobType,
    int initialProgress = 0,
    String? initialMessage,
  }) async {
    if (!Platform.isIOS) {
      return LiveActivityResult.unsupported();
    }

    try {
      final result =
          await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'startLiveActivity',
        {
          'jobId': jobId,
          'title': title,
          'jobType': jobType,
          'initialProgress': initialProgress,
          'initialMessage': initialMessage,
        },
      );

      if (result != null) {
        return LiveActivityResult.success(
          activityId: result['activityId'] as String,
          jobId: result['jobId'] as String,
        );
      }
      return LiveActivityResult.error('Unknown error');
    } on PlatformException catch (e) {
      if (e.code == 'BRIDGE_NOT_REGISTERED') {
        return LiveActivityResult.bridgeNotRegistered();
      }
      return LiveActivityResult.error(e.message ?? 'Failed to start activity');
    }
  }

  /// Start a Live Activity from a SeennJob
  Future<LiveActivityResult> startActivityFromJob(SeennJob job) async {
    return startActivity(
      jobId: job.jobId,
      title: job.title,
      jobType: job.jobType,
      initialProgress: job.progress,
      initialMessage: job.message,
    );
  }

  /// Update a Live Activity
  Future<bool> updateActivity({
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
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'updateLiveActivity',
        {
          'jobId': jobId,
          'progress': progress,
          'status': status,
          'message': message,
          'stageName': stageName,
          'stageIndex': stageIndex,
          'stageTotal': stageTotal,
          'eta': eta,
          'resultUrl': resultUrl,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to update Live Activity: ${e.message}');
      return false;
    }
  }

  /// Update a Live Activity from a SeennJob
  Future<bool> updateActivityFromJob(SeennJob job) async {
    return updateActivity(
      jobId: job.jobId,
      progress: job.progress,
      status: job.status.name,
      message: job.message,
      stageName: job.stage?.name,
      stageIndex: job.stage?.current,
      stageTotal: job.stage?.total,
      eta: job.estimatedCompletionTime != null
          ? (job.estimatedCompletionTime!.millisecondsSinceEpoch / 1000).round()
          : null,
      resultUrl: job.resultUrl,
    );
  }

  /// End a Live Activity
  Future<bool> endActivity({
    required String jobId,
    required int finalProgress,
    required String finalStatus,
    String? message,
    String? resultUrl,
    String? errorMessage,
    double dismissAfter = 300, // 5 minutes
    LiveActivityCTAButton? ctaButton,
  }) async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'endLiveActivity',
        {
          'jobId': jobId,
          'finalProgress': finalProgress,
          'finalStatus': finalStatus,
          'message': message,
          'resultUrl': resultUrl,
          'errorMessage': errorMessage,
          'dismissAfter': dismissAfter,
          if (ctaButton != null) 'ctaButton': ctaButton.toMap(),
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to end Live Activity: ${e.message}');
      return false;
    }
  }

  /// End a Live Activity from a SeennJob
  Future<bool> endActivityFromJob(SeennJob job) async {
    return endActivity(
      jobId: job.jobId,
      finalProgress: job.progress,
      finalStatus: job.status.name,
      message: job.message,
      resultUrl: job.resultUrl,
      errorMessage: job.errorMessage,
    );
  }

  /// Cancel a Live Activity immediately
  Future<bool> cancelActivity(String jobId) async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'cancelLiveActivity',
        {'jobId': jobId},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to cancel Live Activity: ${e.message}');
      return false;
    }
  }

  /// Check if a Live Activity is active for a job
  Future<bool> isActivityActive(String jobId) async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'isActivityActive',
        {'jobId': jobId},
      );
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Get all active Live Activity job IDs
  Future<List<String>> getActiveActivityIds() async {
    if (!Platform.isIOS) return [];

    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'getActiveActivityIds',
      );
      return result?.cast<String>() ?? [];
    } on PlatformException {
      return [];
    }
  }

  /// Cancel all Live Activities
  Future<bool> cancelAllActivities() async {
    if (!Platform.isIOS) return false;

    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'cancelAllActivities',
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Seenn] Failed to cancel all Live Activities: ${e.message}');
      return false;
    }
  }

  /// Register a Live Activity push token with the backend
  ///
  /// This is called automatically when a Live Activity is started
  /// and a push token is received from iOS
  Future<bool> registerPushToken({
    required String jobId,
    required String token,
    required String activityId,
  }) async {
    if (_config == null || _apiKey == null || _userId == null) {
      print('[Seenn] Live Activity service not configured');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse('${_config!.baseUrl}${_config!.basePath}/devices/live-activity'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
          'jobId': jobId,
          'token': token,
          'activityId': activityId,
        }),
      );

      if (response.statusCode == 201) {
        if (_config!.debug) {
          print('[Seenn] Registered Live Activity token for job: $jobId');
        }
        return true;
      } else {
        print('[Seenn] Failed to register Live Activity token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('[Seenn] Error registering Live Activity token: $e');
      return false;
    }
  }

  /// Remove a Live Activity push token from the backend
  Future<bool> removePushToken({required String jobId}) async {
    if (_config == null || _apiKey == null || _userId == null) {
      return false;
    }

    try {
      final response = await http.delete(
        Uri.parse('${_config!.baseUrl}${_config!.basePath}/devices/live-activity'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'userId': _userId,
          'deviceId': _deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}',
          'jobId': jobId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('[Seenn] Error removing Live Activity token: $e');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _eventSubscription?.cancel();
    _pushTokenController.close();
  }
}

/// Result from starting a Live Activity
class LiveActivityResult {
  final bool success;
  final String? activityId;
  final String? jobId;
  final String? error;
  final bool isUnsupported;

  LiveActivityResult._({
    required this.success,
    this.activityId,
    this.jobId,
    this.error,
    this.isUnsupported = false,
  });

  factory LiveActivityResult.success({
    required String activityId,
    required String jobId,
  }) {
    return LiveActivityResult._(
      success: true,
      activityId: activityId,
      jobId: jobId,
    );
  }

  factory LiveActivityResult.error(String error) {
    return LiveActivityResult._(
      success: false,
      error: error,
    );
  }

  factory LiveActivityResult.unsupported() {
    return LiveActivityResult._(
      success: false,
      error: 'Live Activities are not supported on this platform',
      isUnsupported: true,
    );
  }

  factory LiveActivityResult.bridgeNotRegistered() {
    return LiveActivityResult._(
      success: false,
      error: 'Live Activity bridge not registered. '
          'You must call SeennLiveActivityRegistry.shared.register() in your AppDelegate. '
          'See: https://docs.seenn.io/client/flutter#live-activity-setup',
    );
  }
}

/// Type of push token event
enum LiveActivityPushTokenType {
  /// Live Activity push token (for updating a specific Live Activity via APNs)
  liveActivity,
  /// Device push token (for sending regular push notifications)
  device,
}

/// Push token event from iOS
class LiveActivityPushToken {
  /// Type of token
  final LiveActivityPushTokenType type;

  /// Job ID (only present for liveActivity type)
  final String? jobId;

  /// APNs push token
  final String token;

  LiveActivityPushToken({
    required this.type,
    this.jobId,
    required this.token,
  });

  /// Create a Live Activity push token
  factory LiveActivityPushToken.liveActivity({
    required String jobId,
    required String token,
  }) {
    return LiveActivityPushToken(
      type: LiveActivityPushTokenType.liveActivity,
      jobId: jobId,
      token: token,
    );
  }

  /// Create a device push token
  factory LiveActivityPushToken.device({
    required String token,
  }) {
    return LiveActivityPushToken(
      type: LiveActivityPushTokenType.device,
      token: token,
    );
  }

  /// Check if this is a Live Activity token
  bool get isLiveActivity => type == LiveActivityPushTokenType.liveActivity;

  /// Check if this is a device token
  bool get isDevice => type == LiveActivityPushTokenType.device;
}
