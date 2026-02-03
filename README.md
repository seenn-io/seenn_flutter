# seenn_flutter

Flutter SDK for [Seenn](https://seenn.io) - Real-time job progress tracking with Live Activity (iOS), and Ongoing Notification (Android) support.

[![pub package](https://img.shields.io/pub/v/seenn_flutter.svg)](https://pub.dev/packages/seenn_flutter)
[![pub downloads](https://img.shields.io/pub/dm/seenn_flutter.svg)](https://pub.dev/packages/seenn_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

## Features

- **Real-time Updates** - Polling with automatic reconnection
- **iOS Live Activity** - Lock Screen and Dynamic Island progress
- **Android Ongoing Notification** - Persistent notification with progress bar
- **Provisional Push** - iOS 12+ quiet notifications without permission prompt
- **ETA Countdown** - Smart time estimates with confidence scores
- **Parent-Child Jobs** - Hierarchical job relationships
- **Reactive Streams** - RxDart-powered state management

## Installation

```yaml
dependencies:
  seenn_flutter: ^0.8.0
```

## Quick Start

```dart
import 'package:seenn_flutter/seenn_flutter.dart';

// Initialize
final seenn = Seenn(SeennConfig(
  publicKey: 'pk_live_xxx',
  baseUrl: 'https://api.seenn.io',
));

// Connect for a user
await seenn.connect(userId: 'user_123');

// Subscribe to a job
final tracker = seenn.jobs.subscribe('job_abc');

tracker.onProgress.listen((update) {
  print('Progress: ${update.progress}%');
  print('ETA: ${update.etaFormatted}');
});

tracker.onComplete.listen((job) {
  print('Job completed!');
});
```

## iOS Live Activity

```dart
// Start Live Activity
await seenn.liveActivity.startActivity(
  jobId: 'job_abc',
  title: 'Processing video...',
);

// Auto-sync with job updates
seenn.jobs.stream('job_abc').listen((job) {
  if (job != null) {
    seenn.liveActivity.updateActivity(
      jobId: job.id,
      progress: job.progress,
      message: job.message,
    );
  }
});
```

### iOS Setup

Add to `ios/Runner/Info.plist`:

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

## Provisional Push (iOS 12+)

Request push notifications without showing a permission prompt:

```dart
import 'package:seenn_flutter/seenn_flutter.dart';

// Check current status
final status = await LiveActivity.getPushAuthorizationStatus();
print(status.status);        // PushAuthorizationStatus.provisional
print(status.isProvisional); // true if quiet notifications

// Request provisional push (no prompt!)
final granted = await LiveActivity.requestProvisionalPushAuthorization();
if (granted) {
  print('Provisional push enabled');
}

// Later: upgrade to full push when ready
if (status.canRequestFullAuthorization) {
  await LiveActivity.upgradeToStandardPush(); // Shows prompt
}
```

> **Note:** Provisional notifications appear silently in Notification Center only.
> Users can "Keep" or "Turn Off" from their first notification.

## Android Ongoing Notification

```dart
// Start notification
await seenn.ongoingNotification.startNotification(
  jobId: 'job_abc',
  title: 'Processing',
  message: 'Starting...',
);

// Update progress
await seenn.ongoingNotification.updateNotification(
  jobId: 'job_abc',
  progress: 50,
  message: 'Halfway there...',
);

// End notification
await seenn.ongoingNotification.endNotification(
  jobId: 'job_abc',
  title: 'Complete',
  message: 'Your video is ready!',
);
```

## Cross-Platform Notifications

Use `JobNotificationService` for unified iOS + Android handling:

```dart
// Automatically uses Live Activity on iOS, Ongoing Notification on Android
await seenn.jobNotification.startNotification(
  jobId: 'job_abc',
  title: 'Processing',
  message: 'Starting...',
);

// Sync with job updates
await seenn.jobNotification.syncWithJob(job);
```

## ETA Countdown

```dart
// Get countdown stream
final countdown = etaCountdownStream(
  job: job,
  intervalMs: 1000,
);

countdown.listen((state) {
  print('Remaining: ${state.formatted}'); // "2:34"
  print('Past due: ${state.isPastDue}');
  print('Confidence: ${state.confidence}'); // 0.0 - 1.0
});
```

## Parent-Child Jobs

```dart
// Get parent jobs
final parents = seenn.jobs.parents;

// Get children of a parent
final children = seenn.jobs.childrenOf('parent_job_id');

// Stream child progress
tracker.onChildProgress.listen((update) {
  print('${update.completed}/${update.total} complete');
  print('${update.failed} failed');
});
```

## Job Filtering

```dart
// By status
final active = seenn.jobs.active;
final completed = seenn.jobs.byStatus(JobStatus.completed);

// Reactive streams
seenn.jobs.active$.listen((jobs) {
  print('Active jobs: ${jobs.length}');
});
```

## Connection Management

```dart
// Check connection state
seenn.connection$.listen((state) {
  print('Connected: ${state.isConnected}');
});

// Manual reconnect
await seenn.reconnect();

// Disconnect
await seenn.disconnect();
```

## Documentation

- [Getting Started](https://docs.seenn.io/client/flutter)
- [API Reference](https://pub.dev/documentation/seenn_flutter/latest/)
- [Examples](https://github.com/seenn-io/seenn_flutter/tree/main/example)

## Requirements

- Flutter >= 3.10.0
- Dart >= 3.0.0
- iOS 16.1+ (for Live Activity)
- Android API 21+ (for Ongoing Notification)

## License

MIT License - see [LICENSE](LICENSE) for details.
