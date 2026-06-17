import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/supabase_client.dart';
import '../../core/validators.dart';
import '../../models/offer.dart';
import '../../models/review.dart';
import '../../models/task.dart';
import '../../services/chat_service.dart';
import '../../services/task_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primary_button.dart';

class TaskDetailPage extends StatefulWidget {
  const TaskDetailPage({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  final _taskService = TaskService();
  final _chatService = ChatService();
  final _uploadService = UploadService();
  final _imagePicker = ImagePicker();
  late Future<TaskDetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _taskService.fetchTaskDetail(widget.taskId);
  }

  void _reload() {
    setState(() => _future = _taskService.fetchTaskDetail(widget.taskId));
  }

  Future<void> _openChat() async {
    final conversationId =
        await _chatService.findConversationForTask(widget.taskId);
    if (!mounted) return;
    if (conversationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('选择帮手后才能开始聊天')),
      );
      return;
    }
    context.go('/chat/$conversationId');
  }

  Future<void> _confirmCompleted() async {
    await _taskService.confirmCompleted(widget.taskId);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('任务已确认完成')),
    );
  }

  Future<void> _cancelTask(Task task) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => const _TaskActionDialog(
        title: '取消任务',
        message: '取消后任务会关闭，帮手不能继续报价或聊天。',
        actionLabel: '确认取消',
        reasonLabel: '取消原因（可选）',
      ),
    );
    if (reason == null) return;

    await _taskService.cancelTask(taskId: task.id, reason: reason);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('任务已取消')),
    );
  }

  Future<void> _reopenTask(Task task) async {
    final reason = await showDialog<String?>(
      context: context,
      builder: (context) => const _TaskActionDialog(
        title: '重新开放任务',
        message: '当前选择的帮手会被移除，任务会重新回到可报价状态。',
        actionLabel: '重新开放',
        reasonLabel: '给帮手的说明（可选）',
      ),
    );
    if (reason == null) return;

    await _taskService.reopenTaskForOffers(taskId: task.id, reason: reason);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('任务已重新开放')),
    );
  }

  Future<void> _withdrawOffer(TaskOffer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回报价'),
        content: const Text('撤回后这次报价会失效，不能重复提交同一个任务的报价。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('再想想'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认撤回'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _taskService.withdrawOffer(offer.id);
    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('报价已撤回')),
    );
  }

  Future<void> _submitCompletionProof(Task task) async {
    final result = await showDialog<_CompletionProofResult>(
      context: context,
      builder: (context) => _CompletionProofDialog(imagePicker: _imagePicker),
    );
    if (result == null) return;

    String? proofPath;
    if (result.file != null) {
      final uploaded = await _uploadService.uploadCompletionProof(
        taskId: task.id,
        file: result.file!,
      );
      proofPath = uploaded.path;
    }

    await _taskService.submitCompletionProof(
      taskId: task.id,
      note: result.note,
      proofUrl: proofPath,
    );

    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('完成证明已提交')),
    );
  }

  Future<_ReportResult?> _showReportDialog(String title) {
    return showDialog<_ReportResult>(
      context: context,
      builder: (context) => _ReportDialog(title: title),
    );
  }

  Future<void> _reportTask() async {
    final result = await _showReportDialog('举报任务');
    if (result == null) return;
    await _taskService.reportTask(
      taskId: widget.taskId,
      reason: result.reason,
      details: result.details,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('举报已提交')),
    );
  }

  Future<void> _reportUser(String userId) async {
    final result = await _showReportDialog('举报用户');
    if (result == null) return;
    await _taskService.reportUser(
      userId: userId,
      reason: result.reason,
      details: result.details,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('举报已提交')),
    );
  }

  Future<void> _review(Task task, String revieweeId) async {
    final result = await showDialog<_ReviewResult>(
      context: context,
      builder: (context) => const _ReviewDialog(),
    );
    if (result == null) return;

    await _taskService.createReview(
      taskId: task.id,
      revieweeId: revieweeId,
      rating: result.rating,
      comment: result.comment,
    );

    if (!mounted) return;
    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('评价已提交')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '任务详情',
      actions: [
        IconButton(
          tooltip: '举报',
          onPressed: _reportTask,
          icon: const Icon(Icons.flag_outlined),
        ),
      ],
      child: FutureBuilder<TaskDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final data = snapshot.data!;
          final task = data.task;
          final userId = supabase.auth.currentUser?.id;
          final isOwner = task.creatorId == userId;
          final isAssignedHelper = task.assignedHelperId == userId;
          final canTrackTask = task.status == TaskStatus.assigned ||
              task.status == TaskStatus.inProgress;
          final hasCompletionProof =
              task.completionNote != null || task.completionProofUrl != null;
          final myOffer = _offerForUser(data.offers, userId);
          final oppositeUserId = isOwner
              ? task.assignedHelperId
              : isAssignedHelper
                  ? task.creatorId
                  : null;
          final hasReviewed = userId != null &&
              oppositeUserId != null &&
              data.reviews.any(
                (review) =>
                    review.reviewerId == userId &&
                    review.revieweeId == oppositeUserId,
              );
          final canReview = task.status == TaskStatus.completed &&
              oppositeUserId != null &&
              (isOwner || isAssignedHelper);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  if (task.isUrgent)
                    const Chip(
                      avatar: Icon(Icons.flash_on_outlined, size: 18),
                      label: Text('加急'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                  '发布者：${data.creatorName ?? '用户'} · ${formatDate(task.createdAt)}'),
              const SizedBox(height: 16),
              _InfoCard(task: task),
              const SizedBox(height: 16),
              _TaskFlowCard(
                task: task,
                offerCount: data.offers
                    .where((offer) => offer.status == OfferStatus.pending)
                    .length,
                hasCompletionProof: hasCompletionProof,
                hasReviewed: hasReviewed,
                isOwner: isOwner,
                isAssignedHelper: isAssignedHelper,
              ),
              const SizedBox(height: 16),
              if (task.images.isNotEmpty) _ImageStrip(task: task),
              const SizedBox(height: 16),
              Text(
                task.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (task.completionNote != null ||
                  task.completionProofUrl != null) ...[
                const SizedBox(height: 16),
                _CompletionStatusCard(
                  task: task,
                  uploadService: _uploadService,
                  canConfirm: isOwner && task.status.canConfirmCompletion,
                  onConfirm: _confirmCompleted,
                ),
              ],
              if (data.reviews.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ReviewListCard(reviews: data.reviews),
              ],
              const SizedBox(height: 20),
              if (isOwner) ...[
                _OwnerActions(
                  task: task,
                  offers: data.offers,
                  onAccept: (offer) async {
                    final conversationId =
                        await _taskService.acceptOffer(offer.id);
                    if (!context.mounted) return;
                    context.go('/chat/$conversationId');
                  },
                  onChat: _openChat,
                  onComplete: _confirmCompleted,
                  onCancel: () => _cancelTask(task),
                  onReopen: () => _reopenTask(task),
                  onTracking: canTrackTask
                      ? () => context.go('/tasks/${task.id}/tracking')
                      : null,
                ),
              ] else if (isAssignedHelper) ...[
                PrimaryButton(
                  label: '进入聊天',
                  icon: Icons.chat_bubble_outline,
                  onPressed: _openChat,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: canTrackTask
                      ? () => context.go('/tasks/${task.id}/tracking')
                      : null,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('地图追踪'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: !task.status.canConfirmCompletion
                      ? null
                      : () => _submitCompletionProof(task),
                  icon: const Icon(Icons.task_alt_outlined),
                  label: Text(hasCompletionProof ? '更新完成证明' : '上传完成证明'),
                ),
              ] else ...[
                if (myOffer != null)
                  _MyOfferPanel(
                    offer: myOffer,
                    onWithdraw: myOffer.status.canWithdraw
                        ? () => _withdrawOffer(myOffer)
                        : null,
                  )
                else if (task.status.canReceiveOffers)
                  _OfferPanel(
                    onSubmit: (amount, message, minutes) async {
                      await _taskService.createOffer(
                        taskId: task.id,
                        amount: amount,
                        message: message,
                        estimatedMinutes: minutes,
                      );
                      _reload();
                    },
                  )
                else
                  _TaskClosedNotice(status: task.status),
              ],
              if ((isOwner || isAssignedHelper) && oppositeUserId != null) ...[
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _reportUser(oppositeUserId),
                  icon: const Icon(Icons.report_gmailerrorred_outlined),
                  label: const Text('举报对方'),
                ),
              ],
              if (canReview) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed:
                      hasReviewed ? null : () => _review(task, oppositeUserId),
                  icon: Icon(
                    hasReviewed ? Icons.star : Icons.star_outline,
                  ),
                  label: Text(hasReviewed ? '已评价对方' : '评价对方'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

TaskOffer? _offerForUser(List<TaskOffer> offers, String? userId) {
  if (userId == null) return null;
  for (final offer in offers) {
    if (offer.helperId == userId) return offer;
  }
  return null;
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _Info(
                icon: Icons.category_outlined,
                label: task.categoryName ?? task.taskType.label),
            _Info(icon: Icons.place_outlined, label: task.locationText),
            _Info(icon: Icons.payments_outlined, label: task.budgetLabel),
            _Info(icon: Icons.info_outline, label: task.status.label),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: task.images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final image = task.images[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.publicUrl == null
                ? Container(
                    width: 108,
                    color: Colors.white,
                    child: const Icon(Icons.image_outlined),
                  )
                : Image.network(
                    image.publicUrl!,
                    width: 108,
                    height: 108,
                    fit: BoxFit.cover,
                  ),
          );
        },
      ),
    );
  }
}

