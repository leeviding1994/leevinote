import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/transaction.dart';
import 'package:leevinote/models/transaction_category.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/services/transaction_service.dart';
import 'package:leevinote/services/transaction_category_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';
import 'transaction_editor_screen.dart';
import 'transaction_category_manager_screen.dart';

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
    try {
      final localService = context.read<LocalTransactionService>();
      final categoryService = context.read<LocalTransactionCategoryService>();
      await localService.ensureLoaded();
      await categoryService.ensureLoaded();
      await _refreshData();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshData() async {
    final localService = context.read<LocalTransactionService>();
    final categoryService = context.read<LocalTransactionCategoryService>();
    await localService.ensureLoaded();
    await categoryService.ensureLoaded();
    if (!mounted) return;

    var transactions = localService.transactions
        .where((t) => t.syncStatus != 'deleted')
        .toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));

    if (_filterType != null) {
      transactions = transactions.where((t) => t.type == _filterType).toList();
    }
    if (_filterLocalCategoryId != null) {
      transactions = transactions
          .where((t) => t.localCategoryId == _filterLocalCategoryId)
          .toList();
    }

    if (_sortBy == 'amount_desc') {
      transactions.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_sortBy == 'amount_asc') {
      transactions.sort((a, b) => a.amount.compareTo(b.amount));
    } else if (_sortBy == 'date_asc') {
      transactions
          .sort((a, b) => a.transactionDate.compareTo(b.transactionDate));
    }

    setState(() {
      _transactions = transactions;
      _categories = List.from(categoryService.categories);
    });
  }

  List<Transaction> _getTransactionsForRange(DateTime start, DateTime end) {
    final localService = context.read<LocalTransactionService>();
    return localService.transactions.where((t) {
      final date = DateTime(t.transactionDate.year, t.transactionDate.month,
          t.transactionDate.day);
      return !date.isBefore(start) &&
          !date.isAfter(end) &&
          t.syncStatus != 'deleted';
    }).toList();
  }

  (DateTime, DateTime) get _currentRange {
    switch (_view) {
      case _TransactionView.day:
      case _TransactionView.month:
        final start = DateTime(_focusedDate.year, _focusedDate.month, 1);
        final end =
            DateTime(_focusedDate.year, _focusedDate.month + 1, 0, 23, 59, 59);
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
      AppPageRoute(
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
      AppPageRoute(builder: (_) => const TransactionCategoryManagerScreen()),
    );
    if (!mounted) return;
    await _refreshData();
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    final service = context.read<TransactionService>();
    final confirm = await AppDialog.confirm(
      context: context,
      title: '删除记录',
      content: '确定要删除这条记录吗？',
      confirmLabel: '删除',
      destructive: true,
    );
    if (confirm == true) {
      await service.deleteTransaction(transaction.localId);
      if (!mounted) return;
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
        AppPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }

    setState(() => _loading = true);
    try {
      final categoriesSynced =
          await TransactionCategoryService(api, localCat).syncCategories();
      final transactionsSynced = categoriesSynced
          ? await TransactionService(api, localTx, categoryLocal: localCat)
              .syncTransactions()
          : false;
      await _refreshData();
      if (mounted) {
        if (categoriesSynced && transactionsSynced) {
          AppToast.success(context, '同步完成');
        } else {
          AppToast.error(context, '同步失败，请检查网络或登录状态');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, '同步失败: $e');
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
            final expenseCategories =
                _categories.where((c) => c.type == 'expense').toList();
            final incomeCategories =
                _categories.where((c) => c.type == 'income').toList();

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.pageHorizontal,
                  right: AppSpacing.pageHorizontal,
                  top: AppSpacing.xl,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xl,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('筛选与排序', style: AppTypography.h2Light()),
                          AppButton.secondary(
                            label: '重置',
                            width: null,
                            height: 36,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md),
                            onPressed: () => setSheetState(() {
                              _filterType = null;
                              _filterLocalCategoryId = null;
                              _sortBy = 'date_desc';
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('类型', style: AppTypography.captionMediumLight()),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          AppChip(
                            label: '全部',
                            selected: _filterType == null,
                            onSelected: (_) =>
                                setSheetState(() => _filterType = null),
                          ),
                          AppChip(
                            label: '支出',
                            selected: _filterType == 'expense',
                            onSelected: (_) => setSheetState(() {
                              _filterType = 'expense';
                              _filterLocalCategoryId = null;
                            }),
                          ),
                          AppChip(
                            label: '收入',
                            selected: _filterType == 'income',
                            onSelected: (_) => setSheetState(() {
                              _filterType = 'income';
                              _filterLocalCategoryId = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (expenseCategories.isNotEmpty) ...[
                        Text('支出', style: AppTypography.smallLight()),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: expenseCategories
                              .map((c) => AppChip(
                                    label: c.name,
                                    selected:
                                        _filterLocalCategoryId == c.localId,
                                    onSelected: (_) => setSheetState(() {
                                      _filterLocalCategoryId = c.localId;
                                      _filterType = 'expense';
                                    }),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (incomeCategories.isNotEmpty) ...[
                        Text('收入', style: AppTypography.smallLight()),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: AppSpacing.md,
                          children: incomeCategories
                              .map((c) => AppChip(
                                    label: c.name,
                                    selected:
                                        _filterLocalCategoryId == c.localId,
                                    onSelected: (_) => setSheetState(() {
                                      _filterLocalCategoryId = c.localId;
                                      _filterType = 'income';
                                    }),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      Text('排序', style: AppTypography.captionMediumLight()),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.md,
                        children: [
                          AppChip(
                            label: '时间倒序',
                            selected: _sortBy == 'date_desc',
                            onSelected: (_) =>
                                setSheetState(() => _sortBy = 'date_desc'),
                          ),
                          AppChip(
                            label: '时间正序',
                            selected: _sortBy == 'date_asc',
                            onSelected: (_) =>
                                setSheetState(() => _sortBy = 'date_asc'),
                          ),
                          AppChip(
                            label: '金额从高到低',
                            selected: _sortBy == 'amount_desc',
                            onSelected: (_) =>
                                setSheetState(() => _sortBy = 'amount_desc'),
                          ),
                          AppChip(
                            label: '金额从低到高',
                            selected: _sortBy == 'amount_asc',
                            onSelected: (_) =>
                                setSheetState(() => _sortBy = 'amount_asc'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppButton(
                        label: '确定',
                        onPressed: () {
                          Navigator.pop(ctx);
                          _refreshData();
                        },
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
        if (_view == _TransactionView.day) _buildActionsBar(),
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
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4DBE), Color(0xFF7B5CFA)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('结余', style: AppTypography.captionLight(color: Colors.white70)),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥ ${balance >= 0 ? '' : '-'}${_amountFormat.format(balance.abs())}',
              style: AppTypography.h1Light(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStat(
                  '收入', '+¥ ${_amountFormat.format(income)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat(
                  '支出', '-¥ ${_amountFormat.format(expense)}', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          _buildCompactViewSelector(),
          const SizedBox(width: AppSpacing.md),
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
      showSelectedIcon: false,
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
        AppIconButton(
          icon: Icons.chevron_left,
          iconSize: 20,
          onPressed: _previousRange,
        ),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              _rangeLabel,
              style: AppTypography.bodyMediumLight(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AppIconButton(
          icon: Icons.chevron_right,
          iconSize: 20,
          onPressed: _nextRange,
        ),
      ],
    );
  }

  Widget _buildActionsBar() {
    final hasFilter = _filterType != null ||
        _filterLocalCategoryId != null ||
        _sortBy != 'date_desc';
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.xs,
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: AppSpacing.sm,
        children: [
          AppChip(
            label: '筛选',
            icon: Icons.filter_list,
            selected: hasFilter,
            onSelected: (_) => _showFilterBottomSheet(),
          ),
          AppChip(
            label: '分类管理',
            icon: Icons.category,
            onSelected: (_) => _openCategoryManager(),
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
      final key =
          '${t.transactionDate.year}-${t.transactionDate.month.toString().padLeft(2, '0')}-${t.transactionDate.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
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
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B4DBE), Color(0xFF7B5CFA)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.light,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.captionLight(color: Colors.white70)),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥ ${isBalancePositive ? '' : '-'}${_amountFormat.format(balance.abs())}',
              style: AppTypography.h1Light(color: Colors.white),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeroStat(
                  '收入', '+¥ ${_amountFormat.format(income)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat(
                  '支出', '-¥ ${_amountFormat.format(expense)}', Colors.white),
              _buildHeroDivider(),
              _buildHeroStat('结余率',
                  '${(savingsRate * 100).toStringAsFixed(1)}%', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, Color color) {
    return Column(
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 110),
          child: Text(
            value,
            style: AppTypography.bodyMediumDark(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label,
            style:
                AppTypography.smallLight(color: color.withValues(alpha: 0.7))),
      ],
    );
  }

  Widget _buildHeroDivider() {
    return Container(width: 1, height: 24, color: Colors.white24);
  }

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
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        children: [
          _buildMonthSavingsRingCard(
              income: income, expense: expense, savingsRate: savingsRate),
          const SizedBox(height: AppSpacing.component),
          _buildExpenseCategoryCard(transactions),
          const SizedBox(height: AppSpacing.component),
          _buildMonthTrendCard(transactions),
          const SizedBox(height: AppSpacing.component),
          _buildMaxTransactionCards(transactions),
          const SizedBox(height: AppSpacing.component),
        ],
      ),
    );
  }

  Widget _buildMonthSavingsRingCard({
    required double income,
    required double expense,
    required double savingsRate,
  }) {
    final daysInMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
    final now = DateTime.now();
    final remainingDays =
        (_focusedDate.year == now.year && _focusedDate.month == now.month)
            ? daysInMonth - now.day
            : (_focusedDate.isAfter(DateTime(now.year, now.month))
                ? daysInMonth
                : 0);

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
                        color: AppColors.success,
                        value: savingsValue,
                        radius: 18,
                        showTitle: false,
                      ),
                      PieChartSectionData(
                        color: AppColors.border,
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
                      style: AppTypography.h3Light(),
                    ),
                    Text('结余率', style: AppTypography.smallLight()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('本月支出', style: AppTypography.captionLight()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '-¥ ${_amountFormat.format(expense)}',
                  style: AppTypography.h2Light(color: AppColors.error),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('剩余时间', style: AppTypography.captionLight()),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$remainingDays天',
                  style: AppTypography.bodyMediumLight(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    return AppCard(
      shadows: const [],
      child: child,
    );
  }

  Widget _buildExpenseCategoryCard(List<Transaction> transactions,
      {String title = '支出分类'}) {
    final ranking = _groupExpensesByCategory(transactions);
    if (ranking.isEmpty) {
      return _buildSectionCard(
        child: const SizedBox(height: 80, child: Center(child: Text('暂无支出数据'))),
      );
    }
    final total =
        ranking.fold<double>(0.0, (sum, e) => sum + (e['amount'] as double));
    final hasMore = ranking.length > 5;
    final displayItems =
        _showAllExpenseCategories ? ranking : ranking.take(5).toList();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.h3Light()),
              Text('总支出 -¥ ${_amountFormat.format(total)}',
                  style: AppTypography.smallLight()),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...displayItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final category = item['category'] as TransactionCategory?;
            final amount = item['amount'] as double;
            final color =
                _parseColor(category?.color) ?? _defaultCategoryColor(index);
            return _buildCategoryRankingRow(
              category: category,
              amount: amount,
              total: total,
              color: color,
            );
          }),
          if (hasMore)
            Center(
              child: AppButton.secondary(
                label: _showAllExpenseCategories ? '收起' : '更多',
                onPressed: () => setState(() =>
                    _showAllExpenseCategories = !_showAllExpenseCategories),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_parseIcon(category?.icon), color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category?.name ?? '未分类',
                        style: AppTypography.bodyLight()),
                    Text(
                      '-${_amountFormat.format(amount)}',
                      style:
                          AppTypography.bodyMediumLight(color: AppColors.error),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.border,
                    color: color,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthTrendCard(List<Transaction> transactions) {
    final daysInMonth =
        DateTime(_focusedDate.year, _focusedDate.month + 1, 0).day;
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
          Text('每日收支走势', style: AppTypography.h3Light()),
          const SizedBox(height: AppSpacing.lg),
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
                        return Text('¥${value.toInt()}',
                            style: AppTypography.smallLight());
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: (daysInMonth ~/ 5).toDouble(),
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt() + 1;
                        if (day < 1 || day > daysInMonth) {
                          return const SizedBox.shrink();
                        }
                        return Text('$day日', style: AppTypography.smallLight());
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _buildSmoothLine(dailyIncome, AppColors.success),
                  _buildSmoothLine(dailyExpense, AppColors.error),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryText,
                    tooltipRoundedRadius: AppRadius.lg,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final label = spot.barIndex == 0 ? '收入' : '支出';
                        final color = spot.bar.color ?? AppColors.secondaryText;
                        return LineTooltipItem(
                          '',
                          AppTypography.smallMediumLight(color: Colors.white),
                          children: [
                            TextSpan(
                              text: '● ',
                              style: TextStyle(
                                color: color,
                                fontSize: 8,
                                height: 1.2,
                              ),
                            ),
                            TextSpan(
                                text: '$label  ¥${spot.y.toStringAsFixed(0)}'),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('收入', AppColors.success),
              const SizedBox(width: AppSpacing.lg),
              _buildLegendItem('支出', AppColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMaxTransactionCards(List<Transaction> transactions) {
    final incomeTransactions =
        transactions.where((t) => t.type == 'income').toList();
    final expenseTransactions =
        transactions.where((t) => t.type == 'expense').toList();
    incomeTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    expenseTransactions.sort((a, b) => b.amount.compareTo(a.amount));
    final maxIncome =
        incomeTransactions.isNotEmpty ? incomeTransactions.first : null;
    final maxExpense =
        expenseTransactions.isNotEmpty ? expenseTransactions.first : null;

    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.pageHorizontal),
      child: Row(
        children: [
          if (maxIncome != null)
            Expanded(
                child: _buildMaxTransactionCard(
                    '最大单笔收入', maxIncome, AppColors.success)),
          if (maxIncome != null && maxExpense != null)
            const SizedBox(width: AppSpacing.md),
          if (maxExpense != null)
            Expanded(
                child: _buildMaxTransactionCard(
                    '最大单笔支出', maxExpense, AppColors.error)),
        ],
      ),
    );
  }

  Widget _buildMaxTransactionCard(
      String title, Transaction t, Color amountColor) {
    final category = _getCategory(t.localCategoryId);
    final catColor = _parseColor(category?.color) ?? AppColors.secondaryText;

    return AppCard(
      shadows: const [],
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.smallLight()),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(_parseIcon(category?.icon),
                      color: catColor, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ?? (t.type == 'expense' ? '支出' : '收入'),
                        style: AppTypography.bodyMediumLight(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        DateFormat('M月d日', 'zh_CN').format(t.transactionDate),
                        style: AppTypography.smallLight(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              '${t.type == 'expense' ? '-' : '+'}¥ ${_amountFormat.format(t.amount)}',
              style: AppTypography.h3Light(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }

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
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        children: [
          _buildYearOverviewCard(
              monthCount: monthCount,
              avgExpense: avgExpense,
              avgBalance: avgBalance),
          const SizedBox(height: AppSpacing.component),
          _buildYearMonthListCard(transactions),
          const SizedBox(height: AppSpacing.component),
          _buildExpenseCategoryCard(transactions, title: '年度支出分类'),
          const SizedBox(height: AppSpacing.component),
          _buildIncomeCategoryCard(transactions),
          const SizedBox(height: AppSpacing.component),
          _buildYearTrendCard(transactions),
          const SizedBox(height: AppSpacing.component),
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
          Text('年度概览', style: AppTypography.h3Light()),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStatItem('有记录月份', '$monthCount个月'),
              ),
              Expanded(
                child: _buildOverviewStatItem(
                    '月均支出', '-¥ ${_amountFormat.format(avgExpense)}'),
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
        Text(label, style: AppTypography.smallLight()),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTypography.bodyMediumLight(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildYearMonthListCard(List<Transaction> transactions) {
    final monthlyData = List<Map<String, double>>.generate(
        12, (_) => {'income': 0.0, 'expense': 0.0});
    for (final t in transactions) {
      final month = t.transactionDate.month - 1;
      if (t.type == 'income') {
        monthlyData[month]['income'] =
            (monthlyData[month]['income'] ?? 0.0) + t.amount;
      } else {
        monthlyData[month]['expense'] =
            (monthlyData[month]['expense'] ?? 0.0) + t.amount;
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
          Text('各月概览', style: AppTypography.h3Light()),
          const SizedBox(height: AppSpacing.lg),
          ...List.generate(12, (index) {
            final income = monthlyData[index]['income'] ?? 0.0;
            final expense = monthlyData[index]['expense'] ?? 0.0;
            final balance = income - expense;
            final hasData = income > 0 || expense > 0;
            final ratio = maxAbs > 0 && hasData ? balance.abs() / maxAbs : 0.0;
            final isPositive = balance >= 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child:
                        Text('${index + 1}月', style: AppTypography.bodyLight()),
                  ),
                  if (hasData) ...[
                    Container(
                      height: 6,
                      width: 24 * ratio,
                      decoration: BoxDecoration(
                        color: isPositive ? AppColors.success : AppColors.error,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ] else
                    const SizedBox(width: 32),
                  Expanded(
                    child: Text(
                      hasData
                          ? '${isPositive ? '+' : '-'}¥ ${_amountFormat.format(balance.abs())}'
                          : '--',
                      style: AppTypography.bodyMediumLight(
                        color: hasData
                            ? (isPositive ? AppColors.success : AppColors.error)
                            : AppColors.tertiaryText,
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
    final total =
        ranking.fold<double>(0.0, (sum, e) => sum + (e['amount'] as double));

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('收入来源', style: AppTypography.h3Light()),
              Text('总收入 +¥ ${_amountFormat.format(total)}',
                  style: AppTypography.smallLight()),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          ...ranking.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final category = item['category'] as TransactionCategory?;
            final amount = item['amount'] as double;
            final color =
                _parseColor(category?.color) ?? _defaultCategoryColor(index);
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
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_parseIcon(category?.icon), color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(category?.name ?? '未分类',
                        style: AppTypography.bodyLight()),
                    Text(
                      '+¥ ${_amountFormat.format(amount)}',
                      style: AppTypography.bodyMediumLight(
                          color: AppColors.success),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: percentage,
                    backgroundColor: AppColors.border,
                    color: color,
                    minHeight: 5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearTrendCard(List<Transaction> transactions) {
    final monthlyData = List<Map<String, double>>.generate(
        12, (_) => {'income': 0.0, 'expense': 0.0});
    for (final t in transactions) {
      final month = t.transactionDate.month - 1;
      if (t.type == 'income') {
        monthlyData[month]['income'] =
            (monthlyData[month]['income'] ?? 0.0) + t.amount;
      } else {
        monthlyData[month]['expense'] =
            (monthlyData[month]['expense'] ?? 0.0) + t.amount;
      }
    }

    final maxY = _findMax([
      ...monthlyData.expand((e) => [e['income']!, e['expense']!])
    ]);
    if (maxY <= 0) return const SizedBox.shrink();

    return _buildSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('全年收支走势', style: AppTypography.h3Light()),
          const SizedBox(height: AppSpacing.lg),
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
                        if (month < 1 || month > 12) {
                          return const SizedBox.shrink();
                        }
                        return Text('$month月',
                            style: AppTypography.smallLight());
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (index) {
                  final income = monthlyData[index]['income'] ?? 0.0;
                  final expense = monthlyData[index]['expense'] ?? 0.0;
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 1,
                    barRods: [
                      BarChartRodData(
                          toY: income,
                          color: AppColors.success,
                          width: 4,
                          borderRadius: BorderRadius.circular(AppRadius.xs)),
                      BarChartRodData(
                          toY: expense,
                          color: AppColors.error,
                          width: 4,
                          borderRadius: BorderRadius.circular(AppRadius.xs)),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.primaryText,
                    tooltipRoundedRadius: AppRadius.lg,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? '收入' : '支出';
                      final color = rod.color ?? AppColors.secondaryText;
                      return BarTooltipItem(
                        '',
                        AppTypography.smallMediumLight(color: Colors.white),
                        children: [
                          TextSpan(
                            text: '● ',
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              height: 1.2,
                            ),
                          ),
                          TextSpan(
                              text: '$label  ¥${rod.toY.toStringAsFixed(0)}'),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('收入', AppColors.success),
              const SizedBox(width: AppSpacing.lg),
              _buildLegendItem('支出', AppColors.error),
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

  List<Map<String, dynamic>> _groupIncomesByCategory(
      List<Transaction> transactions) {
    final map = <String, Map<String, dynamic>>{};
    for (final t in transactions) {
      if (t.type != 'income') continue;
      final category = _getCategory(t.localCategoryId);
      final key = category?.localId ?? '_uncategorized';
      final entry = map.putIfAbsent(
          key,
          () => {
                'category': category,
                'name': category?.name ?? '未分类',
                'amount': 0.0,
              });
      entry['amount'] = (entry['amount'] as double) + t.amount;
    }
    final result = map.values.toList();
    result.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
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
      spots: List.generate(
          data.length, (index) => FlSpot(index.toDouble(), data[index])),
      color: color,
      barWidth: 2,
      isCurved: true,
      dotData: const FlDotData(show: false),
      belowBarData:
          BarAreaData(show: true, color: color.withValues(alpha: 0.1)),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.smallMediumLight(color: color)),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _groupExpensesByCategory(
      List<Transaction> transactions) {
    final map = <String, Map<String, dynamic>>{};
    for (final t in transactions) {
      if (t.type != 'expense') continue;
      final category = _getCategory(t.localCategoryId);
      final key = category?.localId ?? '_uncategorized';
      final entry = map.putIfAbsent(
          key,
          () => {
                'category': category,
                'name': category?.name ?? '未分类',
                'amount': 0.0,
              });
      entry['amount'] = (entry['amount'] as double) + t.amount;
    }
    final result = map.values.toList();
    result.sort(
        (a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
    return result;
  }

  Color _defaultCategoryColor(int index) {
    final colors = [
      AppColors.error,
      AppColors.warning,
      const Color(0xFFFBBF24),
      AppColors.success,
      AppColors.brand,
      const Color(0xFF3B82F6),
      const Color(0xFF8B5CF6),
      const Color(0xFFEC4899),
      const Color(0xFF14B8A6),
      const Color(0xFF8D6E63),
    ];
    return colors[index % colors.length];
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.receipt_long,
      title: '暂无记录',
    );
  }

  Widget _buildDayHeader(DateTime date, List<Transaction> items) {
    final dailyIncome = items
        .where((t) => t.type == 'income')
        .fold(0.0, (sum, t) => sum + t.amount);
    final dailyExpense = items
        .where((t) => t.type == 'expense')
        .fold(0.0, (sum, t) => sum + t.amount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatDayHeader(date),
              style: AppTypography.captionMediumLight(),
            ),
          ),
          if (dailyIncome > 0 || dailyExpense > 0)
            Flexible(
              child: _buildDaySummaryLabels(dailyIncome, dailyExpense),
            ),
        ],
      ),
    );
  }

  Widget _buildDaySummaryLabels(double income, double expense) {
    final children = <InlineSpan>[];
    if (income > 0) {
      children.addAll([
        TextSpan(
            text: '收 ',
            style: AppTypography.smallLight(color: AppColors.success)),
        TextSpan(
          text: '+${_summaryFormat.format(income)}',
          style: AppTypography.smallMediumLight(color: AppColors.success),
        ),
      ]);
    }
    if (income > 0 && expense > 0) {
      children.add(const TextSpan(text: '  '));
    }
    if (expense > 0) {
      children.addAll([
        TextSpan(
            text: '支 ',
            style: AppTypography.smallLight(color: AppColors.error)),
        TextSpan(
          text: '-${_summaryFormat.format(expense)}',
          style: AppTypography.smallMediumLight(color: AppColors.error),
        ),
      ]);
    }
    return Text.rich(
      TextSpan(children: children),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
    );
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
    final amountColor = isExpense ? AppColors.error : AppColors.success;
    final catColor = _parseColor(category?.color) ?? AppColors.secondaryText;
    final iconData = _parseIcon(category?.icon);

    return InkWell(
      onTap: () => openEditor(t),
      onLongPress: () => _deleteTransaction(t),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pageHorizontal,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: catColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(iconData, color: catColor, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category?.name ?? (isExpense ? '支出' : '收入'),
                    style: AppTypography.bodyMediumLight(),
                  ),
                  if (t.note != null && t.note!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      t.note!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.smallLight(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isExpense ? '-' : '+'}${_amountFormat.format(t.amount)}',
                    style: AppTypography.h3Light(color: amountColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                  if (t.syncStatus != 'synced')
                    const Icon(Icons.cloud_off,
                        size: 12, color: AppColors.tertiaryText),
                ],
              ),
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
}
