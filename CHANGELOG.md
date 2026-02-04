# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.8.4] - 2026-02-04

### Added
- **SDK Version Info** - Programmatic access to SDK version
  - `sdkVersion` - Current SDK version string ('0.8.4')
  - `sdkName` - Package name ('seenn_flutter')
  - `sdkUserAgent` - For API request headers

- **Error Codes** - Standardized error codes for all operations
  - `SeennErrorCode` class with all error code constants
  - All `LiveActivityResult` now includes `code` field for programmatic error handling
  - Codes: `platformNotSupported`, `invalidJobId`, `invalidProgress`, `activityNotFound`, etc.

- **Input Validation** - Client-side validation before native calls
  - Validates jobId (required, max 128 chars), title, progress (0-100), status
  - Returns specific error codes for invalid inputs

- **Debug Logging** - Warning logs in debug mode when calling iOS-only APIs on Android

### Changed
- `LiveActivity.update()` now returns `LiveActivityResult` instead of `bool` for consistency
- `LiveActivity.end()` now returns `LiveActivityResult` instead of `bool` for consistency
- `LiveActivity.cancel()` now returns `LiveActivityResult` instead of `bool` for consistency
- `LiveActivity.cancelAll()` now returns `LiveActivityResult` instead of `bool` for consistency
- `LiveActivityResult` now has `toString()` for easier debugging

### Example
```dart
import 'package:seenn_flutter/seenn_flutter.dart';

print('SDK Version: $sdkVersion'); // '0.8.4'

final result = await LiveActivity.start(
  jobId: '',  // Invalid!
  title: 'Test',
  jobType: 'test',
);

if (!result.success) {
  if (result.code == SeennErrorCode.invalidJobId) {
    print('Invalid job ID!');
  }
}
```

## [0.8.3] - 2026-02-04

### Added
- **Auto Push Token Registration** - SDK now automatically captures device push tokens on app restart
  - `refreshDevicePushToken()` - Refresh token if authorization already granted (call on app launch)
  - Auto-swizzle on SDK init - No longer requires permission request to setup token capture

### Why This Matters
Previously, if a user granted push permission and then restarted the app, the device token would not be captured because swizzling only happened during permission request. Now the SDK swizzles immediately on init, ensuring tokens are always captured.

## [0.8.2] - 2026-02-03

### Fixed
- Fixed outdated version in README installation example (0.2.0 → 0.8.0)

## [0.8.1] - 2026-01-30

### Changed
- Cleaned up SSE references from documentation and comments
- Polling is now the only supported connection mode

## [0.8.0] - 2026-01-30

### Added
- **Device Push Token** support for provisional push
  - `onPushToken` now emits device tokens with `type: .device`
  - Automatic `registerForRemoteNotifications()` after provisional auth
  - Method swizzling for AppDelegate token capture
  - Compatible with OneSignal/Firebase (chains to original implementation)

## [0.7.0] - 2026-01-29

### Added
- **Provisional Push Authorization** (iOS 12+) - Request push notifications without permission prompt
  - `LiveActivity.getPushAuthorizationStatus()` - Get current authorization status
  - `LiveActivity.requestProvisionalPushAuthorization()` - Request quiet notifications
  - `LiveActivity.requestStandardPushAuthorization()` - Request full notifications (shows prompt)
  - `LiveActivity.upgradeToStandardPush()` - Upgrade from provisional to full access
  - New `PushAuthorizationStatus` enum and `PushAuthorizationInfo` model

## [0.6.0] - 2026-01-29

### Added
- **Standalone Mode** - Use Live Activity without Seenn server connection
  - New `LiveActivity` static class for direct native bridge access
  - No `Seenn.init()` required for standalone usage
  - Perfect for BYO Backend scenarios with own job state and APNs push
