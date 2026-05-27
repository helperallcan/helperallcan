class TaskReview {
  const TaskReview({
    required this.id,
    required this.taskId,
    required this.reviewerId,
    required this.revieweeId,
    required this.rating,
    required this.createdAt,
    this.comment,
    this.reviewerName,
    this.revieweeName,
  });

  final String id;
  final String taskId;
  final String reviewerId;
  final String revieweeId;
  final int rating;
  final String? comment;
  final String? reviewerName;
  final String? revieweeName;
  final DateTime createdAt;

  factory TaskReview.fromMap(Map<String, dynamic> map) {
    return TaskReview(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      reviewerId: map['reviewer_id'] as String,
      revieweeId: map['reviewee_id'] as String,
      rating: (map['rating'] as num?)?.toInt() ?? 5,
      comment: map['comment'] as String?,
      reviewerName: _profileName(map['reviewer']),
      revieweeName: _profileName(map['reviewee']),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static String? _profileName(Object? value) {
    final profile = value is List && value.isNotEmpty ? value.first : value;
    if (profile is Map) {
      return profile['display_name'] as String?;
    }
    return null;
  }
}
