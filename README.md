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
- **Error Codes** - Standardized error handling with `SeennErrorCode`
- **Input Validation** - Client-side validation before native calls

## Installation

```yaml
dependencies:
  seenn_flutter: ^0.8.4
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

## Error Handling

All Live Activity operations return results with error codes for programmatic handling:

```dart
import 'package:seenn_flutter/seenn_flutter.dart';

print('SDK Version: $sdkVersion'); // '0.8.4'

final result = await LiveActivity.start(
  jobId: 'job_123',
  title: 'Processing...',
  jobType: 'video',
);

if (!result.success) {
  switch (result.code) {
    case SeennErrorCode.platformNotSupported:
      print('Not on iOS');
      break;
    case SeennErrorCode.invalidJobId:
      print('Invalid job ID');
      break;
    case SeennErrorCode.bridgeNotRegistered:
      print('Native setup incomplete');
      break;
    default:
      print('Error [${result.code}]: ${result.error}');
  }
}
```

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

## Rich Push Notifications (iOS)

Display images (avatars, thumbnails) in push notifications. Requires a **Notification Service Extension**.

### Setup

1. **Create extension in Xcode:**
   - Open `ios/Runner.xcworkspace`
   - File → New → Target → **Notification Service Extension**
   - Name: `NotificationServiceExtension`
   - Language: Swift

2. **Replace the generated code** in `NotificationServiceExtension/NotificationService.swift`:

```swift
import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Look for image URL in payload
        let userInfo = request.content.userInfo
        let imageUrlString = userInfo["senderAvatar"] as? String
            ?? userInfo["imageUrl"] as? String
            ?? userInfo["image"] as? String

        guard let urlString = imageUrlString,
              let imageUrl = URL(string: urlString) else {
            contentHandler(bestAttemptContent)
            return
        }

        // Download and attach image
        downloadImage(from: imageUrl) { attachment in
            if let attachment = attachment {
                bestAttemptContent.attachments = [attachment]
            }
            contentHandler(bestAttemptContent)
        }
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

    private func downloadImage(
        from url: URL,
        completion: @escaping (UNNotificationAttachment?) -> Void
    ) {
        let task = URLSession.shared.downloadTask(with: url) { localUrl, response, error in
            guard let localUrl = localUrl, error == nil else {
                completion(nil)
                return
            }

            let fileManager = FileManager.default
            let tempDir = fileManager.temporaryDirectory
            let fileName = url.lastPathComponent
            let destUrl = tempDir.appendingPathComponent(fileName)

            try? fileManager.removeItem(at: destUrl)
            do {
                try fileManager.moveItem(at: localUrl, to: destUrl)
                let attachment = try UNNotificationAttachment(
                    identifier: "image",
                    url: destUrl,
                    options: nil
                )
                completion(attachment)
            } catch {
                completion(nil)
            }
        }
        task.resume()
    }
}
```

3. **Build and run** your app

### Payload Format

Include `mutable-content: 1` and an image URL:

```json
{
  "aps": {
    "alert": { "title": "Message", "body": "Hello!" },
    "mutable-content": 1
  },
  "senderAvatar": "https://example.com/avatar.jpg"
}
```

Supported fields: `senderAvatar`, `imageUrl`, `image`

## Documentation

- [Getting Started](https://docs.seenn.io/client/flutter)
- [API Reference](https://pub.dev/documentation/seenn_flutter/latest/)
- [Examples](https://github.com/seenn-io/seenn_flutter/tree/main/example)

## Requirements

- Flutter >= 3.10.0
- Dart >= 3.0.0
- iOS 16.2+ (for Live Activity with push updates)
- Android API 21+ (for Ongoing Notification)

> **Why iOS 16.2?** While Live Activities were introduced in iOS 16.1, the push token API (`pushType: .token`) and `ActivityContent` struct required for remote backend updates were added in iOS 16.2.

## License

MIT License - see [LICENSE](LICENSE) for details.
