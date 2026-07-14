import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/widgets/widgets.dart';

class TransactionCategoryManagerScreen extends StatefulWidget {
  const TransactionCategoryManagerScreen({super.key});

  @override
  State<TransactionCategoryManagerScreen> createState() =>
      _TransactionCategoryManagerScreenState();
}

class _TransactionCategoryManagerScreenState
    extends State<TransactionCategoryManagerScreen> {
  bool _isExpenseType = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalTransactionCategoryService>().ensureLoaded();
    });
  }

  Future<void> _addOrEditCategory(TransactionCategory? category) async {
    final isEdit = category != null;
    final nameC = TextEditingController(text: category?.name ?? '');
    String? selectedIcon = category?.icon ?? 'food';
    String? selectedColor = category?.color ?? '#FF6366F1';

    final icons = [
      ('food', Icons.restaurant),
      ('transport', Icons.directions_car),
      ('shopping', Icons.shopping_bag),
      ('entertainment', Icons.movie),
      ('housing', Icons.home),
      ('medical', Icons.local_hospital),
      ('education', Icons.school),
      ('salary', Icons.account_balance_wallet),
      ('bonus', Icons.card_giftcard),
      ('investment', Icons.trending_up),
      ('other', Icons.label),
    ];

    final colors = [
      '#FF6366F1',
      '#FF10B981',
      '#FFF59E0B',
      '#FF8B5CF6',
      '#FFEC4899',
      '#FF06B6D4',
      '#FF795548',
      '#FF607D8B',
      '#FFEF4444',
      '#FF3B82F6',
    ];

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEdit ? '编辑分类' : '新增分类',
                      style: AppTypography.h2Light(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppInput(
                      controller: nameC,
                      hintText: '分类名称',
                      autofocus: true,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('图标', style: AppTypography.captionMediumLight()),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: icons.map((item) {
                        final (key, icon) = item;
                        final selected = selectedIcon == key;
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedIcon = key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Theme.of(context).colorScheme.primaryContainer
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: Icon(icon, size: 24),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text('颜色', style: AppTypography.captionMediumLight()),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: colors.map((c) {
                        final selected = selectedColor == c;
                        final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                        return GestureDetector(
                          onTap: () => setDialogState(() => selectedColor = c),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? AppColors.primaryText : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: AppButton.secondary(
                            label: '取消',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: AppButton(
                            label: '保存',
                            onPressed: () {
                              final name = nameC.text.trim();
                              if (name.isEmpty) return;
                              Navigator.pop(ctx, {
                                'name': name,
                                'icon': selectedIcon ?? 'other',
                                'color': selectedColor ?? '#FF6366F1',
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    final service = context.read<LocalTransactionCategoryService>();
    if (isEdit) {
      await service.updateCategory(category.copyWith(
        type: _isExpenseType ? 'expense' : 'income',
        name: result['name']!,
        icon: () => result['icon'],
        color: () => result['color'],
        syncStatus: category.id != null ? 'modified' : 'local',
      ));
    } else {
      await service.addCategory(TransactionCategory(
        type: _isExpenseType ? 'expense' : 'income',
        name: result['name']!,
        icon: result['icon'],
        color: result['color'],
      ));
    }
  }

  Future<void> _deleteCategory(TransactionCategory category) async {
    final service = context.read<LocalTransactionCategoryService>();
    final confirm = await AppDialog.confirm(
      context: context,
      title: '删除分类',
      content: '确定要删除分类"${category.name}"吗？该分类下的记录将保留但不再显示分类。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirm == true) {
      await service.deleteCategory(category.localId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allCategories = context.watch<LocalTransactionCategoryService>().categories;
    final categories = allCategories
        .where((c) => c.type == (_isExpenseType ? 'expense' : 'income'))
        .toList();

    return AppScaffold.noPadding(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.arrow_back,
          onPressed: () => Navigator.pop(context),
        ),
        title: '分类管理',
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageHorizontal,
              vertical: AppSpacing.md,
            ),
            child: _buildTypeToggle(),
          ),
          Expanded(
            child: categories.isEmpty
                ? const AppEmptyState(
                    icon: Icons.category_outlined,
                    title: '暂无分类',
                    subtitle: '点击右下角按钮添加',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final c = categories[index];
                      final color = _parseColor(c.color);
                      return AnimatedListItem(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
                          child: AppCard(
                            shadows: const [],
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Icon(_parseIcon(c.icon), color: color, size: 22),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(c.name, style: AppTypography.bodyMediumLight())),
                                AppIconButton(
                                  icon: Icons.edit_outlined,
                                  color: AppColors.tertiaryText,
                                  onPressed: () => _addOrEditCategory(c),
                                ),
                                AppIconButton(
                                  icon: Icons.delete_outline,
                                  color: AppColors.tertiaryText,
                                  onPressed: () => _deleteCategory(c),
                                ),
                                AppIconButton(
                                  icon: Icons.drag_handle,
                                  color: AppColors.tertiaryText,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: AppFAB(
        onPressed: () => _addOrEditCategory(null),
        icon: Icons.add,
        label: '新增分类',
      ),
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTypeChip(label: '支出', isExpense: true),
          ),
          Expanded(
            child: _buildTypeChip(label: '收入', isExpense: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({required String label, required bool isExpense}) {
    final selected = _isExpenseType == isExpense;

    return GestureDetector(
      onTap: () => setState(() => _isExpenseType = isExpense),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? AppColors.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTypography.bodyMediumLight(
              color: selected ? Colors.white : AppColors.secondaryText,
            ),
          ),
        ),
      ),
    );
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'food': return Icons.restaurant;
      case 'transport': return Icons.directions_car;
      case 'shopping': return Icons.shopping_bag;
      case 'entertainment': return Icons.movie;
      case 'housing': return Icons.home;
      case 'medical': return Icons.local_hospital;
      case 'education': return Icons.school;
      case 'salary': return Icons.account_balance_wallet;
      case 'bonus': return Icons.card_giftcard;
      case 'investment': return Icons.trending_up;
      default: return Icons.label;
    }
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return AppColors.secondaryText;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.secondaryText;
    }
  }
}
