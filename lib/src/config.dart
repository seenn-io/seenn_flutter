/// Connection mode for real-time updates
enum ConnectionMode {
  /// HTTP Polling - simple, reliable, works everywhere
  polling,
}

/// Seenn SDK configuration
class SeennConfig {
  /// API base URL
  final String baseUrl;

  /// API base path prefix (default: '/v1')
  /// Self-hosted backends can use custom paths (e.g., '/seenn', '/api/jobs')
  final String basePath;

  /// Polling interval for job updates
  final Duration pollInterval;

  /// Job IDs to poll initially
  /// If empty, no polling occurs until jobs are subscribed
  final List<String> initialJobIds;

  /// Request timeout
  final Duration timeout;

  /// Enable debug logging
  final bool debug;

  const SeennConfig({
    this.baseUrl = 'https://api.seenn.io',
    this.basePath = '/v1',
    this.pollInterval = const Duration(seconds: 5),
    this.initialJobIds = const [],
    this.timeout = const Duration(seconds: 30),
    this.debug = false,
  });

  /// Default configuration
  factory SeennConfig.defaults() => const SeennConfig();

  /// Development configuration (localhost)
  factory SeennConfig.development({
    String apiUrl = 'http://localhost:3001',
  }) =>
      SeennConfig(
        baseUrl: apiUrl,
        debug: true,
      );

  /// Self-hosted configuration
  /// Use this for self-hosted backends
  factory SeennConfig.selfHosted({
    required String apiUrl,
    String basePath = '/v1',
    Duration pollInterval = const Duration(seconds: 5),
    bool debug = false,
  }) =>
      SeennConfig(
        baseUrl: apiUrl,
        basePath: basePath,
        pollInterval: pollInterval,
        debug: debug,
      );

  /// Get full API path with basePath prefix
  String apiPath(String path) => '$basePath$path';
}
