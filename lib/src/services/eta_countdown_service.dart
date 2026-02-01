import 'dart:async';
import '../models/job.dart';

/// ETA countdown state
class EtaCountdownState {
  /// Remaining time in milliseconds
  final int remaining;

  /// Formatted remaining time (e.g., "2m 30s")
  final String formatted;

  /// Whether the job is past its estimated completion time
  final bool isPastDue;

  /// ETA confidence (0.0 - 1.0)
  final double? confidence;

  /// Number of historical jobs used to calculate ETA
  final int? basedOn;

  /// Whether ETA is available
  final bool hasEta;

  const EtaCountdownState({
    required this.remaining,
    required this.formatted,
    required this.isPastDue,
    this.confidence,
    this.basedOn,
    required this.hasEta,
  });

  factory EtaCountdownState.empty() {
    return const EtaCountdownState(
      remaining: 0,
      formatted: '--:--',
      isPastDue: false,
      hasEta: false,
    );
  }

  factory EtaCountdownState.fromJob(SeennJob job) {
    final etaTime = job.estimatedCompletionTime;
    if (etaTime == null) {
      return EtaCountdownState.empty();
    }

    final now = DateTime.now();
    final diff = etaTime.difference(now).inMilliseconds;
    final remaining = diff > 0 ? diff : 0;
    final isPastDue = diff < 0;

    return EtaCountdownState(
      remaining: remaining,
      formatted: _formatRemaining(remaining),
      isPastDue: isPastDue,
      confidence: job.etaConfidence,
      basedOn: job.etaBasedOn,
      hasEta: true,
    );
  }

  static String _formatRemaining(int remainingMs) {
    if (remainingMs <= 0) return 'any moment';

    final seconds = (remainingMs / 1000).round();
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;

    if (minutes > 0) {
      return '${minutes}m ${secs}s';
    }
    return '${secs}s';
  }
}

/// Service for ETA countdown with periodic updates
class EtaCountdownService {
  Timer? _timer;
  final StreamController<EtaCountdownState> _controller =
      StreamController<EtaCountdownState>.broadcast();

  SeennJob? _currentJob;
  DateTime? _serverEta;

  /// Stream of ETA countdown states
  Stream<EtaCountdownState> get stream => _controller.stream;

  /// Start countdown for a job
  void startCountdown(SeennJob job, {Duration interval = const Duration(seconds: 1)}) {
    _currentJob = job;
    _serverEta = job.estimatedCompletionTime;

    // Stop existing timer
    _timer?.cancel();

    // Emit initial state
    _emitState();

    // Start periodic updates
    _timer = Timer.periodic(interval, (_) {
      _emitState();
    });
  }

  /// Update the job (call when job state changes from server)
  void updateJob(SeennJob job) {
    _currentJob = job;

    // Sync with server ETA if it changed
    final newEta = job.estimatedCompletionTime;
    if (newEta != null && newEta != _serverEta) {
      _serverEta = newEta;
    }

    _emitState();
  }

  /// Stop the countdown
  void stopCountdown() {
    _timer?.cancel();
    _timer = null;
    _currentJob = null;
    _serverEta = null;
  }

  void _emitState() {
    if (_currentJob == null) {
      _controller.add(EtaCountdownState.empty());
      return;
    }

    // Use server ETA for calculations
    final job = _serverEta != null
        ? _currentJob!.copyWith(
            estimatedCompletionAt: _serverEta!.toIso8601String())
        : _currentJob!;

    _controller.add(EtaCountdownState.fromJob(job));
  }

  /// Dispose resources
  void dispose() {
    _timer?.cancel();
    _controller.close();
  }
}

/// Create a countdown stream for a job
///
/// This is a convenience function that creates a new stream
/// which emits EtaCountdownState every second.
Stream<EtaCountdownState> etaCountdownStream(
  SeennJob job, {
  Duration interval = const Duration(seconds: 1),
}) async* {
  final etaTime = job.estimatedCompletionTime;
  if (etaTime == null) {
    yield EtaCountdownState.empty();
    return;
  }

  while (true) {
    final now = DateTime.now();
    final diff = etaTime.difference(now).inMilliseconds;
    final remaining = diff > 0 ? diff : 0;
    final isPastDue = diff < 0;

    yield EtaCountdownState(
      remaining: remaining,
      formatted: EtaCountdownState._formatRemaining(remaining),
      isPastDue: isPastDue,
      confidence: job.etaConfidence,
      basedOn: job.etaBasedOn,
      hasEta: true,
    );

    // If past due, stop emitting
    if (isPastDue) break;

    await Future.delayed(interval);
  }
}