class _TaskFlowCard extends StatelessWidget {
  const _TaskFlowCard({
    required this.task,
    required this.offerCount,
    required this.hasCompletionProof,
    required this.hasReviewed,
    required this.isOwner,
    required this.isAssignedHelper,
  });

  final Task task;
  final int offerCount;
  final bool hasCompletionProof;
  final bool hasReviewed;
  final bool isOwner;
  final bool isAssignedHelper;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = [
      _FlowStep(
        label: '发布',
        icon: Icons.add_task_outlined,
        isDone: task.status.lifecycleStep >= 1,
      ),
      _FlowStep(
        label: '报价',
        icon: Icons.local_offer_outlined,
        isDone: task.status.lifecycleStep >= 2 || offerCount > 0,
        count: offerCount,
      ),
      _FlowStep(
        label: '接单',
        icon: Icons.handshake_outlined,
        isDone: task.assignedHelperId != null || task.status.lifecycleStep >= 3,
      ),
      _FlowStep(
        label: '证明',
        icon: Icons.task_alt_outlined,
        isDone: hasCompletionProof || task.status == TaskStatus.completed,
      ),
      _FlowStep(
        label: '完成',
        icon: Icons.verified_outlined,
        isDone: task.status == TaskStatus.completed,
      ),
      _FlowStep(
        label: '评价',
        icon: Icons.star_outline,
        isDone: hasReviewed,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_outlined, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '任务流程',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                  label: Text(task.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _nextActionLabel,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 560;
                return Wrap(
                  spacing: compact ? 8 : 12,
                  runSpacing: 10,
                  children: steps
                      .map(
                        (step) => SizedBox(
                          width: compact
                              ? (constraints.maxWidth - 8) / 2
                              : (constraints.maxWidth - 24) / 3,
                          child: _FlowStepTile(step: step),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _nextActionLabel {
    if (task.status.isClosed && task.status != TaskStatus.completed) {
      return task.status.lifecycleHint;
    }
    if (task.status.isWaitingForHelper) {
      if (isOwner) {
        return offerCount > 0 ? '下一步：选择合适的帮手。' : '下一步：等待帮手报价。';
      }
      return '下一步：帮手可以提交报价或接单说明。';
    }
    if (task.status.isActiveWork) {
      if (isOwner) {
        return hasCompletionProof ? '下一步：查看完成证明并确认完成。' : '下一步：等待帮手提交完成证明。';
      }
      if (isAssignedHelper) {
        return hasCompletionProof ? '下一步：等待发布者确认完成。' : '下一步：完成任务后上传证明。';
      }
      return task.status.lifecycleHint;
    }
    if (task.status == TaskStatus.completed) {
      return hasReviewed ? '你已经完成评价。' : '下一步：给对方一个评价。';
    }
    return task.status.lifecycleHint;
  }
}

class _FlowStep {
  const _FlowStep({
    required this.label,
    required this.icon,
    required this.isDone,
    this.count,
  });

  final String label;
  final IconData icon;
  final bool isDone;
  final int? count;
}

class _FlowStepTile extends StatelessWidget {
  const _FlowStepTile({required this.step});

  final _FlowStep step;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        step.isDone ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: step.isDone
            ? colorScheme.primary.withAlpha(20)
            : colorScheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(step.isDone ? Icons.check_circle : step.icon,
              size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              step.count != null && step.count! > 0
                  ? '${step.label} ${step.count}'
                  : step.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionStatusCard extends StatelessWidget {
  const _CompletionStatusCard({
    required this.task,
    required this.uploadService,
    required this.canConfirm,
    required this.onConfirm,
  });

  final Task task;
  final UploadService uploadService;
  final bool canConfirm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final proofPath = task.completionProofUrl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '完成证明',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            if (task.completionNote != null &&
                task.completionNote!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(task.completionNote!),
            ],
            if (proofPath != null && proofPath.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (UploadService.isImageProofPath(proofPath))
                _SignedProofPreview(
                  proofPath: proofPath,
                  uploadService: uploadService,
                )
              else
                _SignedProofFileButton(
                  proofPath: proofPath,
                  uploadService: uploadService,
                ),
            ],
            if (canConfirm) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.verified_outlined),
                label: const Text('确认任务完成'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignedProofPreview extends StatelessWidget {
  const _SignedProofPreview({
    required this.proofPath,
    required this.uploadService,
  });

  final String proofPath;
  final UploadService uploadService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: uploadService.createCompletionProofSignedUrl(proofPath),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final url = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _launchProofUrl(context, url),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('打开证明图片'),
            ),
          ],
        );
      },
    );
  }
}

class _SignedProofFileButton extends StatelessWidget {
  const _SignedProofFileButton({
    required this.proofPath,
    required this.uploadService,
  });

  final String proofPath;
  final UploadService uploadService;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: uploadService.createCompletionProofSignedUrl(proofPath),
      builder: (context, snapshot) {
        final url = snapshot.data;
        return OutlinedButton.icon(
          onPressed: url == null ? null : () => _launchProofUrl(context, url),
          icon: const Icon(Icons.attach_file_outlined),
          label: Text(url == null ? '正在准备证明文件' : '打开证明文件'),
        );
      },
    );
  }
}

Future<void> _launchProofUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('暂时无法打开证明文件')),
    );
  }
}

