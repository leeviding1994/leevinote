import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'transaction_category_manager_screen.dart';

class TransactionEditorScreen extends StatefulWidget {
  final Transaction? transaction;

  const TransactionEditorScreen({super.key, this.transaction});

  @override
  State<TransactionEditorScreen> createState() => _TransactionEditorScreenState();
}

class _TransactionEditorScreenState extends State<TransactionEditorScreen> {
  late bool _isExpense;
  late DateTime _transactionDate;
  final _amountC = TextEditingController();
  final _noteC = TextEditingController();
  String? _selectedLocalCategoryId;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _isExpense = t?.type != 'income';
    _transactionDate = t?.transactionDate ?? DateTime.now();
    _amountC.text = t != null ? t.amount.toStringAsFixed(2) : '';
    _noteC.text = t?.note ?? '';
    _selectedLocalCategoryId = t?.localCategoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocalTransactionCategoryService>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _amountC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: AppColors.brand,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _transactionDate = picked);
    }
  }

  Future<void> _save() async {
    final amountText = _amountC.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入有效金额')),
      );
      return;
    }

    final localService = context.read<LocalTransactionService>();
    final categoryService = context.read<LocalTransactionCategoryService>();
    int? categoryId;
    if (_selectedLocalCategoryId != null) {
      final category = await categoryService.getCategory(_selectedLocalCategoryId!);
      categoryId = category?.id;
    }

    final transaction = widget.transaction != null
        ? widget.transaction!.copyWith(
            type: _isExpense ? 'expense' : 'income',
            amount: amount,
            transactionDate: _transactionDate,
            categoryId: () => categoryId,
            localCategoryId: () => _selectedLocalCategoryId,
            note: () => _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
            syncStatus: widget.transaction!.id != null ? 'modified' : 'local',
          )
        : Transaction(
            type: _isExpense ? 'expense' : 'income',
            amount: amount,
            transactionDate: _transactionDate,
            categoryId: categoryId,
            localCategoryId: _selectedLocalCategoryId,
            note: _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
          );

    if (widget.transaction != null) {
      await localService.updateTransaction(transaction);
    } else {
      await localService.addTransaction(transaction);
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context
        .watch<LocalTransactionCategoryService>()
        .categories
        .where((c) => c.type == (_isExpense ? 'expense' : 'income'))
        .toList();

    final typeColor = _isExpense ? AppColors.error : AppColors.success;
    final amountStyle = AppTypography.h1Light(color: typeColor).copyWith(fontSize: 44);

    return AppScaffold.noPadding(
      appBar: AppAppBar(
        leading: AppIconButton(
          icon: Icons.close,
          onPressed: () => Navigator.pop(context),
        ),
        title: '记账',
        centerTitle: true,
        actions: [
          AppButton(
            label: '保存',
            width: null,
            height: 28,
            borderRadius: AppRadius.xs,
            padding: const EdgeInsets.symmetric(horizontal: 32),
            onPressed: _save,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 金额输入区
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('¥', style: amountStyle),
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountC,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: amountStyle,
                    decoration: InputDecoration(
                      hintText: '0.00',
                      hintStyle: amountStyle.copyWith(
                        color: typeColor.withValues(alpha: 0.35),
                      ),
                      border: InputBorder.none,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            // 类型
            _buildFormCard(
              icon: Icons.compare_arrows,
              label: '类型',
              trailing: _buildTypeToggle(),
            ),
            const SizedBox(height: AppSpacing.component),
            // 日期
            _buildFormCard(
              icon: Icons.calendar_today_outlined,
              label: '日期',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('yyyy年MM月dd日', 'zh_CN').format(_transactionDate),
                    style: AppTypography.bodyLight(color: AppColors.secondaryText),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.chevron_right, color: AppColors.tertiaryText, size: 18),
                ],
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: AppSpacing.component),
            // 备注
            _buildFormCard(
              icon: Icons.edit_note_outlined,
              label: '备注',
              trailing: Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.md),
                  child: TextField(
                    controller: _noteC,
                    textAlign: TextAlign.right,
                    style: AppTypography.bodyLight(),
                    decoration: InputDecoration(
                      hintText: '点击输入备注...',
                      hintStyle: AppTypography.bodyLight(color: AppColors.tertiaryText),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.module),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('选择分类', style: AppTypography.h3Light()),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const TransactionCategoryManagerScreen()),
                  ),
                  child: Text(
                    '管理',
                    style: AppTypography.bodyMediumLight(color: AppColors.brand),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (categories.isEmpty)
              const AppEmptyState(
                icon: Icons.category_outlined,
                title: '暂无分类',
                subtitle: '点击管理分类添加',
              )
            else
              _buildCategoryGrid(categories),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    final child = AppCard(
      shadows: const [],
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.secondaryText, size: 20),
              const SizedBox(width: AppSpacing.md),
              Text(label, style: AppTypography.bodyLight()),
            ],
          ),
          trailing,
        ],
      ),
    );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: child,
    );
  }

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTypeChip(label: '支出', expense: true),
          _buildTypeChip(label: '收入', expense: false),
        ],
      ),
    );
  }

  Widget _buildTypeChip({required String label, required bool expense}) {
    final selected = _isExpense == expense;
    final color = expense ? AppColors.error : AppColors.success;

    return GestureDetector(
      onTap: () => setState(() {
        _isExpense = expense;
        _selectedLocalCategoryId = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md - 2),
        ),
        child: Text(
          label,
          style: AppTypography.bodyMediumLight(
            color: selected ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryGrid(List<TransactionCategory> categories) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return _buildCategoryItem(category);
      },
    );
  }

  Widget _buildCategoryItem(TransactionCategory category) {
    final selected = _selectedLocalCategoryId == category.localId;
    final color = _parseColor(category.color);

    return GestureDetector(
      onTap: () => setState(() => _selectedLocalCategoryId = category.localId),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _parseIcon(category.icon),
              color: selected ? Colors.white : color,
              size: 24,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            category.name,
            style: AppTypography.smallLight(
              color: selected ? color : AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
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
