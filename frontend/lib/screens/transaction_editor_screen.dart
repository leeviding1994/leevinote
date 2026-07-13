import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/services/transaction_service.dart';
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
    _amountC.text = t != null ? t.amount.toStringAsFixed(t.amount.truncateToDouble() == t.amount ? 0 : 2) : '';
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

  Future<void> _delete() async {
    final service = context.read<TransactionService>();
    final confirmed = await AppDialog.confirm(
      context: context,
      title: '删除记录',
      content: '确定要删除这条记录吗？删除后无法恢复。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirmed != true) return;
    await service.deleteTransaction(widget.transaction!.localId);
    if (mounted) Navigator.pop(context, true);
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

    return AppScaffold.noPadding(
      appBar: AppAppBar(
        title: null,
        actions: [
          AppButton.secondary(
            label: '保存',
            width: null,
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            onPressed: _save,
          ),
          const SizedBox(width: AppSpacing.sm),
          if (widget.transaction != null)
            AppIconButton(
              icon: Icons.delete_outline,
              tooltip: '删除',
              onPressed: _delete,
            ),
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
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSecondary,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTypeChip(label: '支出', isExpense: true),
                    _buildTypeChip(label: '收入', isExpense: false),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppInput(
              controller: _amountC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: AppTypography.h1Light(),
              hintText: '0.00',
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: Text('¥', style: AppTypography.h2Light(color: AppColors.secondaryText)),
              ),
            ),
            const SizedBox(height: AppSpacing.component),
            AppCard(
              shadows: const [],
              onTap: _pickDate,
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.secondaryText),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: Text('日期', style: AppTypography.bodyLight())),
                  Text(
                    DateFormat('yyyy年MM月dd日', 'zh_CN').format(_transactionDate),
                    style: AppTypography.bodyMediumLight(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.chevron_right, color: AppColors.tertiaryText),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text('选择分类', style: AppTypography.h3Light()),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: [
                ...categories.map((c) => _buildCategoryChip(c)),
                AppChip(
                  label: '管理分类',
                  icon: Icons.add,
                  onSelected: (_) => Navigator.push(
                    context,
                    AppPageRoute(builder: (_) => const TransactionCategoryManagerScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            AppInput(
              controller: _noteC,
              hintText: '添加备注（可选）',
              prefixIcon: const Icon(Icons.notes_outlined, size: 20),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip({required String label, required bool isExpense}) {
    final selected = _isExpense == isExpense;
    final color = isExpense ? AppColors.error : AppColors.success;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: () => setState(() {
            _isExpense = isExpense;
            _selectedLocalCategoryId = null;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Text(
              label,
              style: AppTypography.bodyMediumLight(
                color: selected ? Colors.white : color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(TransactionCategory category) {
    final selected = _selectedLocalCategoryId == category.localId;
    final color = _parseColor(category.color);

    return AppChip(
      label: category.name,
      icon: _parseIcon(category.icon),
      selected: selected,
      selectedColor: color,
      onSelected: (_) => setState(() => _selectedLocalCategoryId = category.localId),
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
