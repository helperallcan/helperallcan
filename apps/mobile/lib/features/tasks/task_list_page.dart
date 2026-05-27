import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_assets.dart';
import '../../core/formatters.dart';
import '../../models/app_category.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/app_shell.dart';

class TaskListPage extends StatefulWidget {
  const TaskListPage({super.key});

  @override
  State<TaskListPage> createState() => _TaskListPageState();
}

class _TaskListPageState extends State<TaskListPage> {
  final _service = TaskService();
  final _city = TextEditingController();
  TaskKind? _kind;
  String? _categoryId;
  bool _urgentOnly = false;
  late Future<List<Task>> _tasksFuture;
  late Future<List<AppCategory>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _tasksFuture = _loadTasks();
    _categoriesFuture = _service.fetchCategories();
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  Future<List<Task>> _loadTasks() {
    return _service.fetchTasks(
      taskKind: _kind,
      categoryId: _categoryId,
      city: _city.text,
      urgentOnly: _urgentOnly,
    );
  }

  void _refresh() {
    setState(() => _tasksFuture = _loadTasks());
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: '任务大厅',
      actions: [
        IconButton(
          tooltip: '刷新',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _Filters(
              city: _city,
              kind: _kind,
              categoryId: _categoryId,
              urgentOnly: _urgentOnly,
              categoriesFuture: _categoriesFuture,
              onKindChanged: (value) {
                setState(() {
                  _kind = value;
                  _categoryId = null;
                });
                _refresh();
              },
              onCategoryChanged: (value) {
                setState(() => _categoryId = value);
                _refresh();
              },
              onUrgentChanged: (value) {
                setState(() => _urgentOnly = value);
                _refresh();
              },
              onCitySubmitted: (_) => _refresh(),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Task>>(
              future: _tasksFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty) {
                  return const _EmptyTasksState();
                }
                return RefreshIndicator(
                  onRefresh: () async => _refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: tasks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _TaskCard(task: tasks[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksState extends StatelessWidget {
  const _EmptyTasksState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                AppAssets.emptyTasks,
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 16),
              Text(
                '暂时没有符合条件的任务',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                '试试放宽分类、地点或加急筛选。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.city,
    required this.kind,
    required this.categoryId,
    required this.urgentOnly,
    required this.categoriesFuture,
    required this.onKindChanged,
    required this.onCategoryChanged,
    required this.onUrgentChanged,
    required this.onCitySubmitted,
  });

  final TextEditingController city;
  final TaskKind? kind;
  final String? categoryId;
  final bool urgentOnly;
  final Future<List<AppCategory>> categoriesFuture;
  final ValueChanged<TaskKind?> onKindChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<bool> onUrgentChanged;
  final ValueChanged<String> onCitySubmitted;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppCategory>>(
      future: categoriesFuture,
      builder: (context, snapshot) {
        final categories = (snapshot.data ?? [])
            .where((item) =>
                item.parentId == null &&
                (kind == null || item.taskType == kind))
            .toList();

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TaskKind?>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: '入口'),
                    items: [
                      const DropdownMenuItem<TaskKind?>(
                          value: null, child: Text('全部')),
                      ...TaskKind.values.map(
                        (item) => DropdownMenuItem<TaskKind?>(
                          value: item,
                          child: Text(item.label),
                        ),
                      ),
                    ],
                    onChanged: onKindChanged,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(labelText: '分类'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('全部')),
                      ...categories.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(item.name),
                        ),
                      ),
                    ],
                    onChanged: onCategoryChanged,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: city,
                    decoration: const InputDecoration(
                      labelText: '地点',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                    onSubmitted: onCitySubmitted,
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  selected: urgentOnly,
                  label: const Text('只看加急'),
                  avatar: const Icon(Icons.flash_on_outlined, size: 18),
                  onSelected: onUrgentChanged,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.go('/tasks/${task.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  if (task.isUrgent)
                    const Chip(
                      label: Text('加急'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Meta(
                      icon: Icons.category_outlined,
                      text: task.categoryName ?? task.taskType.label),
                  _Meta(icon: Icons.place_outlined, text: task.locationText),
                  _Meta(icon: Icons.payments_outlined, text: task.budgetLabel),
                  _Meta(
                      icon: Icons.schedule_outlined,
                      text: formatDate(task.createdAt)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
