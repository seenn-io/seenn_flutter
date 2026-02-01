import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/job.dart';
import '../models/job_error.dart';
import '../models/job_result.dart';
import '../models/job_status.dart';
import '../models/parent_child.dart';
import '../models/queue_info.dart';
import '../models/stage_info.dart';
import '../state/connection_state.dart';
import '../state/state_manager.dart';

/// Polling Service for self-hosted backends
/// Periodically fetches job state via REST API
class PollingService {
  final String apiKey;
  final SeennConfig config;
  final StateManager stateManager;

  SeennConnectionState _connectionState = SeennConnectionState.disconnected;
  Timer? _pollTimer;
  final Set<String> _subscribedJobIds = {};
  http.Client? _httpClient;

  // Streams
  final _connectionStateController =
      StreamController<SeennConnectionState>.broadcast();
  Stream<SeennConnectionState> get connectionState =>
      _connectionStateController.stream;

  PollingService({
    required this.apiKey,
    required String userId, // Reserved for future use
    required this.config,
    required this.stateManager,
  });

  /// Current connection state
  SeennConnectionState get currentState => _connectionState;

  /// Start polling
  Future<void> connect() async {
    if (_connectionState == SeennConnectionState.connected) {
      return;
    }

    _setConnectionState(SeennConnectionState.connecting);
    _httpClient = http.Client();

    // Add initial job IDs from config
    _subscribedJobIds.addAll(config.initialJobIds);

    // Start polling timer
    _startPolling();
    _setConnectionState(SeennConnectionState.connected);
  }

  /// Start the polling timer
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(config.pollInterval, (_) => _pollJobs());

    // Do initial poll immediately
    _pollJobs();
  }

  /// Poll all subscribed jobs
  Future<void> _pollJobs() async {
    if (_subscribedJobIds.isEmpty) return;

    final jobIds = List<String>.from(_subscribedJobIds);

    for (final jobId in jobIds) {
      try {
        await _fetchJob(jobId);
      } catch (e) {
        _log('Error polling job $jobId: $e');
      }
    }
  }

  /// Fetch a single job from the API
  Future<void> _fetchJob(String jobId) async {
    final uri = Uri.parse('${config.baseUrl}${config.basePath}/jobs/$jobId');
    final response = await _httpClient!.get(
      uri,
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final job = _parseJob(json);
      stateManager.updateJob(job);

      // Auto-unsubscribe from terminal jobs
      if (job.isTerminal) {
        _subscribedJobIds.remove(jobId);
        _log('Job $jobId reached terminal state, unsubscribed');
      }
    } else if (response.statusCode == 404) {
      // Job not found, unsubscribe
      _subscribedJobIds.remove(jobId);
      _log('Job $jobId not found, unsubscribed');
    } else {
      _log('Failed to fetch job $jobId: ${response.statusCode}');
    }
  }

  /// Parse job from API response
  SeennJob _parseJob(Map<String, dynamic> json) {
    // Parse parent info
    ParentInfo? parent;
    if (json['parent'] != null) {
      final p = json['parent'] as Map<String, dynamic>;
      parent = ParentInfo(
        parentJobId: p['parentJobId'] as String,
        childIndex: p['childIndex'] as int? ?? 0,
      );
    }

    // Parse children stats
    ChildrenStats? children;
    if (json['children'] != null) {
      final c = json['children'] as Map<String, dynamic>;
      children = ChildrenStats(
        total: c['total'] as int,
        completed: c['completed'] as int? ?? 0,
        failed: c['failed'] as int? ?? 0,
        running: c['running'] as int? ?? 0,
        pending: c['pending'] as int? ?? 0,
      );
    }

    return SeennJob(
      jobId: json['id'] as String,
      userId: json['userId'] as String,
      appId: json['appId'] as String,
      status: JobStatus.fromString(json['status'] as String),
      title: json['title'] as String? ?? '',
      jobType: json['jobType'] as String? ?? 'job',
      progress: json['progress'] as int? ?? 0,
      message: json['message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      queue: json['queue'] != null
          ? QueueInfo.fromJson(json['queue'] as Map<String, dynamic>)
          : null,
      stage: json['stage'] != null
          ? StageInfo.fromJson(json['stage'] as Map<String, dynamic>)
          : null,
      estimatedCompletionAt: json['estimatedCompletionAt'] as String?,
      result: json['result'] != null
          ? JobResult.fromJson(json['result'] as Map<String, dynamic>)
          : null,
      error: json['error'] != null
          ? JobError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : null,
      // ETA fields
      workflowId: json['workflowId'] as String?,
      etaConfidence: (json['etaConfidence'] as num?)?.toDouble(),
      etaBasedOn: json['etaBasedOn'] as int?,
      // Parent-child fields
      parent: parent,
      children: children,
    );
  }

  /// Subscribe to job updates
  void subscribeJob(String jobId) {
    _subscribedJobIds.add(jobId);
    _log('Subscribed to job $jobId');

    // Fetch immediately
    _fetchJob(jobId);
  }

  /// Subscribe to multiple jobs
  void subscribeJobs(List<String> jobIds) {
    _subscribedJobIds.addAll(jobIds);
    _log('Subscribed to ${jobIds.length} jobs');

    // Fetch all immediately
    for (final jobId in jobIds) {
      _fetchJob(jobId);
    }
  }

  /// Unsubscribe from job updates
  void unsubscribeJob(String jobId) {
    _subscribedJobIds.remove(jobId);
    _log('Unsubscribed from job $jobId');
  }

  /// Get subscribed job IDs
  Set<String> get subscribedJobIds => Set.unmodifiable(_subscribedJobIds);

  /// Disconnect
  Future<void> disconnect() async {
    _setConnectionState(SeennConnectionState.disconnected);
    _cleanup();
  }

  void _cleanup() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _httpClient?.close();
    _httpClient = null;
  }

  /// Update user ID (reserved for future use)
  Future<void> updateToken(String userId) async {
    // Reserved for future use - polling doesn't require userId in requests
  }

  void _setConnectionState(SeennConnectionState state) {
    _connectionState = state;
    _connectionStateController.add(state);
  }

  void _log(String message) {
    if (config.debug) {
      print('[Seenn Polling] $message');
    }
  }

  /// Dispose resources
  void dispose() {
    _cleanup();
    _subscribedJobIds.clear();
    _connectionStateController.close();
  }
}
