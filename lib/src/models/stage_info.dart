/// Stage information for multi-step jobs - matches @seenn/types StageInfo
class StageInfo {
  /// Current stage name
  final String name;

  /// Current stage index (1-based)
  final int current;

  /// Total number of stages
  final int total;

  /// Optional stage description
  final String? description;

  const StageInfo({
    required this.name,
    required this.current,
    required this.total,
    this.description,
  });

  factory StageInfo.fromJson(Map<String, dynamic> json) {
    return StageInfo(
      name: json['name'] as String,
      current: json['current'] as int,
      total: json['total'] as int,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'current': current,
        'total': total,
        if (description != null) 'description': description,
      };

  /// Progress through stages as a percentage (0-100)
  double get stageProgress => total > 0 ? (current / total) * 100 : 0;

  /// Legacy getters for backwards compatibility
  String get id => name;
  String get label => name;
  int get index => current;

  StageInfo copyWith({
    String? name,
    int? current,
    int? total,
    String? description,
  }) {
    return StageInfo(
      name: name ?? this.name,
      current: current ?? this.current,
      total: total ?? this.total,
      description: description ?? this.description,
    );
  }
}
