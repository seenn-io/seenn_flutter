import 'dart:async';
import 'dart:io';
import 'config.dart';
import 'errors/seenn_exception.dart';
import 'models/job.dart';
import 'services/jobs_service.dart';
import 'services/live_activity_service.dart';
import 'services/polling_service.dart';
import 'state/connection_state.dart';
import 'state/state_manager.dart';

/// Main entry point for Seenn Flutter SDK
class Seenn {
  static Seenn? _instance;

  /// Get the singleton instance
  /// Throws [SeennNotInitializedException] if not initialized
  static Seenn get instance =>
      _instance ?? (throw const SeennNotInitializedException());

  /// Check if SDK is initialized
  static bool get isInitialized => _instance != null;

  final SeennConfig _config;
  final StateManager _stateManager;
  final PollingService _pollingService;

  /// Track jobs with active Live Activities
  final Set<String> _activeActivityJobIds = {};

  /// Job update subscription for Live Activity sync
  StreamSubscription<SeennJob>? _jobUpdateSubscription;

  /// Service for job operations
  late final JobsService jobs;

  /// Service for iOS Live Activities
  late final LiveActivityService liveActivity;

  Seenn._(
    this._config,
    this._stateManager,
    this._pollingService,
  ) {
    jobs = JobsService(_stateManager);
    liveActivity = LiveActivityService();
  }

  /// Initialize Seenn SDK
  /// Call once at app startup
  ///
  /// Example:
  /// ```dart
  /// await Seenn.init(
  ///   apiKey: 'pk_live_xxx',  // Public API key
  ///   userId: 'user_123',     // Your user ID
  /// );
  /// ```
  ///
  /// Example (Self-hosted):
  /// ```dart
  /// await Seenn.init(
  ///   apiKey: 'pk_live_xxx',
  ///   userId: 'user_123',
  ///   config: SeennConfig.selfHosted(
  ///     apiUrl: 'https://my-backend.com',
  ///     pollInterval: Duration(seconds: 5),
  ///   ),
  /// );
  /// ```
  static Future<void> init({
    required String apiKey,
    required String userId,
    SeennConfig? config,
  }) async {
    if (_instance != null) {
      throw const SeennAlreadyInitializedException();
    }

    // Validate API key format (skip for self-hosted backends)
    final isSelfHosted = config != null &&
        config.baseUrl != 'https://api.seenn.io';

    if (!isSelfHosted && !apiKey.startsWith('pk_') && !apiKey.startsWith('sk_')) {
      throw const SeennException(
        'Invalid API key format. Key must start with pk_ or sk_',
      );
    }

    final effectiveConfig = config ?? SeennConfig.defaults();
    final stateManager = StateManager();

    final pollingService = PollingService(
      apiKey: apiKey,
      userId: userId,
      config: effectiveConfig,
      stateManager: stateManager,
    );

    _instance = Seenn._(effectiveConfig, stateManager, pollingService);

    // Configure and initialize Live Activity service (iOS only)
    _instance!.liveActivity.configure(
      config: effectiveConfig,
      apiKey: apiKey,
      userId: userId,
    );
    _instance!.liveActivity.initialize();

    // Setup Live Activity sync with job updates (iOS only)
    _instance!._setupLiveActivitySync();

    // Start polling
    await _instance!._pollingService.connect();
  }

  /// Setup automatic Live Activity sync with job updates
  void _setupLiveActivitySync() {
    if (!Platform.isIOS) return;

    _jobUpdateSubscription = _stateManager.jobUpdates$.listen(_onJobUpdate);
  }

  /// Handle job update for Live Activity sync
  void _onJobUpdate(SeennJob job) {
    // Only update Live Activity for jobs that have one active
    if (!_activeActivityJobIds.contains(job.jobId)) return;

    if (job.isTerminal) {
      // Job completed or failed - end the Live Activity
      liveActivity.endActivityFromJob(job);
      _activeActivityJobIds.remove(job.jobId);
    } else {
      // Job still running - update the Live Activity
      liveActivity.updateActivityFromJob(job);
    }
  }

  /// Start Live Activity for a job and track it for auto-updates
  Future<LiveActivityResult> startLiveActivityForJob(SeennJob job) async {
    final result = await liveActivity.startActivityFromJob(job);
    if (result.success) {
      _activeActivityJobIds.add(job.jobId);
    }
    return result;
  }

  /// Start Live Activity by job ID (fetches job from state)
  Future<LiveActivityResult> startLiveActivityById(String jobId) async {
    final job = _stateManager.getJob(jobId);
    if (job == null) {
      return LiveActivityResult.error('Job not found');
    }
    return startLiveActivityForJob(job);
  }

  /// Stop tracking a job for Live Activity auto-updates
  void stopLiveActivityTracking(String jobId) {
    _activeActivityJobIds.remove(jobId);
  }

  /// Get current connection state
  SeennConnectionState get connectionState => _pollingService.currentState;

  /// Stream of connection state changes
  Stream<SeennConnectionState> get connectionState$ => _pollingService.connectionState;

  /// Check if connected
  bool get isConnected => connectionState.isConnected;

  /// Subscribe to job updates
  void subscribeJob(String jobId) {
    _pollingService.subscribeJob(jobId);
  }

  /// Subscribe to multiple jobs
  void subscribeJobs(List<String> jobIds) {
    _pollingService.subscribeJobs(jobIds);
  }

  /// Unsubscribe from job updates
  void unsubscribeJob(String jobId) {
    _pollingService.unsubscribeJob(jobId);
  }

  /// Get subscribed job IDs
  Set<String> get subscribedJobIds => _pollingService.subscribedJobIds;

  /// Manually trigger reconnection
  Future<void> reconnect() async {
    await _pollingService.disconnect();
    await _pollingService.connect();
  }

  /// Update user token (e.g., after token refresh)
  static Future<void> setUserToken(String token) async {
    await instance._pollingService.updateToken(token);
  }

  /// Disconnect and cleanup
  static Future<void> dispose() async {
    if (_instance == null) return;

    await _instance!._jobUpdateSubscription?.cancel();

    await _instance!._pollingService.disconnect();
    _instance!._pollingService.dispose();

    _instance!._stateManager.dispose();
    _instance!.liveActivity.dispose();
    _instance!._activeActivityJobIds.clear();
    _instance = null;
  }

  /// Get SDK version
  static String get version => '0.8.1';

  /// Get current config
  SeennConfig get config => _config;
}
