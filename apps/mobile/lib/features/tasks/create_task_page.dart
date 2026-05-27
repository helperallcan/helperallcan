import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/validators.dart';
import '../../models/app_category.dart';
import '../../models/task.dart';
import '../../models/task_create_input.dart';
import '../../services/task_service.dart';
import '../../services/upload_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/primary_button.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({super.key, required this.taskKind});

  final TaskKind taskKind;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  static const _maxImages = 6;

  final _formKey = GlobalKey<FormState>();
  final _taskService = TaskService();
  final _uploadService = UploadService();
  final _picker = ImagePicker();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _city = TextEditingController();
  final _district = TextEditingController();
  final _budgetMin = TextEditingController();
  final _budgetMax = TextEditingController();
  List<AppCategory> _categories = [];
  List<XFile> _images = [];
  String? _categoryId;
  String? _subcategoryId;
  String? _categoryError;
  bool _isUrgent = false;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _city.dispose();
    _district.dispose();
    _budgetMin.dispose();
    _budgetMax.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loading = true;
      _categoryError = null;
    });

    try {
      final categories =
          await _taskService.fetchCategories(taskKind: widget.taskKind);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoryError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final remaining = _maxImages - _images.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多上传 6 张图片')),
      );
      return;
    }

    final files = await _picker.pickMultiImage(
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (files.isEmpty || !mounted) return;

    setState(() {
      _images = [..._images, ...files.take(remaining)];
    });

    if (files.length > remaining && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保留前 6 张图片')),
      );
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images = [
        for (var i = 0; i < _images.length; i++)
          if (i != index) _images[i],
      ];
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final input = _buildInput();
    final rangeError = input.budgetRangeError;
    if (rangeError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(rangeError)),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final taskId = await _taskService.createTask(input);

      for (var index = 0; index < _images.length; index++) {
        final uploaded = await _uploadService.uploadTaskImage(
          taskId: taskId,
          file: _images[index],
        );
        await _taskService.addTaskImage(
          taskId: taskId,
          storagePath: uploaded.path,
          publicUrl: uploaded.publicUrl,
          sortOrder: index,
        );
      }

      if (!mounted) return;
      context.go('/tasks/$taskId');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$error')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  TaskCreateInput _buildInput() {
    return TaskCreateInput(
      taskKind: widget.taskKind,
      title: _title.text,
      description: _description.text,
      locationText: _location.text,
      categoryId: _categoryId,
      subcategoryId: _subcategoryId,
      city: _city.text,
      district: _district.text,
      budgetMin: TaskCreateInput.parseOptionalMoney(_budgetMin.text),
      budgetMax: TaskCreateInput.parseOptionalMoney(_budgetMax.text),
      isUrgent: _isUrgent,
    );
  }

  String? _validateBudgetMax(String? value) {
    return AppValidators.optionalMoney(value) ??
        AppValidators.budgetRange(
          minValue: _budgetMin.text,
          maxValue: value,
        );
  }

  @override
  Widget build(BuildContext context) {
    final parents = _categories.where((item) => item.parentId == null).toList();
    final children =
        _categories.where((item) => item.parentId == _categoryId).toList();

    return AppShell(
      title: widget.taskKind.label,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categoryError != null
              ? _CategoryLoadError(onRetry: _loadCategories)
              : AbsorbPointer(
                  absorbing: _submitting,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(
                          '发布需求',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 6),
                        const Text('写清楚需求、地点和预算，方便附近帮手快速报价。'),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(
                            labelText: '标题',
                            prefixIcon: Icon(Icons.title_outlined),
                          ),
                          validator: (value) => AppValidators.requiredText(
                            value,
                            min: 4,
                            max: 80,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '详细说明',
                            alignLabelWithHint: true,
                          ),
                          validator: (value) => AppValidators.requiredText(
                            value,
                            min: 10,
                            max: 2000,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _CategoryFields(
                          parents: parents,
                          children: children,
                          categoryId: _categoryId,
                          subcategoryId: _subcategoryId,
                          onCategoryChanged: (value) {
                            setState(() {
                              _categoryId = value;
                              _subcategoryId = null;
                            });
                          },
                          onSubcategoryChanged: (value) {
                            setState(() => _subcategoryId = value);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _location,
                          decoration: const InputDecoration(
                            labelText: '地点或服务范围',
                            prefixIcon: Icon(Icons.place_outlined),
                          ),
                          validator: (value) => AppValidators.requiredText(
                            value,
                            min: 2,
                            max: 160,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _city,
                                decoration:
                                    const InputDecoration(labelText: '城市'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _district,
                                decoration:
                                    const InputDecoration(labelText: '地区'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMin,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(labelText: '最低预算 RM'),
                                validator: AppValidators.optionalMoney,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _budgetMax,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(labelText: '最高预算 RM'),
                                validator: _validateBudgetMax,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: _isUrgent,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('加急发布'),
                          subtitle: const Text('当前会突出显示；后续可接入加急发布费。'),
                          secondary: const Icon(Icons.flash_on_outlined),
                          onChanged: (value) =>
                              setState(() => _isUrgent = value),
                        ),
                        const SizedBox(height: 10),
                        _ImagePickerSection(
                          images: _images,
                          maxImages: _maxImages,
                          onPickImages: _pickImages,
                          onRemoveImage: _removeImage,
                        ),
                        const SizedBox(height: 20),
                        PrimaryButton(
                          label: _submitting ? '发布中' : '发布任务',
                          icon: Icons.send_outlined,
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

class _CategoryLoadError extends StatelessWidget {
  const _CategoryLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.category_outlined, size: 40),
            const SizedBox(height: 12),
            const Text('分类加载失败'),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryFields extends StatelessWidget {
  const _CategoryFields({
    required this.parents,
    required this.children,
    required this.categoryId,
    required this.subcategoryId,
    required this.onCategoryChanged,
    required this.onSubcategoryChanged,
  });

  final List<AppCategory> parents;
  final List<AppCategory> children;
  final String? categoryId;
  final String? subcategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onSubcategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          initialValue: categoryId,
          decoration: const InputDecoration(
            labelText: '分类',
            prefixIcon: Icon(Icons.category_outlined),
          ),
          items: parents
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          onChanged: parents.isEmpty ? null : onCategoryChanged,
          validator: (value) => value == null ? '请选择分类' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: subcategoryId,
          decoration: const InputDecoration(
            labelText: '子分类',
            prefixIcon: Icon(Icons.account_tree_outlined),
          ),
          items: children
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name),
                ),
              )
              .toList(),
          onChanged: children.isEmpty ? null : onSubcategoryChanged,
          validator: (value) {
            if (children.isEmpty) return null;
            return value == null ? '请选择子分类' : null;
          },
        ),
      ],
    );
  }
}

class _ImagePickerSection extends StatelessWidget {
  const _ImagePickerSection({
    required this.images,
    required this.maxImages,
    required this.onPickImages,
    required this.onRemoveImage,
  });

  final List<XFile> images;
  final int maxImages;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '任务图片',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            Text('${images.length}/$maxImages'),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: images.length >= maxImages ? null : onPickImages,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: Text(images.isEmpty ? '上传任务图片' : '继续添加图片'),
        ),
        if (images.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: images.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              return _SelectedImageTile(
                file: images[index],
                onRemove: () => onRemoveImage(index),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _SelectedImageTile extends StatelessWidget {
  const _SelectedImageTile({
    required this.file,
    required this.onRemove,
  });

  final XFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: FutureBuilder<Uint8List>(
            future: file.readAsBytes(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Container(
                  color: Colors.white,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
              );
            },
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filledTonal(
            tooltip: '移除图片',
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18),
            style: IconButton.styleFrom(
              minimumSize: const Size(32, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
