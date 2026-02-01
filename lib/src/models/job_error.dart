/// Error details on job failure - matches @seenn/types JobError
class JobError {
  /// Error code for programmatic handling
  final String code;

  /// Human-readable error message
  final String message;

  /// Additional error details
  final Map<String, dynamic>? details;

  const JobError({
    required this.code,
    required this.message,
    this.details,
  });

  factory JobError.fromJson(Map<String, dynamic> json) {
    return JobError(
      code: json['code'] as String? ?? 'UNKNOWN',
      message: json['message'] as String? ?? 'Unknown error',
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      };

  JobError copyWith({
    String? code,
    String? message,
    Map<String, dynamic>? details,
  }) {
    return JobError(
      code: code ?? this.code,
      message: message ?? this.message,
      details: details ?? this.details,
    );
  }
}
