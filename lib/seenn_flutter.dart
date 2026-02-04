/// Seenn Flutter SDK
/// Real-time job progress tracking with Polling, Live Activity (iOS),
/// and Ongoing Notification (Android) support.
///
/// Types are aligned with @seenn/types for cross-SDK compatibility.
library seenn_flutter;

// Version Info
export 'src/version.dart';

// Error Codes
export 'src/errors/error_codes.dart';

// Config
export 'src/config.dart';

// Main entry point
export 'src/seenn.dart';

// Models - aligned with @seenn/types
export 'src/models/job.dart';
export 'src/models/job_status.dart';
export 'src/models/stage_info.dart';
export 'src/models/queue_info.dart';
export 'src/models/job_result.dart';
export 'src/models/job_error.dart';
export 'src/models/parent_child.dart';
export 'src/models/live_activity_cta.dart';
export 'src/models/push_authorization.dart';

// Services
export 'src/services/jobs_service.dart'
    show JobsService, JobTracker, ProgressUpdate, ChildProgressUpdate;
export 'src/services/live_activity_service.dart'
    show LiveActivityService, LiveActivityResult, LiveActivityPushToken, LiveActivityPushTokenType;
export 'src/services/ongoing_notification_service.dart'
    show OngoingNotificationService, OngoingNotificationResult;
export 'src/services/job_notification_service.dart'
    show JobNotificationService, JobNotificationResult;
export 'src/services/eta_countdown_service.dart'
    show EtaCountdownService, EtaCountdownState, etaCountdownStream;

// Standalone API (no server required)
export 'src/live_activity.dart' show LiveActivity;

// State
export 'src/state/connection_state.dart';

// Errors
export 'src/errors/seenn_exception.dart';
