enum TaskTrackingStatus {
  active('active', '共享中'),
  paused('paused', '已暂停'),
  arrived('arrived', '已到达');

  const TaskTrackingStatus(this.value, this.label);

  final String value;
  final String label;

  static TaskTrackingStatus fromValue(String? value) {
    return TaskTrackingStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskTrackingStatus.active,
    );
  }
}

class TaskLocation {
  const TaskLocation({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.updatedAt,
    required this.createdAt,
    this.accuracyMeters,
    this.headingDegrees,
    this.speedMps,
    this.source = 'manual',
    this.label,
  });

  final String id;
  final String taskId;
  final String userId;
  final double latitude;
  final double longitude;
  final double? accuracyMeters;
  final double? headingDegrees;
  final double? speedMps;
  final TaskTrackingStatus status;
  final String source;
  final String? label;
  final DateTime updatedAt;
  final DateTime createdAt;

  bool get isActive => status == TaskTrackingStatus.active;

  String get coordinateLabel =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  factory TaskLocation.fromMap(Map<String, dynamic> map) {
    return TaskLocation(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      userId: map['user_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracyMeters: (map['accuracy_meters'] as num?)?.toDouble(),
      headingDegrees: (map['heading_degrees'] as num?)?.toDouble(),
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      status: TaskTrackingStatus.fromValue(map['sharing_status'] as String?),
      source: map['source'] as String? ?? 'manual',
      label: map['label'] as String?,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
