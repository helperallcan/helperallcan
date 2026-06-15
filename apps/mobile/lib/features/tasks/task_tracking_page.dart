import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/supabase_client.dart';
import '../../models/task.dart';
import '../../models/task_location.dart';
import '../../services/task_service.dart';
import '../../services/task_tracking_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primary_button.dart';

class TaskTrackingPage extends StatefulWidget {
  const TaskTrackingPage({super.key, required this.taskId});

  final String taskId;

  @override
  State<TaskTrackingPage> createState() => _TaskTrackingPageState();
}

class _TaskTrackingPageState extends State<TaskTrackingPage> {
  final _taskService = TaskService();
  final _trackingService = TaskTrackingService();
  final _formKey = GlobalKey<FormState>();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _label = TextEditingController();
  late Future<TaskDetailData> _taskFuture;
  TaskTrackingStatus _status = TaskTrackingStatus.active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _taskFuture = _taskService.fetchTaskDetail(widget.taskId);
  }

  @override
  void dispose() {
    _latitude.dispose();
    _longitude.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _trackingService.shareLocation(
        taskId: widget.taskId,
        latitude: double.parse(_latitude.text.trim()),
        longitude: double.parse(_longitude.text.trim()),
        status: _status,
        label: _label.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('位置已共享')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _stopSharing() async {
    await _trackingService.stopSharing(widget.taskId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已停止共享位置')),
    );
  }

  Future<void> _openNavigation(TaskLocation location) async {
    final uri = TaskTrackingService.navigationUri(location);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('无法打开地图')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '任务地图追踪',
      child: FutureBuilder<TaskDetailData>(
        future: _taskFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final task = snapshot.data!.task;
          final currentUserId = supabase.auth.currentUser?.id;
          final isOwner = task.creatorId == currentUserId;
          final isAssignedHelper = task.assignedHelperId == currentUserId;
          final canTrack = task.status == TaskStatus.assigned ||
              task.status == TaskStatus.inProgress;
          final canShare = canTrack && (isOwner || isAssignedHelper);

          return StreamBuilder<List<TaskLocation>>(
            stream: _trackingService.watchTaskLocations(widget.taskId),
            builder: (context, locationSnapshot) {
              final locations = locationSnapshot.data ?? [];
              final myLocation = TaskTrackingService.locationForUser(
                locations,
                currentUserId,
              );
              final otherLocation = _otherLocation(
                locations,
                currentUserId,
              );

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
                children: [
                  _TaskTrackingHeader(task: task),
                  const SizedBox(height: 16),
                  _TrackingMapPanel(
                    task: task,
                    locations: locations,
                    currentUserId: currentUserId,
                  ),
                  const SizedBox(height: 16),
                  if (!canShare)
                    _TrackingLockedCard(task: task)
                  else
                    _ShareLocationPanel(
                      formKey: _formKey,
                      latitude: _latitude,
                      longitude: _longitude,
                      label: _label,
                      status: _status,
                      saving: _saving,
                      myLocation: myLocation,
                      onStatusChanged: (status) =>
                          setState(() => _status = status),
                      onShare: _share,
                      onStopSharing: myLocation == null ? null : _stopSharing,
                    ),
                  const SizedBox(height: 16),
                  _LocationList(
                    locations: locations,
                    currentUserId: currentUserId,
                    creatorId: task.creatorId,
                    assignedHelperId: task.assignedHelperId,
                    onNavigate: otherLocation == null ? null : _openNavigation,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

TaskLocation? _otherLocation(
  List<TaskLocation> locations,
  String? currentUserId,
) {
  for (final location in locations) {
    if (location.userId != currentUserId) return location;
  }
  return null;
}

class _TaskTrackingHeader extends StatelessWidget {
  const _TaskTrackingHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.onPrimary.withAlpha(28),
            child: Icon(
              Icons.near_me_outlined,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  task.locationText,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onPrimary.withAlpha(220),
                  ),
                ),
              ],
            ),
          ),
          Chip(
            label: Text(task.status.label),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _TrackingMapPanel extends StatelessWidget {
  const _TrackingMapPanel({
    required this.task,
    required this.locations,
    required this.currentUserId,
  });

  final Task task;
  final List<TaskLocation> locations;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: BoxDecoration(
        color: const Color(0xffe7f0ed),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        children: [
          const _MapGrid(),
          Positioned(
            left: 16,
            top: 16,
            child: _MapBadge(
              icon: Icons.place_outlined,
              label: task.district?.isNotEmpty == true
                  ? '${task.city ?? ''} ${task.district}'
                  : task.locationText,
            ),
          ),
          if (locations.isEmpty)
            const Center(
              child: Text(
                '还没有共享位置',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: _buildPins(context, constraints.biggest),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildPins(BuildContext context, Size size) {
    final bounds = _LocationBounds(locations);
    return locations.map((location) {
      final point = bounds.position(location, size);
      final mine = location.userId == currentUserId;
      return Positioned(
        left: point.dx,
        top: point.dy,
        child: _MapPin(
          label: mine ? '我' : '对方',
          location: location,
          color: mine
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.tertiary,
        ),
      );
    }).toList();
  }
}

class _LocationBounds {
  _LocationBounds(this.locations)
      : minLat = locations.map((item) => item.latitude).reduce(math.min),
        maxLat = locations.map((item) => item.latitude).reduce(math.max),
        minLng = locations.map((item) => item.longitude).reduce(math.min),
        maxLng = locations.map((item) => item.longitude).reduce(math.max);

  final List<TaskLocation> locations;
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  Offset position(TaskLocation location, Size size) {
    final isFlatLatitude = (maxLat - minLat).abs() < 0.0001;
    final isFlatLongitude = (maxLng - minLng).abs() < 0.0001;
    final latRange = isFlatLatitude ? 1.0 : maxLat - minLat;
    final lngRange = isFlatLongitude ? 1.0 : maxLng - minLng;
    final x = isFlatLongitude
        ? 0.5
        : ((location.longitude - minLng) / lngRange).clamp(0.0, 1.0);
    final y = isFlatLatitude
        ? 0.5
        : (1 - ((location.latitude - minLat) / latRange)).clamp(0.0, 1.0);
    final availableWidth = math.max(1.0, size.width - 96);
    final availableHeight = math.max(1.0, size.height - 128);
    return Offset(24 + x * availableWidth, 72 + y * availableHeight);
  }
}

class _MapGrid extends StatelessWidget {
  const _MapGrid();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MapGridPainter(
        color: Theme.of(context).colorScheme.primary.withAlpha(36),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  const _MapGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 54) {
      canvas.drawLine(Offset(x, 0), Offset(x + 80, size.height), paint);
    }
    for (var y = 28.0; y < size.height; y += 52) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 30), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({
    required this.label,
    required this.location,
    required this.color,
  });

  final String label;
  final TaskLocation location;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1f000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        Icon(Icons.location_on, color: color, size: 42),
        Text(
          location.status.label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(232),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareLocationPanel extends StatelessWidget {
  const _ShareLocationPanel({
    required this.formKey,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.status,
    required this.saving,
    required this.myLocation,
    required this.onStatusChanged,
    required this.onShare,
    required this.onStopSharing,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController label;
  final TaskTrackingStatus status;
  final bool saving;
  final TaskLocation? myLocation;
  final ValueChanged<TaskTrackingStatus> onStatusChanged;
  final VoidCallback onShare;
  final VoidCallback? onStopSharing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.my_location_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '共享我的位置',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: latitude,
                      decoration: const InputDecoration(labelText: '纬度'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        min: -90,
                        max: 90,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: longitude,
                      decoration: const InputDecoration(labelText: '经度'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      validator: (value) => _coordinateError(
                        value,
                        min: -180,
                        max: 180,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: label,
                decoration: const InputDecoration(
                  labelText: '位置备注',
                  prefixIcon: Icon(Icons.edit_location_alt_outlined),
                ),
                maxLength: 120,
              ),
              const SizedBox(height: 4),
              SegmentedButton<TaskTrackingStatus>(
                showSelectedIcon: false,
                segments: TaskTrackingStatus.values
                    .map(
                      (item) => ButtonSegment(
                        value: item,
                        label: Text(item.label),
                      ),
                    )
                    .toList(),
                selected: {status},
                onSelectionChanged:
                    saving ? null : (value) => onStatusChanged(value.first),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: myLocation == null ? '共享位置' : '更新位置',
                icon: Icons.near_me_outlined,
                isLoading: saving,
                onPressed: onShare,
              ),
              if (myLocation != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onStopSharing,
                  icon: const Icon(Icons.location_disabled_outlined),
                  label: const Text('停止共享'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String? _coordinateError(String? value,
    {required double min, required double max}) {
  final text = value?.trim() ?? '';
  final number = double.tryParse(text);
  if (number == null) return '请输入有效坐标';
  if (number < min || number > max) return '坐标超出范围';
  return null;
}

class _TrackingLockedCard extends StatelessWidget {
  const _TrackingLockedCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              Icons.lock_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '当前任务状态为「${task.status.label}」，选择帮手并开始任务后才能共享位置。',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationList extends StatelessWidget {
  const _LocationList({
    required this.locations,
    required this.currentUserId,
    required this.creatorId,
    required this.assignedHelperId,
    required this.onNavigate,
  });

  final List<TaskLocation> locations;
  final String? currentUserId;
  final String creatorId;
  final String? assignedHelperId;
  final ValueChanged<TaskLocation>? onNavigate;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '实时位置',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            if (locations.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('双方还没有共享位置'),
              )
            else
              ...locations.map(
                (location) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(
                      location.userId == creatorId
                          ? Icons.person_outline
                          : Icons.handyman_outlined,
                    ),
                  ),
                  title: Text(_participantLabel(location.userId)),
                  subtitle: Text(
                    [
                      location.coordinateLabel,
                      location.label,
                      formatDate(location.updatedAt),
                    ]
                        .whereType<String>()
                        .where((item) => item.isNotEmpty)
                        .join(' · '),
                  ),
                  trailing: location.userId == currentUserId
                      ? Chip(
                          label: Text(location.status.label),
                          visualDensity: VisualDensity.compact,
                        )
                      : IconButton(
                          tooltip: '打开地图导航',
                          onPressed: onNavigate == null
                              ? null
                              : () => onNavigate!(location),
                          icon: const Icon(Icons.directions_outlined),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _participantLabel(String userId) {
    if (userId == currentUserId) return '我';
    if (userId == creatorId) return '发布者';
    if (userId == assignedHelperId) return '帮手';
    return '任务成员';
  }
}
