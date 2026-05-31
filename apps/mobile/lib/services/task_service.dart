import '../core/supabase_client.dart';
import '../models/app_category.dart';
import '../models/offer.dart';
import '../models/review.dart';
import '../models/task.dart';
import '../models/task_create_input.dart';

class TaskDetailData {
  const TaskDetailData({
    required this.task,
    required this.offers,
    required this.reviews,
    this.creatorName,
  });

  final Task task;
  final List<TaskOffer> offers;
  final List<TaskReview> reviews;
  final String? creatorName;
}

class TaskService {
  Future<List<AppCategory>> fetchCategories({TaskKind? taskKind}) async {
    dynamic query = supabase.from('categories').select().eq('is_active', true);

    if (taskKind != null) {
      query = query.eq('task_type', taskKind.value);
    }

    final rows = await query.order('sort_order');
    return (rows as List<dynamic>)
        .map(
            (row) => AppCategory.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Future<List<Task>> fetchTasks({
    TaskKind? taskKind,
    String? categoryId,
    String? city,
    bool urgentOnly = false,
  }) async {
    dynamic query = supabase
        .from('tasks')
        .select(
            '*, categories:category_id(name), subcategories:subcategory_id(name), task_images(*)')
        .inFilter('status', ['open', 'offered', 'assigned', 'in_progress']);

    if (taskKind != null) {
      query = query.eq('task_type', taskKind.value);
    }
    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }
    if (city != null && city.trim().isNotEmpty) {
      query = query.ilike('city', city.trim());
    }
    if (urgentOnly) {
      query = query.eq('is_urgent', true);
    }

    final rows = await query
        .order('is_urgent', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List<dynamic>)
        .map((row) => Task.fromMap(Map<String, dynamic>.from(row as Map)))
        .toList();
  }

  Stream<List<Task>> watchOpenTasks() {
    return supabase
        .from('tasks')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (rows) => rows
              .where((row) => ['open', 'offered', 'assigned', 'in_progress']
                  .contains(row['status']))
              .map((row) => Task.fromMap(Map<String, dynamic>.from(row)))
              .toList(),
        );
  }

  Future<TaskDetailData> fetchTaskDetail(String taskId) async {
    final row = await supabase
        .from('tasks')
        .select(
          '*, creator:creator_id(display_name), categories:category_id(name), subcategories:subcategory_id(name), task_images(*), task_offers(*, helper:helper_id(display_name, avatar_url)), reviews(*, reviewer:reviewer_id(display_name), reviewee:reviewee_id(display_name))',
        )
        .eq('id', taskId)
        .single();

    final map = Map<String, dynamic>.from(row);
    final offers = (map['task_offers'] as List<dynamic>? ?? [])
        .map(
            (item) => TaskOffer.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final reviews = (map['reviews'] as List<dynamic>? ?? [])
        .map((item) =>
            TaskReview.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
    final creator = map['creator'];

    return TaskDetailData(
      task: Task.fromMap(map),
      offers: offers,
      reviews: reviews,
      creatorName: creator is Map ? creator['display_name'] as String? : null,
    );
  }

  Future<String> createTask(TaskCreateInput input) async {
    final user = supabase.auth.currentUser!;
    final row = await supabase
        .from('tasks')
        .insert(input.toInsertMap(creatorId: user.id))
        .select('id')
        .single();

    return row['id'] as String;
  }

  Future<void> addTaskImage({
    required String taskId,
    required String storagePath,
    required String? publicUrl,
    int sortOrder = 0,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('task_images').insert({
      'task_id': taskId,
      'uploader_id': user.id,
      'storage_path': storagePath,
      'public_url': publicUrl,
      'sort_order': sortOrder,
    });
  }

  Future<void> createOffer({
    required String taskId,
    required double amount,
    required String message,
    int? estimatedMinutes,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('task_offers').insert({
      'task_id': taskId,
      'helper_id': user.id,
      'amount': amount,
      'message': message.trim(),
      'estimated_minutes': estimatedMinutes,
    });
  }

  Future<String> acceptOffer(String offerId) async {
    final conversationId = await supabase
        .rpc('accept_task_offer', params: {'p_offer_id': offerId});
    return conversationId as String;
  }

  Future<void> submitCompletionProof({
    required String taskId,
    String? note,
    String? proofUrl,
  }) async {
    await supabase.rpc('submit_completion_proof', params: {
      'p_task_id': taskId,
      'p_completion_note': note,
      'p_completion_proof_url': proofUrl,
    });
  }

  Future<void> confirmCompleted(String taskId) async {
    await supabase.rpc('confirm_task_completed', params: {'p_task_id': taskId});
  }

  Future<TaskStatus> cancelTask({
    required String taskId,
    String? reason,
  }) async {
    final result = await supabase.rpc('cancel_task', params: {
      'p_task_id': taskId,
      'p_reason': normalizeOptionalText(reason),
    });
    return TaskStatus.fromValue(result as String?);
  }

  Future<TaskStatus> reopenTaskForOffers({
    required String taskId,
    String? reason,
  }) async {
    final result = await supabase.rpc('reopen_task_for_offers', params: {
      'p_task_id': taskId,
      'p_reason': normalizeOptionalText(reason),
    });
    return TaskStatus.fromValue(result as String?);
  }

  Future<OfferStatus> withdrawOffer(String offerId) async {
    final result = await supabase
        .rpc('withdraw_task_offer', params: {'p_offer_id': offerId});
    return OfferStatus.fromValue(result as String?);
  }

  Future<void> createReview({
    required String taskId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('reviews').insert({
      'task_id': taskId,
      'reviewer_id': user.id,
      'reviewee_id': revieweeId,
      'rating': rating,
      'comment': normalizeOptionalText(comment),
    });
  }

  Future<void> reportTask({
    required String taskId,
    required String reason,
    String? details,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('reports').insert({
      'reporter_id': user.id,
      'target_type': 'task',
      'target_id': taskId,
      'reason': reason.trim(),
      'details': normalizeOptionalText(details),
    });
  }

  Future<void> reportUser({
    required String userId,
    required String reason,
    String? details,
  }) async {
    final user = supabase.auth.currentUser!;
    await supabase.from('reports').insert({
      'reporter_id': user.id,
      'target_type': 'user',
      'target_id': userId,
      'reason': reason.trim(),
      'details': normalizeOptionalText(details),
    });
  }

  static String? normalizeOptionalText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
