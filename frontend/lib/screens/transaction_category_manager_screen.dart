import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';

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
    String? selectedColor = category?.color ?? '#FF2196F3';

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
      '#FF2196F3',
      '#FF4CAF50',
      '#FFFF9800',
      '#FF9C27B0',
      '#FFE91E63',
      '#FF00BCD4',
      '#FF795548',
      '#FF607D8B',
      '#FFF44336',
      '#FF3F51B5',
    ];

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '编辑分类' : '新增分类'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameC,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '分类名称'),
                  ),
                  const SizedBox(height: 16),
                  const Text('图标', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: icons.map((item) {
                      final (key, icon) = item;
                      final selected = selectedIcon == key;
                      return InkWell(
                        onTap: () => setDialogState(() => selectedIcon = key),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 16),
                  const Text('颜色', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: colors.map((c) {
                      final selected = selectedColor == c;
                      final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
                      return InkWell(
                        onTap: () => setDialogState(() => selectedColor = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected ? Colors.black : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final name = nameC.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(ctx, {
                    'name': name,
                    'icon': selectedIcon ?? 'other',
                    'color': selectedColor ?? '#FF2196F3',
                  });
                },
                child: const Text('保存'),
              ),
            ],
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除分类'),
        content: Text('确定要删除分类"${category.name}"吗？该分类下的记录将保留但不再显示分类。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChoiceChip(
                  label: const Text('支出分类'),
                  selected: _isExpenseType,
                  selectedColor: Colors.red,
                  labelStyle: TextStyle(color: _isExpenseType ? Colors.white : Colors.red, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _isExpenseType = true),
                ),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('收入分类'),
                  selected: !_isExpenseType,
                  selectedColor: Colors.green,
                  labelStyle: TextStyle(color: !_isExpenseType ? Colors.white : Colors.green, fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _isExpenseType = false),
                ),
              ],
            ),
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final c = categories[index];
          final color = _parseColor(c.color);
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(_parseIcon(c.icon), color: color),
              ),
              title: Text(c.name),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () => _addOrEditCategory(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteCategory(c),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditCategory(null),
        child: const Icon(Icons.add),
      ),
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
