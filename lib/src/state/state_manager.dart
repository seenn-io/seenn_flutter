import 'dart:async';
import 'package:rxdart/rxdart.dart';
import '../models/job.dart';
import '../models/queue_info.dart';

/// Central state manager for Seenn SDK
class StateManager {
  /// Job state - BehaviorSubject keeps last value
  final _jobsSubject = BehaviorSubject<Map<String, SeennJob>>.seeded({});

  /// Individual job updates stream (for Live Activity sync)
  final _jobUpdateController = StreamController<SeennJob>.broadcast();

  /// Get stream for all jobs
  Stream<Map<String, SeennJob>> get jobs$ => _jobsSubject.stream;

  /// Get stream of individual job updates
  Stream<SeennJob> get jobUpdates$ => _jobUpdateController.stream;

  /// Get current jobs map (sync)
  Map<String, SeennJob> get jobs => _jobsSubject.value;

  /// Get stream for specific job
  Stream<SeennJob?> jobStream(String jobId) {
    return _jobsSubject.stream.map((jobs) => jobs[jobId]).distinct();
  }

  /// Get current job (sync)
  SeennJob? getJob(String jobId) => _jobsSubject.value[jobId];

  /// Update job state
  void updateJob(SeennJob job) {
    final current = Map<String, SeennJob>.from(_jobsSubject.value);
    current[job.jobId] = job;
    _jobsSubject.add(current);
    _jobUpdateController.add(job);
  }

  /// Update job queue info
  void updateJobQueue(String jobId, QueueInfo queue) {
    final job = getJob(jobId);
    if (job != null) {
      updateJob(job.copyWith(queue: queue));
    }
  }

  /// Remove job from state
  void removeJob(String jobId) {
    final current = Map<String, SeennJob>.from(_jobsSubject.value);
    current.remove(jobId);
    _jobsSubject.add(current);
  }

  /// Clear all jobs
  void clear() {
    _jobsSubject.add({});
  }

  /// Dispose resources
  void dispose() {
    _jobsSubject.close();
    _jobUpdateController.close();
  }
}
