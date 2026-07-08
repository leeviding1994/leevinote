import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/services/transaction_service.dart';
import 'package:leevinote/services/transaction_category_service.dart';
import 'package:leevinote/screens/login_screen.dart';
import 'package:leevinote/screens/transaction_editor_screen.dart';
import 'package:leevinote/screens/transaction_category_manager_screen.dart';

enum _TransactionView { day, month, year }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => TransactionsScreenState();
}

class TransactionsScreenState extends State<TransactionsScreen> {
  _TransactionView _view = _TransactionView.day;
  DateTime _focusedDate = DateTime.now();
  String? _filterType;
  String? _filterLocalCategoryId;
  String _sortBy = 'date_desc';
  bool _loading = false;
  bool _showAllExpenseCategories = false;

  List<Transaction> _transactions = [];
  List<TransactionCategory> _categories = [];

  final _amountFormat = NumberFormat('0.00');
  final _summaryFormat = NumberFormat('0.##');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final localService = context.read<LocalTransactionService>();
    final categoryService = context.read<LocalTransactionCategoryService>();
    await localService.ensureLoaded();
    await categoryService.ensureLoaded();
    await _refreshData();
    setState(() => _loading = false);
  }

  Future<void> _refreshData() async {
    final localService = context.read<LocalTransactionService>();
    final categoryService = context.read<LocalTransactionCategoryService>();
    await localService.ensureLoaded();
    await categoryService.ensureLoaded();

    var transactions = List<Transaction>.from(localService.transactions)
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    if (_filterType != null) {
      transactions = transactions.where((t) => t.type == _filterType).toList();
    }
    if (_filterLocalCategoryId != null) {
      transactions = transactions.where((t) => t.localCategoryId == _filterLocalCategoryId).toList();
    }

    if (_sortBy == 'amount_desc') {
      transactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'amount_asc') {
      transactions.sort((a, b) => a.amount.compareTo(b.amount));
    } else if (_sortBy == 'date_asc') {
      transactions.sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    }

    setState(() {
      _transactions = transactions;
      _categories = List.from(categoryService.categories);
    });
  }

  List<Transaction> _getTransactionsForRange(DateTime start, DateTime end) {
    final localService = context.read<LocalTransactionService>();
    return localService.transactions.where((t) {
      final date = DateTime(t.transactionDate.year, t.transactionDate.month, t.transactionDate.day);
      return !date.isBefore(start) && !date.isAfter(end) && t.syncStatus != 'deleted';
    }).toList();
  }

  (DateTime, DateTime) get _currentRange {
    switch (_view) {
      case _TransactionView.day:
      case _TransactionView.month:
        final start = DateTime(_focusedDate.year, _focusedDate.month, 1);
        final end = DateTime(_focusedDate.year, _focusedDate.month + 1, 0, 23, 59, 59);
        return (start, end);
      case _TransactionView.year:
        final start = DateTime(_focusedDate.year, 1, 1);
        final end = DateTime(_focusedDate.year, 12, 31, 23, 59, 59);
        return (start, end);
    }
  }

  String get _rangeLabel {
    switch (_view) {
      case _TransactionView.day:
      case _TransactionView.month:
        return '${_focusedDate.year}年${_focusedDate.month}月';
      case _TransactionView.year:
        return '${_focusedDate.year}年';
    }
  }

  void _previousRange() {
    setState(() {
      switch (_view) {
        case _TransactionView.day:
        case _TransactionView.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month - 1);
        case _TransactionView.year:
          _focusedDate = DateTime(_focusedDate.year - 1);
      }
    });
    _refreshData();
  }

  void _nextRange() {
    setState(() {
      switch (_view) {
        case _TransactionView.day:
        case _TransactionView.month:
          _focusedDate = DateTime(_focusedDate.year, _focusedDate.month + 1);
        case _TransactionView.year:
          _focusedDate = DateTime(_focusedDate.year + 1);
      }
    });
    _refreshData();
  }

  Future<void> openEditor(Transaction? transaction) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionEditorScreen(transaction: transaction),
      ),
    );
    if (result == true) {
      await _refreshData();
    }
  }

  Future<void> _openCategoryManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TransactionCategoryManagerScreen()),
    );
    await _refreshData();
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final service = context.read<TransactionService>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
        ],
      ),
    );
    if (confirm == true) {
      await service.deleteTransaction(transaction.localId);
      await _refreshData();
    }
  }

  Future<void> sync() async {
    final auth = context.read<AuthService>();
    final api = context.read<ApiService>();
    final localTx = context.read<LocalTransactionService>();
    final localCat = context.read<LocalTransactionCategoryService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }

    setState(() => _loading = true);
    try {
      await TransactionCategoryService(api, localCat).syncCategories();
      await TransactionService(api, localTx, categoryLocal: localCat).syncTransactions();
      await _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('同步完成'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $e'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  TransactionCategory? _getCategory(String? localCategoryId) {
    if (localCategoryId == null) return null;
    try {
      return _categories.firstWhere((c) => c.localId == localCategoryId);
    } catch (_) {
      return null;
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final expenseCategories = _categories.where((c) => c.type == 'expense').toList();
            final incomeCategories = _categories.where((c) => c.type == 'income').toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('筛选与排序', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () {
                              setSheetState(() {
                                _filterType = null;
                                _filterLocalCategoryId = null;
                                _sortBy = 'date_desc';
                              });
                            },
                            child: const Text('重置'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('类型', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _FilterChip(
                            label: '全部',
                            selected: _filterType == null,
                            onSelected: (_) => setSheetState(() => _filterType = null),
                          ),
                          _FilterChip(
                            label: '支出',
                            selected: _filterType == 'expense',
                            onSelected: (_) => setSheetState(() {
                              _filterType = 'expense';
                              _filterLocalCategoryId = null;
                            }),
                          ),
                          _FilterChip(
                            label: '收入',
                            selected: _filterType == 'income',
                            onSelected: (_) => setSheetState(() {
                              _filterType = 'income';
                              _filterLocalCategoryId = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('分类', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      if (expenseCategories.isNotEmpty) ...[
                        Text('支出', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: expenseCategories.map((c) => _FilterChip(
                            label: c.name,
                            selected: _filterLocalCategoryId == c.localId,
                            onSelected: (_) => setSheetState(() {
                              _filterLocalCategoryId = c.localId;
                              _filterType = 'expense';
                            }),
                          )).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (incomeCategories.isNotEmpty) ...[
                        Text('收入', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: incomeCategories.map((c) => _FilterChip(
                            label: c.name,
                            selected: _filterLocalCategoryId == c.localId,
                            onSelected: (_) => setSheetState(() {
                              _filterLocalCategoryId = c.localId;
                              _filterType = 'income';
                            }),
                          )).toList(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text('排序', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _FilterChip(
                            label: '时间倒序',
                            selected: _sortBy == 'date_desc',
                            onSelected: (_) => setSheetState(() => _sortBy = 'date_desc'),
                          ),
                          _FilterChip(
                            label: '时间正序',
                            selected: _sortBy == 'date_asc',
                            onSelected: (_) => setSheetState(() => _sortBy = 'date_asc'),
                          ),
                          _FilterChip(
                            label: '金额从高到低',
                            selected: _sortBy == 'amount_desc',
                            onSelected: (_) => setSheetState(() => _sortBy = 'amount_desc'),
                          ),
                          _FilterChip(
                            label: '金额从低到高',
                            selected: _sortBy == 'amount_asc',
                            onSelected: (_) => setSheetState(() => _sortBy = 'amount_asc'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _refreshData();
                          },
                          child: const Text('确定'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocalTransactionService>();
    context.watch<LocalTransactionCategoryService>();

    return Column(
      children: [
        if (_view == _TransactionView.day)
          _buildDayHeaderCard()
        else
          _buildSummaryHeroCard(),
        _buildDayControls(),
        if (_view != _TransactionView.month) _buildActionsBar(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
        ),
      ],
    );
  }

  Widget _buildDayHeaderCard() {
    final (start, end) = _currentRange;
    final transactions = _getTransactionsForRange(start, end);
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final balance = income - expense;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4DBE), Color(0xFF7B5CFA)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('结余', style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '¥ ${balance >= 0 ? '' : '-'}${_amountFormat.format(balance.abs())}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStat('收入', '+¥ ${_amountFormat.format(income)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat('支出', '-¥ ${_amountFormat.format(expense)}', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _buildCompactViewSelector(),
          const SizedBox(width: 12),
          Expanded(child: _buildCompactDateNavigator()),
        ],
      ),
    );
  }

  Widget _buildCompactViewSelector() {
    return SegmentedButton<_TransactionView>(
      segments: const [
        ButtonSegment(value: _TransactionView.day, label: Text('日')),
        ButtonSegment(value: _TransactionView.month, label: Text('月')),
        ButtonSegment(value: _TransactionView.year, label: Text('年')),
      ],
      selected: {_view},
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onSelectionChanged: (set) {
        if (set.isNotEmpty) {
          setState(() => _view = set.first);
          _refreshData();
        }
      },
    );
  }

  Widget _buildCompactDateNavigator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: _previousRange,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            _rangeLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: _nextRange,
        ),
      ],
    );
  }

  Widget _buildActionsBar() {
    final hasFilter = _filterType != null || _filterLocalCategoryId != null || _sortBy != 'date_desc';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: _showFilterBottomSheet,
            icon: Badge(
              isLabelVisible: hasFilter,
              smallSize: 8,
              child: const Icon(Icons.filter_list, size: 18),
            ),
            label: const Text('筛选'),
          ),
          const SizedBox(width: 24),
          TextButton.icon(
            onPressed: _openCategoryManager,
            icon: const Icon(Icons.category, size: 18),
            label: const Text('分类管理'),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_view) {
      case _TransactionView.day:
        return _buildDayView();
      case _TransactionView.month:
        return _buildMonthAnalyticsView();
      case _TransactionView.year:
        return _buildYearAnalyticsView();
    }
  }

  Widget _buildDayView() {
    if (_transactions.isEmpty) {
      return _buildEmptyState();
    }

    final grouped = <String, List<Transaction>>{};
    for (final t in _transactions) {
      final key = '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        ...sortedKeys.expand((key) {
          final items = grouped[key]!;
          final date = DateTime.parse(key);
          return [
            _buildDayHeader(date, items),
            ...items.map((t) => _buildTransactionTile(t)),
          ];
        }),
      ],
    );
  }

  Widget _buildSummaryHeroCard() {
    final (start, end) = _currentRange;
    final transactions = _getTransactionsForRange(start, end);
    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final balance = income - expense;
    final savingsRate = income > 0 ? balance / income : 0.0;
    final label = _view == _TransactionView.year ? '本年结余' : '本月结余';
    final isBalancePositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4DBE), Color(0xFF7B5CFA)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '¥ ${isBalancePositive ? '' : '-'}${_amountFormat.format(balance.abs())}',
            style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStat('收入', '+¥ ${_amountFormat.format(income)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat('支出', '-¥ ${_amountFormat.format(expense)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat('结余率', '${(savingsRate * 100).toStringAsFixed(1)}%', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildHeroDivider() {
    return Container(width: 1, height: 24, color: Colors.white24);
  }

  // ---------------- 月视图分析 ----------------

  Widget _buildMonthAnalyticsView() {
    final (start, end) = _currentRange;
    final transactions = _getTransactionsForRange(start, end);
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final balance = income - expense;
    final savingsRate = income > 0 ? balance / income : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          _buildMonthSavingsRingCard(income: income, expense: expense, savingsRate: savingsRate),
          const SizedBox(height: 12),
          _buildExpenseCategoryCard(transactions),
          const SizedBox(height: 12),
          _buildMonthTrendCard(transactions),
          const SizedBox(height: 12),
          _buildMaxTransactionCards(transactions),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildMonthSavingsRingCard({
    required double income,
    required double expense,
    required double savingsRate,
  }) {
    final daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final now = DateTime.now();
    final remainingDays = (_focusedDate.year == now.year && _focusedDate.month == now.month)
        ? daysInMonth - now.day
        : (_focusedDate.isAfter(DateTime(now.year, now.month)) ? daysInMonth : 0);

    final savingsValue = savingsRate * 100;
    final expenseValue = 100 - savingsValue;

    return _buildSectionCard(
      child: Row(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 42,
                    sections: [
                      PieChartSectionData(
                        color: Colors.green.shade400,
                        value: savingsValue,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: Colors.grey.shade300,
                        value: expenseValue,
                        radius: 18,
                        showTitle: false,
                      ),
                    ],
                    pieTouchData: PieTouchData(enabled: false),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${savingsValue.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text('结余率', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本月支出', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  '-¥ ${_amountFormat.format(expense)}',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red.shade600),
                ),
                const SizedBox(height: 12),
                Text('剩余时间', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(
                  '$remainingDays天',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildExpenseCategoryCard(List<Transaction> transactions, {String title = '支出分类'}) {
    final ranking = _groupExpensesByCategory(transactions);
    if (ranking.isEmpty) {
      return _buildSectionCard(
        child: const SizedBox(height: 80, child: Center(child: Text('暂无支出数据'))),
      );
    }
    final total = ranking.fold<double>(0.0, (sum, e) => sum + (e['amount'] as double));
    final hasMore = ranking.length > 5;
    final displayItems = _showAllExpenseCategories ? ranking : ranking.take(5).toList();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('总支出 -¥ ${_amountFormat.format(total)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          ...displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final category = item['category'] as TransactionCategory?;
            final amount = item['amount'] as double;
            final color = _parseColor(category?.color) ?? _defaultCategoryColor(index);
            return _buildCategoryRankingRow(
              category: category,
              amount: amount,
              total: total,
              color: color,
            );
          }),
          if (hasMore)
            Center(
              child: TextButton(
                onPressed: () => setState(() => _showAllExpenseCategories = !_showAllExpenseCategories),
                child: Text(_showAllExpenseCategories ? '收起' : '更多'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRankingRow({
    required TransactionCategory? category,
    required double amount,
    required double total,
    required Color color,
  }) {
    final percentage = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_parseIcon(category?.icon), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category?.name ?? '未分类', style: const TextStyle(fontSize: 14)),
                    Text(
                      '-${_amountFormat.format(amount)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTrendCard(List<Transaction> transactions) {
    final daysInMonth = DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final dailyExpense = List<double>.filled(daysInMonth, 0);
    final dailyIncome = List<double>.filled(daysInMonth, 0);

    for (final t in transactions) {
      final day = t.transactionDate.day - 1;
      if (day < 0 || day >= daysInMonth) continue;
      if (t.type == 'income') {
        dailyIncome[day] += t.amount;
      } else {
        dailyExpense[day] += t.amount;
      }
    }

    final maxY = _findMax([...dailyExpense, ...dailyIncome]);
    if (maxY <= 0) return const SizedBox.shrink();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('每日收支走势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.2,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox.shrink();
                        return Text('¥${value.toInt()}', style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (daysInMonth ~/ 5).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
                        return Text('$day日', style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildSmoothLine(dailyIncome, Colors.green.shade600),
                  _buildSmoothLine(dailyExpense, Colors.red.shade600),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final label = spot.barIndex == 0 ? '收入' : '支出';
                        return LineTooltipItem(
                          '$label: ¥${spot.y.toStringAsFixed(0)}',
                          TextStyle(color: spot.bar.color, fontWeight: FontWeight.bold, fontSize: 12),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('收入', Colors.green.shade600),
              const SizedBox(width: 16),
              _buildLegendItem('支出', Colors.red.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaxTransactionCards(List<Transaction> transactions) {
    final incomeTransactions = transactions.where((t) => t.type == 'income').toList();
    final expenseTransactions = transactions.where((t) => t.type == 'expense').toList();
    incomeTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    expenseTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    final maxIncome = incomeTransactions.isNotEmpty ? incomeTransactions.first : null;
    final maxExpense = expenseTransactions.isNotEmpty ? expenseTransactions.first : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          if (maxIncome != null)
            Expanded(child: _buildMaxTransactionCard('最大单笔收入', maxIncome, Colors.green.shade600)),
          if (maxIncome != null && maxExpense != null) const SizedBox(width: 12),
          if (maxExpense != null)
            Expanded(child: _buildMaxTransactionCard('最大单笔支出', maxExpense, Colors.red.shade600)),
        ],
      ),
    );
  }

  Widget _buildMaxTransactionCard(String title, Transaction t, Color amountColor) {
    final category = _getCategory(t.localCategoryId);
    final catColor = _parseColor(category?.color) ?? Colors.grey;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_parseIcon(category?.icon), color: catColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? (t.type == 'expense' ? '支出' : '收入'),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('M月d日', 'zh_CN').format(t.transactionDate),
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${t.type == 'expense' ? '-' : '+'}¥ ${_amountFormat.format(t.amount)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: amountColor),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 年视图分析 ----------------

  Widget _buildYearAnalyticsView() {
    final (start, end) = _currentRange;
    final transactions = _getTransactionsForRange(start, end);
    if (transactions.isEmpty) {
      return _buildEmptyState();
    }

    double income = 0;
    double expense = 0;
    for (final t in transactions) {
      if (t.type == 'income') {
        income += t.amount;
      } else {
        expense += t.amount;
      }
    }
    final balance = income - expense;
    final monthCount = _activeMonthCount(transactions);
    final avgExpense = monthCount > 0 ? expense / monthCount : 0.0;
    final avgBalance = monthCount > 0 ? balance / monthCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          _buildYearOverviewCard(monthCount: monthCount, avgExpense: avgExpense, avgBalance: avgBalance),
          const SizedBox(height: 12),
          _buildYearMonthListCard(transactions),
          const SizedBox(height: 12),
          _buildExpenseCategoryCard(transactions, title: '年度支出分类'),
          const SizedBox(height: 12),
          _buildIncomeCategoryCard(transactions),
          const SizedBox(height: 12),
          _buildYearTrendCard(transactions),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildYearOverviewCard({
    required int monthCount,
    required double avgExpense,
    required double avgBalance,
  }) {
    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('年度概览', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatItem('有记录月份', '$monthCount个月'),
              ),
              Expanded(
                child: _buildOverviewStatItem('月均支出', '-¥ ${_amountFormat.format(avgExpense)}'),
              ),
              Expanded(
                child: _buildOverviewStatItem(
                  '月均结余',
                  '${avgBalance >= 0 ? '+' : '-'}¥ ${_amountFormat.format(avgBalance.abs())}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStatItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildYearMonthListCard(List<Transaction> transactions) {
    final monthlyData = List<Map<String, double>>.generate(12, (_) => {'income': 0.0, 'expense': 0.0});
    for (final t in transactions) {
      final month = t.transactionDate.month - 1;
      if (t.type == 'income') {
        monthlyData[month]['income'] = (monthlyData[month]['income'] ?? 0.0) + t.amount;
      } else {
        monthlyData[month]['expense'] = (monthlyData[month]['expense'] ?? 0.0) + t.amount;
      }
    }

    final maxAbs = monthlyData.fold(0.0, (m, e) {
      final balance = (e['income'] ?? 0.0) - (e['expense'] ?? 0.0);
      final abs = balance.abs();
      return abs > m ? abs : m;
    });

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('各月概览', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...List.generate(12, (index) {
            final income = monthlyData[index]['income'] ?? 0.0;
            final expense = monthlyData[index]['expense'] ?? 0.0;
            final balance = income - expense;
            final hasData = income > 0 || expense > 0;
            final ratio = maxAbs > 0 && hasData ? balance.abs() / maxAbs : 0.0;
            final isPositive = balance >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 36,
                    child: Text('${index + 1}月', style: const TextStyle(fontSize: 13)),
                  ),
                  if (hasData) ...[
                    Container(
                      height: 6,
                      width: 24 * ratio,
                      decoration: BoxDecoration(
                        color: isPositive ? Colors.green.shade400 : Colors.red.shade400,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ] else
                    const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      hasData ? '${isPositive ? '+' : '-'}¥ ${_amountFormat.format(balance.abs())}' : '--',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasData
                            ? (isPositive ? Colors.green.shade600 : Colors.red.shade600)
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIncomeCategoryCard(List<Transaction> transactions) {
    final ranking = _groupIncomesByCategory(transactions);
    if (ranking.isEmpty) {
      return _buildSectionCard(
        child: const SizedBox(height: 80, child: Center(child: Text('暂无收入数据'))),
      );
    }
    final total = ranking.fold<double>(0.0, (sum, e) => sum + (e['amount'] as double));

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('收入来源', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('总收入 +¥ ${_amountFormat.format(total)}', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 12),
          ...ranking.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final category = item['category'] as TransactionCategory?;
            final amount = item['amount'] as double;
            final color = _parseColor(category?.color) ?? _defaultCategoryColor(index);
            return _buildIncomeRankingRow(
              category: category,
              amount: amount,
              total: total,
              color: color,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIncomeRankingRow({
    required TransactionCategory? category,
    required double amount,
    required double total,
    required Color color,
  }) {
    final percentage = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_parseIcon(category?.icon), color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category?.name ?? '未分类', style: const TextStyle(fontSize: 14)),
                    Text(
                      '+¥ ${_amountFormat.format(amount)}',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.green.shade600),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 5,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearTrendCard(List<Transaction> transactions) {
    final monthlyData = List<Map<String, double>>.generate(12, (_) => {'income': 0.0, 'expense': 0.0});
    for (final t in transactions) {
      final month = t.transactionDate.month - 1;
      if (t.type == 'income') {
        monthlyData[month]['income'] = (monthlyData[month]['income'] ?? 0.0) + t.amount;
      } else {
        monthlyData[month]['expense'] = (monthlyData[month]['expense'] ?? 0.0) + t.amount;
      }
    }

    final maxY = _findMax([...monthlyData.expand((e) => [e['income']!, e['expense']!])]);
    if (maxY <= 0) return const SizedBox.shrink();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('全年收支走势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final month = value.toInt() + 1;
                        if (month < 1 || month > 12) return const SizedBox.shrink();
                        return Text('$month月', style: const TextStyle(fontSize: 9));
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (index) {
                  final income = monthlyData[index]['income'] ?? 0.0;
                  final expense = monthlyData[index]['expense'] ?? 0.0;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 1,
                    barRods: [
                      BarChartRodData(toY: income, color: Colors.green.shade400, width: 4, borderRadius: BorderRadius.circular(2)),
                      BarChartRodData(toY: expense, color: Colors.red.shade400, width: 4, borderRadius: BorderRadius.circular(2)),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? '收入' : '支出';
                      return BarTooltipItem(
                        '$label: ¥${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontSize: 10),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('收入', Colors.green.shade400),
              const SizedBox(width: 16),
              _buildLegendItem('支出', Colors.red.shade400),
            ],
          ),
        ],
      ),
    );
  }

  int _activeMonthCount(List<Transaction> transactions) {
    final months = <String>{};
    for (final t in transactions) {
      months.add('${t.transactionDate.year}-${t.transactionDate.month}');
    }
    return months.length;
  }

  List<Map<String, dynamic>> _groupIncomesByCategory(List<Transaction> transactions) {
    final map = <String, Map<String, dynamic>>{};
    for (final t in transactions) {
      if (t.type != 'income') continue;
      final category = _getCategory(t.localCategoryId);
      final key = category?.localId ?? '_uncategorized';
      final entry = map.putIfAbsent(key, () => {
        'category': category,
        'name': category?.name ?? '未分类',
        'amount': 0.0,
      });
      entry['amount'] = (entry['amount'] as double) + t.amount;
    }
    final result = map.values.toList();
    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return result;
  }

  double _findMax(List<double> values) {
    if (values.isEmpty) return 1;
    var max = 0.0;
    for (final v in values) {
      if (v > max) max = v;
    }
    return max;
  }

  LineChartBarData _buildSmoothLine(List<double> data, Color color) {
    return LineChartBarData(
      spots: List.generate(data.length, (index) => FlSpot(index.toDouble(), data[index])),
      color: color,
      barWidth: 2,
      isCurved: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  List<Map<String, dynamic>> _groupExpensesByCategory(List<Transaction> transactions) {
    final map = <String, Map<String, dynamic>>{};
    for (final t in transactions) {
      if (t.type != 'expense') continue;
      final category = _getCategory(t.localCategoryId);
      final key = category?.localId ?? '_uncategorized';
      final entry = map.putIfAbsent(key, () => {
        'category': category,
        'name': category?.name ?? '未分类',
        'amount': 0.0,
      });
      entry['amount'] = (entry['amount'] as double) + t.amount;
    }
    final result = map.values.toList();
    result.sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return result;
  }

  Color _defaultCategoryColor(int index) {
    final colors = [Colors.red, Colors.orange, Colors.amber, Colors.green, Colors.blue, Colors.indigo, Colors.purple, Colors.pink, Colors.teal, Colors.brown];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('暂无记录', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildDayHeader(DateTime date, List<Transaction> items) {
    final dailyIncome = items.where((t) => t.type == 'income').fold(0.0, (sum, t) => sum + t.amount);
    final dailyExpense = items.where((t) => t.type == 'expense').fold(0.0, (sum, t) => sum + t.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatDayHeader(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (dailyIncome > 0 || dailyExpense > 0)
            _buildDaySummaryLabels(dailyIncome, dailyExpense),
        ],
      ),
    );
  }

  Widget _buildDaySummaryLabels(double income, double expense) {
    final children = <InlineSpan>[];
    if (income > 0) {
      children.addAll([
        TextSpan(text: '收 ', style: TextStyle(fontSize: 11, color: Colors.green.shade600)),
        TextSpan(
          text: '+${_summaryFormat.format(income)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade600),
        ),
      ]);
    }
    if (income > 0 && expense > 0) {
      children.add(const TextSpan(text: '  '));
    }
    if (expense > 0) {
      children.addAll([
        TextSpan(text: '支 ', style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
        TextSpan(
          text: '-${_summaryFormat.format(expense)}',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red.shade600),
        ),
      ]);
    }
    return Text.rich(TextSpan(children: children));
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return '今天';
    if (d == today.subtract(const Duration(days: 1))) return '昨天';
    if (d == today.subtract(const Duration(days: 2))) return '前天';
    return DateFormat('M月d日 EEEE', 'zh_CN').format(date);
  }

  Widget _buildTransactionTile(Transaction t) {
    final category = _getCategory(t.localCategoryId);
    final isExpense = t.type == 'expense';
    final amountColor = isExpense ? Colors.red.shade600 : Colors.green.shade600;
    final catColor = _parseColor(category?.color) ?? Colors.grey;
    final iconData = _parseIcon(category?.icon);

    return InkWell(
      onTap: () => openEditor(t),
      onLongPress: () => _deleteTransaction(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(iconData, color: catColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? (isExpense ? '支出' : '收入'),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface),
                  ),
                  if (t.note != null && t.note!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      t.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isExpense ? '-' : '+'}${_amountFormat.format(t.amount)}',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: amountColor),
                ),
                if (t.syncStatus != 'synced')
                  Icon(Icons.cloud_off, size: 12, color: Theme.of(context).colorScheme.outline),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color? _parseColor(String? colorString) {
    if (colorString == null || colorString.isEmpty) return null;
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (_) {
      return null;
    }
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  const _FilterChip({required this.label, required this.selected, this.onSelected});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      visualDensity: VisualDensity.compact,
    );
  }
}
