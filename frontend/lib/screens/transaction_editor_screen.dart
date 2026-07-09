import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/services/transaction_service.dart';
import 'package:leevinote/screens/transaction_category_manager_screen.dart';

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
    );
    if (picked != null) {
      setState(() => _transactionDate = picked);
    }
  }

  Future<void> _delete() async {
    final service = context.read<TransactionService>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await service.deleteTransaction(widget.transaction!.localId);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _save() async {
    final amountText = _amountC.text.trim();
    final amount = double.tryParse(amountText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入有效金额')));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? '记一笔' : '编辑记录'),
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除',
              onPressed: _delete,
            ),
          TextButton(
            onPressed: _save,
            child: const Text('保存', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChoiceChip(
                    label: const Text('支出'),
                    selected: _isExpense,
                    selectedColor: Colors.red,
                    labelStyle: TextStyle(color: _isExpense ? Colors.white : Colors.red, fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() {
                      _isExpense = true;
                      _selectedLocalCategoryId = null;
                    }),
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('收入'),
                    selected: !_isExpense,
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(color: !_isExpense ? Colors.white : Colors.green, fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() {
                      _isExpense = false;
                      _selectedLocalCategoryId = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountC,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '0.00',
                border: InputBorder.none,
                prefixIcon: Icon(Icons.attach_money, size: 32),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('日期'),
              trailing: Text(
                DateFormat('yyyy年MM月dd日', 'zh_CN').format(_transactionDate),
                style: const TextStyle(fontSize: 16),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            const Text('选择分类', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ...categories.map((c) => _buildCategoryChip(c)),
                ActionChip(
                  avatar: const Icon(Icons.add),
                  label: const Text('管理分类'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionCategoryManagerScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _noteC,
              decoration: const InputDecoration(
                labelText: '备注',
                hintText: '添加备注（可选）',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(TransactionCategory category) {
    final selected = _selectedLocalCategoryId == category.localId;
    final color = _parseColor(category.color);
    return ChoiceChip(
      avatar: Icon(_parseIcon(category.icon), color: selected ? Colors.white : color, size: 18),
      label: Text(category.name),
      selected: selected,
      selectedColor: color,
      labelStyle: TextStyle(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
      onSelected: (_) => setState(() => _selectedLocalCategoryId = category.localId),
    );
  }

  IconData _parseIcon(String? iconName) {
    switch (iconName) {
      case 'food':
        return Icons.restaurant;
      case 'transport':
        return Icons.directions_car;
      case 'shopping':
        return Icons.shopping_bag;
      case 'entertainment':
        return Icons.movie;
      case 'housing':
        return Icons.home;
      case 'medical':
        return Icons.local_hospital;
      case 'education':
        return Icons.school;
      case 'salary':
        return Icons.account_balance_wallet;
      case 'bonus':
        return Icons.card_giftcard;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.label;
    }
  }

  Color _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) {
      return Colors.grey;
    }
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.grey;
    }
  }
}
