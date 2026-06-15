import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/formatters.dart';
import '../../core/supabase_client.dart';
import '../../models/task.dart';
import '../../models/task_location.dart';
import '../../services/device_location_service.dart';
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
  final _deviceLocationService = DeviceLocationService();
  final _formKey = GlobalKey<FormState>();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _label = TextEditingController();
  late Future<TaskDetailData> _taskFuture;
  TaskTrackingStatus _status = TaskTrackingStatus.active;
  bool _saving = false;
  bool _locating = false;
  String? _locationError;

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
    setState(() {
      _saving = true;
      _locationError = null;
    });
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

  Future<void> _shareCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });

    try {
      final reading = await _deviceLocationService.getCurrentReading();
      _latitude.text = reading.latitude.toStringAsFixed(6);
      _longitude.text = reading.longitude.toStringAsFixed(6);
      if (_label.text.trim().isEmpty) {
        _label.text = '手机定位';
      }

      await _trackingService.shareLocation(
        taskId: widget.taskId,
        latitude: reading.latitude,
        longitude: reading.longitude,
        accuracyMeters: reading.accuracyMeters,
        headingDegrees: reading.headingDegrees,
        speedMps: reading.speedMps,
        status: _status,
        source: 'device',
        label: _label.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前位置已共享')),
      );
    } on DeviceLocationException catch (error) {
      _showLocationError(error.userMessage);
    } catch (_) {
      _showLocationError('暂时无法获取当前位置，请检查定位权限或网络后再试。');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _showLocationError(String message) {
    if (!mounted) return;
    setState(() => _locationError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                      locating: _locating,
                      locationError: _locationError,
                      myLocation: myLocation,
                      onStatusChanged: (status) =>
                          setState(() => _status = status),
                      onUseDeviceLocation: _shareCurrentLocation,
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
    final center = TaskTrackingService.mapCenter(locations);
    final centerPoint = LatLng(center.latitude, center.longitude);
    final mapKey = ValueKey(
      '${locations.length}-${center.latitude.toStringAsFixed(5)}-${center.longitude.toStringAsFixed(5)}',
    );

    return Container(
      height: 340,
      decoration: BoxDecoration(
        color: const Color(0xffe7f0ed),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            FlutterMap(
              key: mapKey,
              options: MapOptions(
                initialCenter: centerPoint,
                initialZoom: locations.isEmpty ? 12 : 14,
                minZoom: 3,
                maxZoom: 18,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.helper.mobile',
                ),
                if (locations.isNotEmpty)
                  MarkerLayer(markers: _buildMarkers(context)),
              ],
            ),
            Positioned(
              left: 12,
              top: 12,
              right: 12,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _MapBadge(
                  icon: Icons.place_outlined,
                  label: _taskLocationLabel(task),
                ),
              ),
            ),
            if (locations.isEmpty)
              const Center(
                child: _EmptyMapNotice(),
              ),
            const Positioned(
              right: 10,
              bottom: 10,
              child: _MapAttribution(),
            ),
          ],
        ),
      ),
    );
  }

  List<Marker> _buildMarkers(BuildContext context) {
    return locations.map((location) {
      final mine = location.userId == currentUserId;
      return Marker(
        point: LatLng(location.latitude, location.longitude),
        width: 96,
        height: 96,
        alignment: Alignment.bottomCenter,
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
        Icon(Icons.location_on, color: color, size: 44),
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
            Flexible(
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

class _EmptyMapNotice extends StatelessWidget {
  const _EmptyMapNotice();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(
          '等待双方共享位置',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _MapAttribution extends StatelessWidget {
  const _MapAttribution();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(220),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '© OpenStreetMap',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
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
    required this.locating,
    required this.locationError,
    required this.myLocation,
    required this.onStatusChanged,
    required this.onUseDeviceLocation,
    required this.onShare,
    required this.onStopSharing,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController latitude;
  final TextEditingController longitude;
  final TextEditingController label;
  final TaskTrackingStatus status;
  final bool saving;
  final bool locating;
  final String? locationError;
  final TaskLocation? myLocation;
  final ValueChanged<TaskTrackingStatus> onStatusChanged;
  final VoidCallback onUseDeviceLocation;
  final VoidCallback onShare;
  final VoidCallback? onStopSharing;

  bool get _isBusy => saving || locating;

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
              const SizedBox(height: 10),
              const _LocationModeHint(),
              if (locationError != null) ...[
                const SizedBox(height: 10),
                _LocationErrorBanner(message: locationError!),
              ],
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
                    _isBusy ? null : (value) => onStatusChanged(value.first),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                label: myLocation == null ? '使用手机定位共享' : '用手机定位更新',
                icon: Icons.my_location_outlined,
                isLoading: locating,
                onPressed: saving ? null : onUseDeviceLocation,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : onShare,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: Text(myLocation == null ? '保存手动坐标' : '更新手动坐标'),
              ),
              if (myLocation != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : onStopSharing,
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

class _LocationModeHint extends StatelessWidget {
  const _LocationModeHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(120),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.gps_fixed_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('手机会请求定位权限；没有权限时也可以手动填写坐标。'),
          ),
        ],
      ),
    );
  }
}

class _LocationErrorBanner extends StatelessWidget {
  const _LocationErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.location_disabled_outlined,
            size: 18,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _coordinateError(
  String? value, {
  required double min,
  required double max,
}) {
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
                  subtitle: Text(_locationSubtitle(location)),
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

  String _locationSubtitle(TaskLocation location) {
    return [
      location.coordinateLabel,
      location.sourceLabel,
      location.accuracyLabel,
      location.label,
      formatDate(location.updatedAt),
    ].whereType<String>().where((item) => item.isNotEmpty).join(' · ');
  }

  String _participantLabel(String userId) {
    if (userId == currentUserId) return '我';
    if (userId == creatorId) return '发布者';
    if (userId == assignedHelperId) return '帮手';
    return '任务成员';
  }
}

String _taskLocationLabel(Task task) {
  final city = task.city?.trim();
  final district = task.district?.trim();
  final parts = [
    if (city != null && city.isNotEmpty) city,
    if (district != null && district.isNotEmpty) district,
  ];
  if (parts.isNotEmpty) return parts.join(' ');
  return task.locationText;
}
