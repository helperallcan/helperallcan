enum OfferStatus {
  pending('pending', '待选择'),
  accepted('accepted', '已接受'),
  rejected('rejected', '未选择'),
  withdrawn('withdrawn', '已撤回');

  const OfferStatus(this.value, this.label);

  final String value;
  final String label;

  static OfferStatus fromValue(String? value) {
    return OfferStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => OfferStatus.pending,
    );
  }
}

class TaskOffer {
  const TaskOffer({
    required this.id,
    required this.taskId,
    required this.helperId,
    required this.amount,
    required this.status,
    required this.createdAt,
    this.message,
    this.estimatedMinutes,
    this.helperName,
  });

  final String id;
  final String taskId;
  final String helperId;
  final double amount;
  final OfferStatus status;
  final DateTime createdAt;
  final String? message;
  final int? estimatedMinutes;
  final String? helperName;

  factory TaskOffer.fromMap(Map<String, dynamic> map) {
    final helper = map['helper'];
    return TaskOffer(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      helperId: map['helper_id'] as String,
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: OfferStatus.fromValue(map['status'] as String?),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      message: map['message'] as String?,
      estimatedMinutes: map['estimated_minutes'] as int?,
      helperName: helper is Map ? helper['display_name'] as String? : null,
    );
  }
}
