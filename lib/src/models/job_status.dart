/// Job status enum - matches @seenn/types JobStatus
enum JobStatus {
  pending,
  queued,
  running,
  completed,
  failed,
  cancelled;

  /// Check if this is a terminal state
  bool get isTerminal =>
      this == completed || this == failed || this == cancelled;

  /// Parse from string
  static JobStatus fromString(String value) {
    return JobStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => JobStatus.pending,
    );
  }
}