class _ReviewListCard extends StatelessWidget {
  const _ReviewListCard({required this.reviews});

  final List<TaskReview> reviews;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.reviews_outlined,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '双方评价',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...reviews.map(
              (review) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${review.reviewerName ?? '用户'} 给 ${review.revieweeName ?? '对方'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        _Stars(rating: review.rating),
                      ],
                    ),
                    if (review.comment != null &&
                        review.comment!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(review.comment!),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      formatDate(review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber.shade700,
        ),
      ),
    );
  }
}

class _OwnerActions extends StatelessWidget {
  const _OwnerActions({
    required this.task,
    required this.offers,
    required this.onAccept,
    required this.onChat,
    required this.onComplete,
    required this.onCancel,
    required this.onReopen,
    required this.onTracking,
  });

  final Task task;
  final List<TaskOffer> offers;
  final ValueChanged<TaskOffer> onAccept;
  final VoidCallback onChat;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onReopen;
  final VoidCallback? onTracking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (task.assignedHelperId != null) ...[
          PrimaryButton(
            label: '进入聊天',
            icon: Icons.chat_bubble_outline,
            onPressed: onChat,
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTracking,
            icon: const Icon(Icons.map_outlined),
            label: const Text('地图追踪'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: task.status.canConfirmCompletion ? onComplete : null,
            icon: const Icon(Icons.task_alt_outlined),
            label: const Text('确认完成'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: task.status.canOwnerReopen ? onReopen : null,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('重新选择帮手'),
          ),
          const SizedBox(height: 16),
        ],
        if (task.status.canOwnerCancel) ...[
          OutlinedButton.icon(
            onPressed: onCancel,
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('取消任务'),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          '帮手报价',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 10),
        if (offers.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('还没有帮手报价'),
            ),
          )
        else
          ...offers.map(
            (offer) => _OfferDecisionCard(
              offer: offer,
              canAccept: offer.status == OfferStatus.pending &&
                  task.assignedHelperId == null,
              onAccept: () => onAccept(offer),
            ),
          ),
      ],
    );
  }
}

