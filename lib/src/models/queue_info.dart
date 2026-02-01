/// Queue position information - matches @seenn/types QueueInfo
class QueueInfo {
  /// Position in queue (1-based)
  final int position;

  /// Total items in queue
  final int? total;

  /// Queue name/identifier
  final String? queueName;

  const QueueInfo({
    required this.position,
    this.total,
    this.queueName,
  });

  factory QueueInfo.fromJson(Map<String, dynamic> json) {
    return QueueInfo(
      position: json['position'] as int,
      total: json['total'] as int?,
      queueName: json['queueName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'position': position,
        if (total != null) 'total': total,
        if (queueName != null) 'queueName': queueName,
      };

  /// Check if this is first in queue
  bool get isFirst => position == 1;

  QueueInfo copyWith({
    int? position,
    int? total,
    String? queueName,
  }) {
    return QueueInfo(
      position: position ?? this.position,
      total: total ?? this.total,
      queueName: queueName ?? this.queueName,
    );
  }
}
