import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/health_entry.dart';
import 'package:leevinote/services/local_health_service.dart';
import 'package:leevinote/widgets/widgets.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => HealthScreenState();
}

class HealthScreenState extends State<HealthScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      await context.read<LocalHealthService>().ensureLoaded();
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e, st) {
      debugPrint('健康数据加载失败: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  Future<void> openAddMeal() => _showMealSheet();

  Future<void> openAddWeight() => _showWeightSheet();

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LocalHealthService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surface;
    final border = isDark ? AppColors.borderDark : AppColors.border;
    final entry = service.entryForDate(_selectedDate);
    final meals = service.mealsForDate(_selectedDate);
    final calories =
        meals.fold<double>(0, (sum, meal) => sum + meal.estimatedCalories);
    final protein = meals.fold<double>(0, (sum, meal) => sum + meal.proteinG);
    final carbs = meals.fold<double>(0, (sum, meal) => sum + meal.carbsG);
    final fat = meals.fold<double>(0, (sum, meal) => sum + meal.fatG);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return AppEmptyState(
        icon: Icons.error_outline,
        title: '健康数据加载失败',
        subtitle: _loadError!,
        action: AppButton(label: '重试', width: 140, onPressed: _load),
      );
    }

    return Container(
      color: isDark ? AppColors.backgroundDark : const Color(0xFFF7F8FB),
      child: RefreshIndicator(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                _buildDateNavigator(),
                const SizedBox(height: AppSpacing.lg),
                _buildHero(entry, calories, isDark),
                const SizedBox(height: AppSpacing.xl),
                if (compact) ...[
                  _buildTodayPanel(
                      entry, calories, protein, carbs, fat, surface, border),
                  const SizedBox(height: AppSpacing.lg),
                  _buildInsightPanel(entry, meals, surface, border),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 7,
                        child: _buildTodayPanel(entry, calories, protein, carbs,
                            fat, surface, border),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        flex: 5,
                        child:
                            _buildInsightPanel(entry, meals, surface, border),
                      ),
                    ],
                  ),
                const SizedBox(height: AppSpacing.lg),
                _buildMealsSection(meals, surface, border),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDateNavigator() {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
    final label = isToday
        ? '今天'
        : '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppIconButton(
              icon: Icons.chevron_left,
              tooltip: '前一天',
              onPressed: () => setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 1));
              }),
            ),
            Expanded(
              child: AppButton.secondary(
                label: label,
                icon: Icons.calendar_today_outlined,
                width: null,
                onPressed: _selectDate,
              ),
            ),
            AppIconButton(
              icon: Icons.chevron_right,
              tooltip: '后一天',
              onPressed: isToday
                  ? null
                  : () => setState(() {
                        _selectedDate =
                            _selectedDate.add(const Duration(days: 1));
                      }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppChip(
          label: '仅保存在本机',
          icon: Icons.cloud_off_outlined,
        ),
      ],
    );
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Widget _buildHero(HealthEntry? entry, double calories, bool isDark) {
    final dayLabel = DateUtils.isSameDay(_selectedDate, DateTime.now())
        ? '今日'
        : '${_selectedDate.month}月${_selectedDate.day}日';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: isDark ? AppShadows.dark : AppShadows.medium,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Health Studio',
                    style:
                        AppTypography.smallMediumLight(color: Colors.white70)),
                const SizedBox(height: AppSpacing.sm),
                Text('$dayLabel身体与饮食记录',
                    style: AppTypography.h1Light(color: Colors.white)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '记录体重、身体照片和每餐摄入，形成可追踪的健康日报。',
                  style: AppTypography.captionLight(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          _HeroMetric(
              label: '体重',
              value: entry?.weightKg == null
                  ? '--'
                  : '${entry!.weightKg!.toStringAsFixed(1)}kg'),
          const SizedBox(width: AppSpacing.md),
          _HeroMetric(label: '摄入', value: '${calories.round()}kcal'),
        ],
      ),
    );
  }

  Widget _buildTodayPanel(
    HealthEntry? entry,
    double calories,
    double protein,
    double carbs,
    double fat,
    Color surface,
    Color border,
  ) {
    return _SectionCard(
      title: DateUtils.isSameDay(_selectedDate, DateTime.now())
          ? '今日概览'
          : '${_selectedDate.month}月${_selectedDate.day}日概览',
      action: AppButton.secondary(
        label: '记录体重',
        icon: Icons.monitor_weight_outlined,
        height: 40,
        width: null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        onPressed: _showWeightSheet,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '当前体重',
                  value: entry?.weightKg == null
                      ? '--'
                      : entry!.weightKg!.toStringAsFixed(1),
                  unit: 'kg',
                  icon: Icons.scale_outlined,
                  color: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _MetricCard(
                  label: '估算体脂',
                  value: entry?.estimatedBodyFatPercent == null
                      ? '--'
                      : entry!.estimatedBodyFatPercent!.toStringAsFixed(1),
                  unit: '%',
                  icon: Icons.accessibility_new_outlined,
                  color: const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                  child: _MacroTile(
                      label: '热量',
                      value: calories.round(),
                      unit: 'kcal',
                      color: AppColors.warning)),
              Expanded(
                  child: _MacroTile(
                      label: '蛋白质',
                      value: protein.round(),
                      unit: 'g',
                      color: AppColors.success)),
              Expanded(
                  child: _MacroTile(
                      label: '碳水',
                      value: carbs.round(),
                      unit: 'g',
                      color: const Color(0xFF3B82F6))),
              Expanded(
                  child: _MacroTile(
                      label: '脂肪',
                      value: fat.round(),
                      unit: 'g',
                      color: const Color(0xFFEF4444))),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: '上传身体照片',
                  icon: Icons.photo_camera_outlined,
                  onPressed: _pickBodyPhoto,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppButton.secondary(
                  label: '添加饮食',
                  icon: Icons.restaurant_menu_outlined,
                  onPressed: _showMealSheet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightPanel(
      HealthEntry? entry, List<MealEntry> meals, Color surface, Color border) {
    final photoPath = entry?.bodyPhotoPath;
    return _SectionCard(
      title: '粗略估算与照片',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.antiAlias,
              child: photoPath == null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 36,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(height: AppSpacing.sm),
                          Text('添加身体照片并结合体重生成粗略估算',
                              style: context.captionMedium),
                        ],
                      ),
                    )
                  : _LocalImage(path: photoPath),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _InsightRow(
            icon: Icons.auto_awesome_outlined,
            title: '体脂率粗略估算',
            body: entry?.bodyAnalysisNote ?? '记录体重后生成粗略趋势，仅供日常参考，不构成医疗建议。',
          ),
          const SizedBox(height: AppSpacing.md),
          _InsightRow(
            icon: Icons.local_fire_department_outlined,
            title: '热量估算',
            body: meals.isEmpty
                ? '添加饮食或餐食照片后，会自动形成每日热量与三大营养素摘要。'
                : '今日已记录 ${meals.length} 餐，建议晚间复盘实际份量并微调估算值。',
          ),
        ],
      ),
    );
  }

  Widget _buildMealsSection(
      List<MealEntry> meals, Color surface, Color border) {
    return _SectionCard(
      title: DateUtils.isSameDay(_selectedDate, DateTime.now())
          ? '今日饮食'
          : '${_selectedDate.month}月${_selectedDate.day}日饮食',
      action: AppButton.secondary(
        label: '添加饮食',
        icon: Icons.add,
        height: 40,
        width: null,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        onPressed: _showMealSheet,
      ),
      child: meals.isEmpty
          ? AppEmptyState(
              icon: Icons.restaurant_outlined,
              title: '还没有饮食记录',
              subtitle: '添加早餐、午餐、晚餐或加餐，系统会汇总热量。',
              action: AppButton(
                label: '添加第一餐',
                icon: Icons.add,
                width: 180,
                onPressed: _showMealSheet,
              ),
            )
          : Column(
              children: meals
                  .map((meal) =>
                      _MealTile(meal: meal, onDelete: () => _deleteMeal(meal)))
                  .toList(),
            ),
    );
  }

  Future<void> _showWeightSheet() async {
    final service = context.read<LocalHealthService>();
    final current = service.entryForDate(_selectedDate)?.weightKg;
    final controller =
        TextEditingController(text: current?.toStringAsFixed(1) ?? '');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.sm,
          AppSpacing.xl,
          MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('记录体重', style: context.h2),
            const SizedBox(height: AppSpacing.lg),
            AppInput(
              controller: controller,
              hintText: '例如 68.5',
              labelText: '体重 kg',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              prefixIcon: const Icon(Icons.scale_outlined, size: 20),
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: '保存体重',
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    final input = controller.text.trim();
    controller.dispose();
    if (saved == true) {
      final value = double.tryParse(input);
      if (value == null || value <= 0) {
        if (mounted) AppToast.error(context, '请输入有效体重');
        return;
      }
      try {
        await service.saveWeight(date: _selectedDate, weightKg: value);
        if (mounted) AppToast.success(context, '体重已保存');
      } catch (e, st) {
        debugPrint('保存体重失败: $e\n$st');
        if (mounted) AppToast.error(context, '体重保存失败，请重试');
      }
    }
  }

  Future<void> _showMealSheet() async {
    final service = context.read<LocalHealthService>();
    final titleController = TextEditingController();
    final descController = TextEditingController();
    var mealType = '午餐';
    String? photoPath;
    MealEstimate? estimate;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          void refreshEstimate() {
            estimate = service.estimateMeal(
              title: titleController.text,
              description: descController.text,
              photoPath: photoPath,
            );
            setSheetState(() {});
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('添加饮食', style: context.h2),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: ['早餐', '午餐', '晚餐', '加餐']
                        .map((type) => ChoiceChip(
                              label: Text(type),
                              selected: mealType == type,
                              onSelected: (_) =>
                                  setSheetState(() => mealType = type),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  AppInput(
                    controller: titleController,
                    labelText: '食物名称',
                    hintText: '例如 鸡胸肉沙拉 / 牛肉饭',
                    prefixIcon:
                        const Icon(Icons.restaurant_menu_outlined, size: 20),
                    onChanged: (_) => refreshEstimate(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppInput(
                    controller: descController,
                    labelText: '份量和备注',
                    hintText: '例如 大份、少油、含一杯奶茶',
                    maxLines: 3,
                    onChanged: (_) => refreshEstimate(),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppButton.secondary(
                    label: photoPath == null ? '添加餐食照片' : '已添加照片',
                    icon: Icons.photo_library_outlined,
                    onPressed: () async {
                      final path = await _pickImagePath();
                      if (path != null) {
                        photoPath = path;
                        refreshEstimate();
                      }
                    },
                  ),
                  if (estimate != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _EstimatePreview(estimate: estimate!),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: '保存饮食',
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) {
                        AppToast.error(context, '请输入食物名称');
                        return;
                      }
                      final result = estimate ??
                          service.estimateMeal(
                              title: title,
                              description: descController.text,
                              photoPath: photoPath);
                      try {
                        await service.addMeal(MealEntry(
                          mealDate: _selectedDate,
                          mealType: mealType,
                          title: title,
                          description: descController.text.trim().isEmpty
                              ? null
                              : descController.text.trim(),
                          photoPath: photoPath,
                          estimatedCalories: result.calories,
                          proteinG: result.proteinG,
                          carbsG: result.carbsG,
                          fatG: result.fatG,
                          analysisNote: result.note,
                        ));
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) AppToast.success(context, '饮食已保存');
                      } catch (e, st) {
                        debugPrint('保存饮食失败: $e\n$st');
                        if (mounted) AppToast.error(context, '饮食保存失败，请重试');
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    titleController.dispose();
    descController.dispose();
  }

  Future<void> _pickBodyPhoto() async {
    try {
      final service = context.read<LocalHealthService>();
      final path = await _pickImagePath();
      if (path == null) return;
      await service.saveBodyPhoto(
        date: _selectedDate,
        photoPath: path,
        currentWeightKg: service.entryForDate(_selectedDate)?.weightKg,
      );
      if (mounted) AppToast.success(context, '身体照片已保存，粗略估算已更新');
    } catch (e, st) {
      debugPrint('保存身体照片失败: $e\n$st');
      if (mounted) AppToast.error(context, '照片保存失败，请重试');
    }
  }

  Future<String?> _pickImagePath() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (kIsWeb) {
      final bytes = file.bytes;
      if (bytes == null) return null;
      final extension = (file.extension ?? 'png').toLowerCase();
      return 'data:image/$extension;base64,${base64Encode(bytes)}';
    }

    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory('${directory.path}/leevinote/health');
    await imageDirectory.create(recursive: true);
    final extension = file.extension ?? 'png';
    final destination = File(
      '${imageDirectory.path}/${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    if (file.bytes != null) {
      await destination.writeAsBytes(file.bytes!);
    } else if (file.path != null) {
      await File(file.path!).copy(destination.path);
    } else {
      return null;
    }
    return destination.path;
  }

  Future<void> _deleteMeal(MealEntry meal) async {
    final confirmed = await AppDialog.confirm(
      context: context,
      title: '删除饮食记录',
      content: '确定删除“${meal.title}”吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<LocalHealthService>().deleteMeal(meal.localId);
      if (mounted) AppToast.success(context, '饮食记录已删除');
    } catch (e, st) {
      debugPrint('删除饮食失败: $e\n$st');
      if (mounted) AppToast.error(context, '删除失败，请重试');
    }
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;

  const _SectionCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xl),
      shadows: isDark ? AppShadows.dark : AppShadows.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.h3)),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 118,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.smallMediumLight(color: Colors.white70)),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.h3Light(color: Colors.white)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _MetricCard(
      {required this.label,
      required this.value,
      required this.unit,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: AppSpacing.md),
          Text(label, style: context.smallMedium),
          const SizedBox(height: AppSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: context.h1),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(unit, style: context.caption),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroTile extends StatelessWidget {
  final String label;
  final int value;
  final String unit;
  final Color color;

  const _MacroTile(
      {required this.label,
      required this.value,
      required this.unit,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
            width: 28,
            height: 4,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: AppSpacing.sm),
        Text(label, style: context.smallMedium),
        Text('$value$unit', style: context.bodyMedium),
      ],
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InsightRow(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: context.bodyMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(body, style: context.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _MealTile extends StatelessWidget {
  final MealEntry meal;
  final VoidCallback onDelete;

  const _MealTile({required this.meal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: meal.photoPath == null
                ? Icon(Icons.restaurant_outlined,
                    color: Theme.of(context).colorScheme.primary)
                : _LocalImage(path: meal.photoPath!),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${meal.mealType} · ${meal.title}',
                    style: context.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                Text(
                    '${meal.estimatedCalories.round()} kcal · P ${meal.proteinG.round()}g / C ${meal.carbsG.round()}g / F ${meal.fatG.round()}g',
                    style: context.caption),
              ],
            ),
          ),
          IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20)),
        ],
      ),
    );
  }
}

class _EstimatePreview extends StatelessWidget {
  final MealEstimate estimate;

  const _EstimatePreview({required this.estimate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primaryContainer
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('估算结果', style: context.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
              '${estimate.calories.round()} kcal · 蛋白 ${estimate.proteinG.round()}g · 碳水 ${estimate.carbsG.round()}g · 脂肪 ${estimate.fatG.round()}g',
              style: context.captionMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(estimate.note, style: context.small),
        ],
      ),
    );
  }
}

class _LocalImage extends StatelessWidget {
  final String path;

  const _LocalImage({required this.path});

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('data:image/')) {
      final separator = path.indexOf(',');
      if (separator > 0) {
        return Image.memory(
          base64Decode(path.substring(separator + 1)),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported_outlined),
        );
      }
    }
    if (path.startsWith('http')) {
      return Image.network(path,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image_not_supported_outlined));
    }
    if (kIsWeb) {
      return const Icon(Icons.image_not_supported_outlined);
    }
    return Image.file(File(path),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.image_not_supported_outlined));
  }
}
