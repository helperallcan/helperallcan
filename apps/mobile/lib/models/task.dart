enum TaskKind {
  help('help', '我要找帮手'),
  answer('answer', '我要找答案'),
  findItem('find_item', '我要找东西'),
  resource('resource', '找资源');

  const TaskKind(this.value, this.label);

  final String value;
  final String label;
}

TaskKind taskKindFromValue(String? value) {
  return TaskKind.values.firstWhere(
    (kind) => kind.value == value,
    orElse: () => TaskKind.help,
  );
}

enum TaskStatus {
  draft('draft', '草稿'),
  open('open', '待报价'),
  offered('offered', '已有报价'),
  assigned('assigned', '已选择帮手'),
  inProgress('in_progress', '进行中'),
  completed('completed', '已完成'),
  cancelled('cancelled', '已取消'),
  rejected('rejected', '审核拒绝'),
  hidden('hidden', '已隐藏');

  const TaskStatus(this.value, this.label);

  final String value;
  final String label;

  static TaskStatus fromValue(String? value) {
    return TaskStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TaskStatus.open,
    );
  }
}

class TaskImage {
  const TaskImage({
    required this.id,
    required this.storagePath,
    this.publicUrl,
  });

  final String id;
  final String storagePath;
  final String? publicUrl;

  factory TaskImage.fromMap(Map<String, dynamic> map) {
    return TaskImage(
      id: map['id'] as String,
      storagePath: map['storage_path'] as String? ?? '',
      publicUrl: map['public_url'] as String?,
    );
  }
}

class Task {
  const Task({
    required this.id,
    required this.creatorId,
    required this.taskType,
    required this.title,
    required this.description,
    required this.locationText,
    required this.isUrgent,
    required this.status,
    required this.createdAt,
    this.assignedHelperId,
    this.completionNote,
    this.completionProofUrl,
    this.completedAt,
    this.categoryId,
    this.subcategoryId,
    this.categoryName,
    this.subcategoryName,
    this.city,
    this.district,
    this.budgetMin,
    this.budgetMax,
    this.images = const [],
  });

  final String id;
  final String creatorId;
  final String? assignedHelperId;
  final String? categoryId;
  final String? subcategoryId;
  final String? categoryName;
  final String? subcategoryName;
  final TaskKind taskType;
  final String title;
  final String description;
  final String locationText;
  final String? city;
  final String? district;
  final double? budgetMin;
  final double? budgetMax;
  final bool isUrgent;
  final TaskStatus status;
  final String? completionNote;
  final String? completionProofUrl;
  final DateTime? completedAt;
  final DateTime createdAt;
  final List<TaskImage> images;

  String get budgetLabel {
    if (budgetMin == null && budgetMax == null) {
      return '面议';
    }
    if (budgetMin != null && budgetMax == null) {
      return 'RM ${budgetMin!.toStringAsFixed(0)} 起';
    }
    if (budgetMin == null && budgetMax != null) {
      return '最高 RM ${budgetMax!.toStringAsFixed(0)}';
    }
    return 'RM ${budgetMin!.toStringAsFixed(0)} - ${budgetMax!.toStringAsFixed(0)}';
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    final images = (map['task_images'] as List<dynamic>? ?? [])
        .map(
            (item) => TaskImage.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();

    final category = map['categories'];
    final subcategory = map['subcategories'];

    return Task(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      assignedHelperId: map['assigned_helper_id'] as String?,
      categoryId: map['category_id'] as String?,
      subcategoryId: map['subcategory_id'] as String?,
      categoryName: category is Map ? category['name'] as String? : null,
      subcategoryName:
          subcategory is Map ? subcategory['name'] as String? : null,
      taskType: taskKindFromValue(map['task_type'] as String?),
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      locationText: map['location_text'] as String? ?? '',
      city: map['city'] as String?,
      district: map['district'] as String?,
      budgetMin: (map['budget_min'] as num?)?.toDouble(),
      budgetMax: (map['budget_max'] as num?)?.toDouble(),
      isUrgent: map['is_urgent'] as bool? ?? false,
      status: TaskStatus.fromValue(map['status'] as String?),
      completionNote: map['completion_note'] as String?,
      completionProofUrl: map['completion_proof_url'] as String?,
      completedAt: DateTime.tryParse(map['completed_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
      images: images,
    );
  }
}
