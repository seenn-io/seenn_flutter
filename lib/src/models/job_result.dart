/// Job result on successful completion - matches @seenn/types JobResult
class JobResult {
  /// Result type (e.g., 'video', 'image', 'file')
  final String? type;

  /// Result URL if applicable
  final String? url;

  /// Additional result data
  final Map<String, dynamic>? data;

  const JobResult({
    this.type,
    this.url,
    this.data,
  });

  factory JobResult.fromJson(Map<String, dynamic> json) {
    return JobResult(
      type: json['type'] as String?,
      url: json['url'] as String?,
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
      };

  JobResult copyWith({
    String? type,
    String? url,
    Map<String, dynamic>? data,
  }) {
    return JobResult(
      type: type ?? this.type,
      url: url ?? this.url,
      data: data ?? this.data,
    );
  }
}