class _OfferDecisionCard extends StatelessWidget {
  const _OfferDecisionCard({
    required this.offer,
    required this.canAccept,
    required this.onAccept,
  });

  final TaskOffer offer;
  final bool canAccept;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.handyman_outlined)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.helperName ?? '帮手',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      Chip(
                        label: Text(offer.status.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatMoney(offer.amount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  if (offer.estimatedMinutes != null) ...[
                    const SizedBox(height: 4),
                    Text('预计用时：${offer.estimatedMinutes} 分钟'),
                  ],
                  const SizedBox(height: 8),
                  Text(offer.message ?? '暂无留言'),
                  if (canAccept) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('选择这位帮手'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyOfferPanel extends StatelessWidget {
  const _MyOfferPanel({
    required this.offer,
    required this.onWithdraw,
  });

  final TaskOffer offer;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '我的报价',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Chip(
                  label: Text(offer.status.label),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('报价：${formatMoney(offer.amount)}'),
            if (offer.estimatedMinutes != null)
              Text('预计用时：${offer.estimatedMinutes} 分钟'),
            if (offer.message != null && offer.message!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(offer.message!),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onWithdraw,
              icon: const Icon(Icons.undo_outlined),
              label: const Text('撤回报价'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskClosedNotice extends StatelessWidget {
  const _TaskClosedNotice({required this.status});

  final TaskStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前任务状态为「${status.label}」，暂时不能提交报价。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferPanel extends StatefulWidget {
  const _OfferPanel({required this.onSubmit});

  final Future<void> Function(double amount, String message, int? minutes)
      onSubmit;

  @override
  State<_OfferPanel> createState() => _OfferPanelState();
}

class _OfferPanelState extends State<_OfferPanel> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _message = TextEditingController();
  final _minutes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _message.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(
        double.parse(_amount.text),
        _message.text,
        int.tryParse(_minutes.text),
      );
      if (!mounted) return;
      _amount.clear();
      _message.clear();
      _minutes.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('报价已提交')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '帮手报价 / 接单',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '报价 RM'),
                validator: (value) =>
                    AppValidators.optionalMoney(value) ??
                    ((value?.trim().isEmpty ?? true) ? '请填写报价' : null),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '预计用时（分钟，可选）'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _message,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '留言'),
                validator: (value) => AppValidators.requiredText(
                  value,
                  min: 4,
                  max: 600,
                ),
              ),
              const SizedBox(height: 14),
              PrimaryButton(
                label: '提交报价',
                icon: Icons.local_offer_outlined,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskActionDialog extends StatefulWidget {
  const _TaskActionDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.reasonLabel,
  });

  final String title;
  final String message;
  final String actionLabel;
  final String reasonLabel;

  @override
  State<_TaskActionDialog> createState() => _TaskActionDialogState();
}

class _TaskActionDialogState extends State<_TaskActionDialog> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLines: 3,
            decoration: InputDecoration(labelText: widget.reasonLabel),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _reason.text),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }
}

class _ReportResult {
  const _ReportResult({required this.reason, this.details});

  final String reason;
  final String? details;
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.title});

  final String title;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  static const _reasons = [
    '违法或危险内容',
    '色情、骚扰或暴力',
    '诈骗或虚假信息',
    '侵犯隐私',
    '垃圾广告',
    '其他问题',
  ];

  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String _reason = _reasons.first;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ReportResult(reason: _reason, details: _details.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: '举报原因'),
              items: _reasons
                  .map(
                    (reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(reason),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _reason = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _details,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: '补充说明（可选）',
                hintText: '请说明发生了什么，方便后台快速判断',
              ),
              validator: (value) {
                final details = value?.trim() ?? '';
                if (details.isEmpty) return null;
                return AppValidators.requiredText(details, min: 2, max: 1200);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}

class _CompletionProofResult {
  const _CompletionProofResult({required this.note, this.file});

  final String note;
  final XFile? file;
}

class _CompletionProofDialog extends StatefulWidget {
  const _CompletionProofDialog({required this.imagePicker});

  final ImagePicker imagePicker;

  @override
  State<_CompletionProofDialog> createState() => _CompletionProofDialogState();
}

class _CompletionProofDialogState extends State<_CompletionProofDialog> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  XFile? _file;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await widget.imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _file = file);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _CompletionProofResult(note: _note.text.trim(), file: _file),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('上传完成证明'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _note,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '完成说明',
                hintText: '例如：已完成搬运，物品已放到指定位置',
              ),
              validator: (value) {
                final note = value?.trim() ?? '';
                if (note.isEmpty && _file == null) return '请填写说明或上传图片';
                if (note.isNotEmpty) {
                  return AppValidators.requiredText(note, min: 4, max: 600);
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.image_outlined),
              label: Text(_file == null ? '选择证明图片' : _file!.name),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}

class _ReviewResult {
  const _ReviewResult({required this.rating, this.comment});

  final int rating;
  final String? comment;
}

class _ReviewDialog extends StatefulWidget {
  const _ReviewDialog();

  @override
  State<_ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<_ReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final _comment = TextEditingController();
  int _rating = 5;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _ReviewResult(rating: _rating, comment: _comment.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('评价对方'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1')),
                ButtonSegment(value: 2, label: Text('2')),
                ButtonSegment(value: 3, label: Text('3')),
                ButtonSegment(value: 4, label: Text('4')),
                ButtonSegment(value: 5, label: Text('5')),
              ],
              selected: {_rating},
              onSelectionChanged: (value) =>
                  setState(() => _rating = value.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _comment,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '评价内容（可选）'),
              validator: (value) {
                final comment = value?.trim() ?? '';
                if (comment.isEmpty) return null;
                return AppValidators.requiredText(comment, min: 2, max: 800);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('提交'),
        ),
      ],
    );
  }
}
