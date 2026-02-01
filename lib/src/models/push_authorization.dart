/// iOS push authorization status values
///
/// - [notDetermined]: Permission never requested
/// - [denied]: User denied permission
/// - [authorized]: Full push access granted
/// - [provisional]: Quiet notifications only (iOS 12+)
/// - [ephemeral]: App Clips only (iOS 14+)
enum PushAuthorizationStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
  ephemeral,
}

/// Extension to convert string to enum
extension PushAuthorizationStatusExtension on PushAuthorizationStatus {
  static PushAuthorizationStatus fromString(String value) {
    switch (value) {
      case 'notDetermined':
        return PushAuthorizationStatus.notDetermined;
      case 'denied':
        return PushAuthorizationStatus.denied;
      case 'authorized':
        return PushAuthorizationStatus.authorized;
      case 'provisional':
        return PushAuthorizationStatus.provisional;
      case 'ephemeral':
        return PushAuthorizationStatus.ephemeral;
      default:
        return PushAuthorizationStatus.notDetermined;
    }
  }
}

/// Information about the current push authorization status
class PushAuthorizationInfo {
  /// Current authorization status
  final PushAuthorizationStatus status;

  /// Whether current authorization is provisional (quiet notifications only)
  final bool isProvisional;

  /// Whether user can be prompted to upgrade to full authorization
  ///
  /// This is true when status is [PushAuthorizationStatus.provisional],
  /// meaning you can call [LiveActivity.upgradeToStandardPush] to show
  /// the standard permission prompt.
  final bool canRequestFullAuthorization;

  PushAuthorizationInfo({
    required this.status,
    required this.isProvisional,
    required this.canRequestFullAuthorization,
  });

  factory PushAuthorizationInfo.fromMap(Map<String, dynamic> map) {
    return PushAuthorizationInfo(
      status: PushAuthorizationStatusExtension.fromString(
        map['status'] as String? ?? 'notDetermined',
      ),
      isProvisional: map['isProvisional'] as bool? ?? false,
      canRequestFullAuthorization:
          map['canRequestFullAuthorization'] as bool? ?? false,
    );
  }

  /// Default info for unsupported platforms (Android)
  factory PushAuthorizationInfo.unsupported() {
    return PushAuthorizationInfo(
      status: PushAuthorizationStatus.notDetermined,
      isProvisional: false,
      canRequestFullAuthorization: false,
    );
  }

  @override
  String toString() {
    return 'PushAuthorizationInfo(status: $status, isProvisional: $isProvisional, canRequestFullAuthorization: $canRequestFullAuthorization)';
  }
}
