// Seenn Flutter SDK - Error Codes
// MIT License - Open Source

/// Standardized error codes for Seenn SDK operations
///
/// Use these codes to handle errors programmatically:
///
/// ```dart
/// final result = await LiveActivity.start(jobId: '', title: 'Test');
/// if (!result.success && result.code == SeennErrorCode.invalidJobId) {
///   print('Invalid job ID provided');
/// }
/// ```
class SeennErrorCode {
  SeennErrorCode._();

  // Platform errors
  /// Operation not supported on this platform (e.g., LiveActivity on Android)
  static const String platformNotSupported = 'PLATFORM_NOT_SUPPORTED';

  /// Native module not found - native setup incomplete
  static const String nativeModuleNotFound = 'NATIVE_MODULE_NOT_FOUND';

  /// Live Activity bridge not registered in AppDelegate
  static const String bridgeNotRegistered = 'BRIDGE_NOT_REGISTERED';

  // Activity errors
  /// Live Activity not found for the given jobId
  static const String activityNotFound = 'ACTIVITY_NOT_FOUND';

  /// Live Activities disabled by user in Settings
  static const String activitiesDisabled = 'ACTIVITIES_DISABLED';

  // Permission errors
  /// Push notification permission denied
  static const String permissionDenied = 'PERMISSION_DENIED';

  /// Push permission not yet requested
  static const String permissionNotDetermined = 'PERMISSION_NOT_DETERMINED';

  // Validation errors
  /// Generic validation error
  static const String validationError = 'VALIDATION_ERROR';

  /// Invalid or empty jobId
  static const String invalidJobId = 'INVALID_JOB_ID';

  /// Progress value out of range (must be 0-100)
  static const String invalidProgress = 'INVALID_PROGRESS';

  /// Invalid or empty title
  static const String invalidTitle = 'INVALID_TITLE';

  /// Invalid status value
  static const String invalidStatus = 'INVALID_STATUS';

  // Network errors
  /// Network request failed
  static const String networkError = 'NETWORK_ERROR';

  /// Request timed out
  static const String timeout = 'TIMEOUT';

  // Generic errors
  /// Unknown error occurred
  static const String unknownError = 'UNKNOWN_ERROR';
}