- Static convenience methods:
  - `LiveActivity.start()`, `update()`, `end()`
  - `LiveActivity.isSupported()`, `areActivitiesEnabled()`
  - `LiveActivity.isActive()`, `getActiveIds()`
  - `LiveActivity.cancel()`, `cancelAll()`
  - `LiveActivity.onPushToken` stream
  - `LiveActivity.initialize()`, `dispose()`

### Documentation
- Added "Standalone Mode (BYO Backend)" section to docs
- Clarified difference between Self-Hosted and Standalone modes

## [0.5.0] - 2026-01-29

### Added
- **Live Activity CTA Button** - Tappable button on completion
  - `ctaButton` parameter in `endActivity()`
  - `LiveActivityCTAButton` model with text, deepLink, style options

## [0.4.1] - 2026-01-28

### Fixed
- **Critical**: Push token race condition - tokens arriving before Dart listener was ready were silently dropped
- Added token buffering: tokens received before `EventChannel.listen()` are now queued and emitted when listener connects

## [0.4.0] - 2026-01-28

### Changed
- **BREAKING**: Live Activity now requires bridge registration
- Removed internal `SeennJobAttributes` to fix "ActivityInput error 0" iOS module isolation bug
- Added `SeennLiveActivityBridge` protocol for app-level implementation
- Added `SeennLiveActivityRegistry` for bridge registration

### Added
- `isBridgeRegistered()` method in `LiveActivityService`
- `LiveActivityResult.bridgeNotRegistered()` error type
- Bridge implementation template in example app

### Migration
Users must now:
1. Copy `SeennLiveActivityBridgeImpl.swift` to their app
2. Copy `SeennJobAttributes.swift` to both app and Widget Extension targets
3. Register bridge in AppDelegate: `SeennLiveActivityRegistry.shared.register(SeennLiveActivityBridgeImpl.shared)`
4. See docs: https://docs.seenn.io/client/flutter#live-activity-setup

## [0.3.0] - 2026-01-24

### Added
- **Polling Mode** - Alternative to SSE for self-hosted backends
  - `ConnectionMode` enum: `.sse` (default) or `.polling`
  - `PollingService` for REST-based job polling
  - `SeennConfig.selfHosted()` factory for easy setup
  - `subscribeJob()`, `subscribeJobs()`, `unsubscribeJob()` methods
  - Configurable `pollInterval` (default: 5 seconds)
  - Auto-unsubscribe from terminal jobs

### Changed
- `SeennConfig` now includes `mode`, `pollInterval`, `initialJobIds`
- SDK version bumped to 0.3.0

## [0.2.0] - 2026-01-24

### Added
- **Android Ongoing Notification** - Persistent notification with progress bar
  - `OngoingNotificationService` for direct Android control
  - `JobNotificationService` for unified cross-platform API
- **ETA Countdown** - Real-time countdown with server sync
  - `EtaCountdownService` with formatted output
  - `etaCountdownStream()` convenience function
- **Parent-Child Jobs** - Hierarchical job relationships
  - `ParentInfo`, `ChildrenStats`, `ChildJobSummary` models
  - `childrenOf()`, `parents`, `children` in JobsService
- **New Job Fields** - Full @seenn/types alignment
  - `jobType`, `workflowId`, `estimatedCompletionAt`
  - `etaConfidence`, `etaBasedOn`, `childProgressMode`
  - `parent`, `children`, `startedAt`
- **JobTracker Enhancements**
  - `onCancelled` stream
  - `onChildProgress` stream for parent jobs

### Changed
- `StageInfo` fields: `name`, `current`, `total`, `description`
- `QueueInfo` added `queueName` field
- `JobStatus` added `cancelled` status

### Deprecated
- `StageInfo.id` → use `name`
- `StageInfo.label` → use `name`
- `StageInfo.index` → use `current`

## [0.1.0] - 2026-01-22

### Added
- Initial release
- SSE connection with auto-reconnect
- iOS Live Activity support
- Job state management with RxDart
- `JobsService` with reactive streams
- `LiveActivityService` for iOS
