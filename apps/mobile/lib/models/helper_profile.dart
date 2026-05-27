import 'offer.dart';
import 'task.dart';

enum HelperVerificationStatus {
  none('none', '未认证'),
  pending('pending', '审核中'),
  approved('approved', '已认证'),
  rejected('rejected', '未通过');

  const HelperVerificationStatus(this.value, this.label);

  final String value;
  final String label;

  bool get canRequest => this == none || this == rejected;

  static HelperVerificationStatus fromValue(String? value) {
    return HelperVerificationStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => HelperVerificationStatus.none,
    );
  }
}

class HelperProfile {
  const HelperProfile({
    required this.id,
    required this.userId,
    required this.skills,
    required this.serviceAreas,
    required this.verificationStatus,
    required this.completedTasks,
    required this.ratingAverage,
    required this.ratingCount,
    required this.isAvailable,
    this.headline,
    this.bio,
    this.hourlyRate,
    this.verificationNote,
  });

  final String id;
  final String userId;
  final String? headline;
  final String? bio;
  final List<String> skills;
  final List<String> serviceAreas;
  final double? hourlyRate;
  final HelperVerificationStatus verificationStatus;
  final String? verificationNote;
  final int completedTasks;
  final double ratingAverage;
  final int ratingCount;
  final bool isAvailable;

  String get ratingLabel {
    if (ratingCount == 0) return '暂无评分';
    return '${ratingAverage.toStringAsFixed(1)} / 5';
  }

  factory HelperProfile.fromMap(Map<String, dynamic> map) {
    return HelperProfile(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      headline: map['headline'] as String?,
      bio: map['bio'] as String?,
      skills: _stringList(map['skills']),
      serviceAreas: _stringList(map['service_areas']),
      hourlyRate: (map['hourly_rate'] as num?)?.toDouble(),
      verificationStatus: HelperVerificationStatus.fromValue(
        map['verification_status'] as String?,
      ),
      verificationNote: map['verification_note'] as String?,
      completedTasks: (map['completed_tasks'] as num?)?.toInt() ?? 0,
      ratingAverage: (map['rating_average'] as num?)?.toDouble() ?? 0,
      ratingCount: (map['rating_count'] as num?)?.toInt() ?? 0,
      isAvailable: map['is_available'] as bool? ?? true,
    );
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }
}

class HelperWorkItem {
  const HelperWorkItem({
    required this.offerId,
    required this.offerStatus,
    required this.amount,
    required this.createdAt,
    required this.task,
  });

  final String offerId;
  final OfferStatus offerStatus;
  final double amount;
  final DateTime createdAt;
  final Task task;

  factory HelperWorkItem.fromMap(Map<String, dynamic> map) {
    final rawTask = map['tasks'] ?? map['task'];
    final taskMap = rawTask is Map
        ? Map<String, dynamic>.from(rawTask)
        : <String, dynamic>{
            'id': map['task_id'],
            'creator_id': '',
            'task_type': 'help',
            'title': '任务',
            'description': '',
            'location_text': '',
            'is_urgent': false,
            'status': 'open',
            'created_at': map['created_at'],
          };

    return HelperWorkItem(
      offerId: map['id'] as String,
      offerStatus: OfferStatus.fromValue(map['status'] as String?),
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      task: Task.fromMap(taskMap),
    );
  }
}
