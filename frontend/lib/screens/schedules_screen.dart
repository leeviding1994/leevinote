import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/schedule.dart';
import 'package:leevinote/services/schedule_service.dart';
import 'package:leevinote/services/holiday_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'package:leevinote/screens/login_screen.dart';

enum ScheduleViewMode { day, week, month, year }

const _viewModeLabels = {
  ScheduleViewMode.day: '日',
  ScheduleViewMode.week: '周',
  ScheduleViewMode.month: '月',
  ScheduleViewMode.year: '年',
};

const Map<int, String> _weekdayNames = {
  DateTime.monday: '一',
  DateTime.tuesday: '二',
  DateTime.wednesday: '三',
  DateTime.thursday: '四',
  DateTime.friday: '五',
  DateTime.saturday: '六',
  DateTime.sunday: '日',
};

const _scheduleColors = [
  Color(0xFF6366F1), // 蓝紫
  Color(0xFF8B5CF6), // 紫
  Color(0xFF3B82F6), // 蓝
  Color(0xFF10B981), // 绿
  Color(0xFFF59E0B), // 琥珀
  Color(0xFFEC4899), // 粉
  Color(0xFF06B6D4), // 青
  Color(0xFFEF4444), // 红
  Color(0xFF14B8A6), //  teal
  Color(0xFFF97316), // 橙
  Color(0xFF84CC16), // 黄绿
  Color(0xFF64748B), // 灰蓝
];

Color _getScheduleColor(int index) {
  return _scheduleColors[index % _scheduleColors.length];
}

Widget _todayBadge(BuildContext context) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      borderRadius: BorderRadius.circular(AppRadius.xs),
    ),
    child: Text(
      '今',
      style: AppTypography.smallMediumLight(color: Colors.white),
    ),
  );
}

String _getLunarDayShort(DateTime date) {
  try {
    final solar = Solar.fromYmd(date.year, date.month, date.day);
    final lunar = solar.getLunar();
    final day = lunar.getDayInChinese();
    // 如果是初一，显示月份
    if (day == '初一') {
      return '${lunar.getMonthInChinese()}月';
    }
    return day;
  } catch (_) {
    return '';
  }
}

String _getLunarFull(DateTime date) {
  try {
    final solar = Solar.fromYmd(date.year, date.month, date.day);
    final lunar = solar.getLunar();
    return '${lunar.getMonthInChinese()}月${lunar.getDayInChinese()}';
  } catch (_) {
    return '';
  }
}

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => SchedulesScreenState();
}

class SchedulesScreenState extends State<SchedulesScreen> {
  ScheduleViewMode _viewMode = ScheduleViewMode.day;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  DateTime? _searchStartDate;
  DateTime? _searchEndDate;
  List<Schedule> _searchResults = [];

  bool get isSearching => _isSearching;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleService>().load();
      context.read<HolidayService>().fetchHolidays(DateTime.now().year);
    });
  }

  Future<void> sync() async {
    final scheduleService = context.read<ScheduleService>();
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;
    final success = await scheduleService.sync();
    if (mounted) {
      if (success) {
        AppToast.success(context, '日程同步完成');
      } else {
        AppToast.error(context, '同步失败');
      }
    }
  }

  void toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchStartDate = null;
        _searchEndDate = null;
        _searchResults = [];
      }
    });
  }

  void resetToDayView() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _searchResults = [];
      _searchStartDate = null;
      _searchEndDate = null;
      _viewMode = ScheduleViewMode.day;
      _calendarFormat = CalendarFormat.week;
      _selectedDay = DateTime.now();
      _focusedDay = DateTime.now();
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    final service = context.read<ScheduleService>();
    setState(() {
      _searchResults = service.searchSchedules(
        query: query.isEmpty ? null : query,
        startDate: _searchStartDate,
        endDate: _searchEndDate,
      );
      _searchResults.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  double _calculateRowHeight(ScheduleService service) {
    final lastDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    double maxHeight = 70;
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(_focusedDay.year, _focusedDay.month, day);
      final events = service.getSchedulesForDate(date);
      // 54 = 日期区域(44) + 底部间距(2) + cell 内外边距(8)
      // 13 = 每个日程高度 (margin 1 + padding 2 + 内容 10)
      // 额外 +4 留安全边距
      final height = 58 + events.length * 13.0;
      if (height > maxHeight) maxHeight = height;
    }
    return maxHeight;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheduleService = context.watch<ScheduleService>();

    return Scaffold(
      body: Column(
        children: [
          if (!_isSearching) _buildViewModeSelector(),
          if (_isSearching) _buildSearchPanel(),
          Expanded(
            child: _isSearching
                ? _buildSearchResults()
                : _buildContent(scheduleService),
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.md,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<ScheduleViewMode>(
          segments: ScheduleViewMode.values.map((mode) {
            return ButtonSegment(
              value: mode,
              label: Text(_viewModeLabels[mode]!),
            );
          }).toList(),
          selected: {_viewMode},
          onSelectionChanged: (value) {
            setState(() {
              _viewMode = value.first;
              if (_viewMode == ScheduleViewMode.month) {
                _calendarFormat = CalendarFormat.month;
              } else if (_viewMode == ScheduleViewMode.week ||
                  _viewMode == ScheduleViewMode.day) {
                _calendarFormat = CalendarFormat.week;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildContent(ScheduleService service) {
    if (service.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_viewMode) {
      case ScheduleViewMode.month:
        return _buildCalendarWithEvents(service);
      case ScheduleViewMode.week:
        return _buildWeekView(service);
      case ScheduleViewMode.day:
        return _buildDayView(service);
      case ScheduleViewMode.year:
        return _buildYearView(service);
    }
  }

  Widget _buildCalendarWithEvents(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();

    return SingleChildScrollView(
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 365)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _calendarFormat,
        availableCalendarFormats: _viewMode == ScheduleViewMode.month
            ? const {CalendarFormat.month: '月'}
            : const {CalendarFormat.week: '周'},
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
          _showDayEventsBubble(context, selectedDay, service);
        },
        onFormatChanged: (format) {
          setState(() => _calendarFormat = format);
        },
        onPageChanged: (focusedDay) {
          final year = focusedDay.year;
          if (year != _focusedDay.year) {
            context.read<HolidayService>().fetchHolidays(year);
          }
          _focusedDay = focusedDay;
        },
        eventLoader: (day) => service.getSchedulesForDate(day),
        calendarBuilders: _buildCalendarBuilders(holidayService, service),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        daysOfWeekHeight: 28,
        rowHeight: _calculateRowHeight(service),
        calendarStyle: CalendarStyle(
          weekendTextStyle: TextStyle(color: Colors.red.shade400),
          cellPadding: EdgeInsets.zero,
          cellMargin: const EdgeInsets.all(2),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildDayView(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    final selectedDateEvents = service.getSchedulesForDate(_selectedDay);

    return Column(
      children: [
        _buildDayHeader(holidayService),
        const Divider(height: 1),
        Expanded(child: _buildDayTimeline(selectedDateEvents)),
      ],
    );
  }

  Widget _buildDayHeader(HolidayService holidayService) {
    final isHoli = holidayService.isHoliday(_selectedDay);
    final holiday = holidayService.getHoliday(_selectedDay);
    final isWeekend = _selectedDay.weekday == DateTime.saturday ||
        _selectedDay.weekday == DateTime.sunday;
    final lunarFull = _getLunarFull(_selectedDay);
    final isToday = isSameDay(_selectedDay, DateTime.now());

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.lg,
        horizontal: AppSpacing.pageHorizontal,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_selectedDay.month}月${_selectedDay.day}日',
                    style: AppTypography.h2Light(),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: AppSpacing.sm),
                    _todayBadge(context),
                  ],
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '周${_weekdayNames[_selectedDay.weekday] ?? ''}',
                    style: AppTypography.bodyLight(
                      color: isWeekend || isHoli
                          ? AppColors.error
                          : AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    lunarFull,
                    style: AppTypography.captionLight(),
                  ),
                ],
              ),
              if (isHoli && holiday != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      holiday.name,
                      style: AppTypography.smallMediumLight(
                          color: AppColors.error),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          AppIconButton(
            icon: Icons.chevron_left,
            onPressed: () {
              setState(() {
                _selectedDay = _selectedDay.subtract(const Duration(days: 1));
              });
            },
          ),
          AppIconButton(
            icon: Icons.chevron_right,
            onPressed: () {
              setState(() {
                _selectedDay = _selectedDay.add(const Duration(days: 1));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayTimeline(List<Schedule> events) {
    if (events.isEmpty) {
      return const AppEmptyState(
        icon: Icons.event_busy,
        title: '暂无日程',
      );
    }

    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pageHorizontal,
        vertical: AppSpacing.md,
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final colorIndex = event.localId.hashCode.abs();
        final color = _getScheduleColor(colorIndex);
        final startStr = DateFormat('HH:mm').format(event.startTime);
        final endStr = DateFormat('HH:mm').format(event.endTime);
        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
            child: GestureDetector(
              onTap: () => _showEditScheduleDialog(context, event),
              child: AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 4,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Checkbox(
                      value: event.completed,
                      onChanged: (v) {
                        context
                            .read<ScheduleService>()
                            .toggleCompleted(event.localId);
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            event.title,
                            style: AppTypography.bodyMediumLight(
                              color: event.completed
                                  ? AppColors.tertiaryText
                                  : null,
                              decoration: event.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isAllDay ? '全天' : '$startStr - $endStr',
                            style: AppTypography.captionLight(
                              color: event.completed
                                  ? AppColors.tertiaryText
                                  : null,
                              decoration: event.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          if (event.location != null &&
                              event.location!.isNotEmpty)
                            Text(
                              event.location!,
                              style: AppTypography.smallLight(
                                color: event.completed
                                    ? AppColors.tertiaryText
                                    : null,
                                decoration: event.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ),
                    AppIconButton(
                      icon: Icons.delete_outline,
                      iconSize: 20,
                      onPressed: () => _deleteSchedule(event),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildYearView(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    final currentYear = _focusedDay.year;
    final now = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(currentYear - 1);
                  });
                  context.read<HolidayService>().fetchHolidays(currentYear - 1);
                },
              ),
              Text(
                '$currentYear年',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _focusedDay = DateTime(currentYear + 1);
                  });
                  context.read<HolidayService>().fetchHolidays(currentYear + 1);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: 12,
            itemBuilder: (context, index) {
              final month = index + 1;
              final daysInMonth = DateTime(currentYear, month + 1, 0).day;
              final firstWeekday = DateTime(currentYear, month, 1).weekday;
              final hasEvents = service.schedules.any((s) =>
                  s.startTime.year == currentYear &&
                  s.startTime.month == month);

              return InkWell(
                onTap: () {
                  setState(() {
                    _focusedDay = DateTime(currentYear, month, 1);
                    _selectedDay = DateTime(currentYear, month, 1);
                    _viewMode = ScheduleViewMode.month;
                    _calendarFormat = CalendarFormat.month;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$month月',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: _buildMiniMonthGrid(
                          currentYear,
                          month,
                          daysInMonth,
                          firstWeekday,
                          holidayService,
                          now,
                          service,
                        ),
                      ),
                      if (hasEvents)
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniMonthGrid(
    int year,
    int month,
    int daysInMonth,
    int firstWeekday,
    HolidayService holidayService,
    DateTime now,
    ScheduleService service,
  ) {
    final today = now.year == year && now.month == month ? now.day : -1;
    final cells = <Widget>[];
    for (int i = 1; i < firstWeekday; i++) {
      cells.add(const SizedBox());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(year, month, day);
      final isHoli = holidayService.isHoliday(date);
      final daySchedules = service.getSchedulesForDate(date);
      final hasEvent = daySchedules.isNotEmpty;
      final isToday = day == today;
      final allCompleted = hasEvent && daySchedules.every((s) => s.completed);

      cells.add(
        InkWell(
          onTap: () {
            setState(() {
              _focusedDay = date;
              _selectedDay = date;
              _viewMode = ScheduleViewMode.day;
            });
          },
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isToday)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                if (hasEvent && !isToday)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: allCompleted
                          ? Colors.green.withValues(alpha: 0.15)
                          : Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: allCompleted ? Colors.green : Colors.red,
                        width: 1,
                      ),
                    ),
                  ),
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 9,
                    color: isToday
                        ? Colors.white
                        : isHoli
                            ? Colors.red.shade400
                            : null,
                    fontWeight: hasEvent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Fill remaining cells to make 6 rows (42 cells)
    while (cells.length < 42) {
      cells.add(const SizedBox());
    }

    // Build 6 rows of 7 columns using Expanded to avoid overflow
    final rows = <Widget>[];
    for (int r = 0; r < 6; r++) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < 7; c++) {
        rowChildren.add(Expanded(child: cells[r * 7 + c]));
      }
      rows.add(Expanded(
        child: Row(children: rowChildren),
      ));
    }
    return Column(children: rows);
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        0,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            controller: _searchController,
            hintText: '搜索日程名称...',
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: AppIconButton(
              icon: Icons.clear,
              iconSize: 18,
              onPressed: () {
                _searchController.clear();
                _performSearch();
              },
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  shadows: const [],
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _searchStartDate ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 5)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => _searchStartDate = date);
                      _performSearch();
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('开始日期', style: AppTypography.smallLight()),
                            Text(
                              _searchStartDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(_searchStartDate!)
                                  : '不限',
                              style: AppTypography.bodyMediumLight(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: AppCard(
                  shadows: const [],
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _searchEndDate ?? DateTime.now(),
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 5)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => _searchEndDate = date);
                      _performSearch();
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('结束日期', style: AppTypography.smallLight()),
                            Text(
                              _searchEndDate != null
                                  ? DateFormat('yyyy-MM-dd')
                                      .format(_searchEndDate!)
                                  : '不限',
                              style: AppTypography.bodyMediumLight(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: '搜索',
            onPressed: _performSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off,
        title: '未找到日程',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final event = _searchResults[index];
        final startStr = DateFormat('MM-dd HH:mm').format(event.startTime);
        final endStr = DateFormat('MM-dd HH:mm').format(event.endTime);
        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
            child: AppCard(
              onTap: () => _showEditScheduleDialog(context, event),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      isAllDay ? Icons.event : Icons.access_time,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title,
                            style: AppTypography.bodyMediumLight()),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          isAllDay
                              ? '${DateFormat('yyyy-MM-dd').format(event.startTime)} 全天'
                              : '$startStr - $endStr',
                          style: AppTypography.smallLight(),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: Icons.delete_outline,
                    onPressed: () => _deleteSchedule(event),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showDayEventsBubble(
    BuildContext context,
    DateTime day,
    ScheduleService service,
  ) {
    final holidayService = context.read<HolidayService>();
    final isHoli = holidayService.isHoliday(day);
    final holiday = holidayService.getHoliday(day);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final lunarFull = _getLunarFull(day);
    final isToday = isSameDay(day, DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final events = service.getSchedulesForDate(day);
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            AppSpacing.lg,
                            AppSpacing.lg,
                            AppSpacing.lg,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppRadius.lg),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '${day.month}月${day.day}日',
                                          style: AppTypography.h2Light(),
                                        ),
                                        if (isToday) ...[
                                          const SizedBox(width: AppSpacing.sm),
                                          _todayBadge(context),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Row(
                                      children: [
                                        Text(
                                          '周${_weekdayNames[day.weekday] ?? ''}',
                                          style: AppTypography.captionLight(
                                            color: isWeekend || isHoli
                                                ? AppColors.error
                                                : AppColors.secondaryText,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Text(
                                          lunarFull,
                                          style: AppTypography.smallLight(),
                                        ),
                                        if (isHoli && holiday != null) ...[
                                          const SizedBox(width: AppSpacing.md),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.md,
                                              vertical: AppSpacing.xs,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      AppRadius.xs),
                                            ),
                                            child: Text(
                                              holiday.name,
                                              style: AppTypography
                                                  .smallMediumLight(
                                                      color: AppColors.error),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              AppIconButton(
                                icon: Icons.close,
                                onPressed: () => Navigator.pop(ctx),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (events.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.xxl),
                            child: Center(
                              child: Text(
                                '暂无日程',
                                style: AppTypography.bodyLight(
                                    color: AppColors.tertiaryText),
                              ),
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md,
                                AppSpacing.md,
                                AppSpacing.md,
                                72,
                              ),
                              shrinkWrap: true,
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final startStr =
                                    DateFormat('HH:mm').format(event.startTime);
                                final endStr =
                                    DateFormat('HH:mm').format(event.endTime);
                                final isAllDay = event.startTime.hour == 0 &&
                                    event.endTime.hour == 23;

                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: AppSpacing.listItemGap),
                                  child: AppCard(
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: event.completed,
                                          onChanged: (v) {
                                            context
                                                .read<ScheduleService>()
                                                .toggleCompleted(event.localId);
                                            setDialogState(() {});
                                          },
                                          materialTapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Expanded(
                                          child: InkWell(
                                            onTap: () {
                                              Navigator.pop(ctx);
                                              _showEditScheduleDialog(
                                                  context, event);
                                            },
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  event.title,
                                                  style: AppTypography
                                                      .bodyMediumLight(
                                                    color: event.completed
                                                        ? AppColors.tertiaryText
                                                        : null,
                                                    decoration: event.completed
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    height: AppSpacing.xs),
                                                Text(
                                                  isAllDay
                                                      ? '全天'
                                                      : event.location !=
                                                                  null &&
                                                              event.location!
                                                                  .isNotEmpty
                                                          ? '$startStr - $endStr · ${event.location}'
                                                          : '$startStr - $endStr',
                                                  style:
                                                      AppTypography.smallLight(
                                                    color: event.completed
                                                        ? AppColors.tertiaryText
                                                        : null,
                                                    decoration: event.completed
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        AppIconButton(
                                          icon: Icons.delete_outline,
                                          onPressed: () {
                                            _deleteSchedule(event);
                                            Navigator.pop(ctx);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    Positioned(
                      right: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                      child: AppFAB(
                        heroTag: 'day_events_fab_${day.toIso8601String()}',
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() => _selectedDay = day);
                          _showAddScheduleDialog(context);
                        },
                        icon: Icons.add,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWeekView(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    final weekStart = _selectedDay.subtract(
      Duration(days: (_selectedDay.weekday - DateTime.monday) % 7),
    );
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconButton(
                icon: Icons.chevron_left,
                onPressed: () {
                  setState(() {
                    _selectedDay =
                        _selectedDay.subtract(const Duration(days: 7));
                  });
                },
              ),
              Text(
                '${DateFormat('M月d日').format(days.first)} - ${DateFormat('M月d日').format(days.last)}',
                style: AppTypography.bodyMediumLight(),
              ),
              AppIconButton(
                icon: Icons.chevron_right,
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.add(const Duration(days: 7));
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: 7,
            itemBuilder: (context, index) {
              final day = days[index];
              return _buildWeekDayRow(day, service, holidayService);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWeekDayRow(
    DateTime day,
    ScheduleService service,
    HolidayService holidayService,
  ) {
    final events = service.getSchedulesForDate(day);
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isHoli = holidayService.isHoliday(day);
    final holiday = holidayService.isHolidayNameDay(day)
        ? holidayService.getHoliday(day)
        : null;
    final isToday = isSameDay(day, DateTime.now());

    // 全天日程
    final allDayEvents = events
        .where((e) => e.startTime.hour == 0 && e.endTime.hour == 23)
        .toList();
    // 普通日程
    final timedEvents = events
        .where((e) => !(e.startTime.hour == 0 && e.endTime.hour == 23))
        .toList();

    // 按行分配重叠日程
    final List<List<Schedule>> rows = [];
    for (final e in timedEvents) {
      bool placed = false;
      for (final row in rows) {
        final last = row.last;
        if (e.startTime.isAfter(last.endTime) ||
            e.startTime.isAtSameMomentAs(last.endTime)) {
          row.add(e);
          placed = true;
          break;
        }
      }
      if (!placed) rows.add([e]);
    }

    const double rowHeight = 22;
    const double rowGap = 3;
    final double allDayHeight = allDayEvents.isNotEmpty ? 24.0 : 0.0;
    final double allDayGap =
        allDayEvents.isNotEmpty && rows.isNotEmpty ? 4.0 : 0.0;
    final double timelineHeight =
        rows.isEmpty ? 0 : rows.length * rowHeight + (rows.length - 1) * rowGap;
    final double contentHeight = allDayHeight + allDayGap + timelineHeight;

    return InkWell(
      onTap: () => _showDayEventsBubble(context, day, service),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: isToday
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              )
                            : events.isNotEmpty
                                ? BoxDecoration(
                                    color: events.every((s) => s.completed)
                                        ? AppColors.success
                                            .withValues(alpha: 0.12)
                                        : AppColors.error
                                            .withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: events.every((s) => s.completed)
                                          ? AppColors.success
                                          : AppColors.error,
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                        child: Text(
                          '${day.day}',
                          style: AppTypography.h2Light(
                            color: isToday
                                ? Colors.white
                                : events.isNotEmpty
                                    ? (events.every((s) => s.completed)
                                        ? AppColors.success
                                        : AppColors.error)
                                    : isWeekend || isHoli
                                        ? AppColors.error
                                        : null,
                          ),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: AppSpacing.xs),
                        _todayBadge(context),
                      ],
                    ],
                  ),
                  Text(
                    '周${_weekdayNames[day.weekday] ?? ''}',
                    style: AppTypography.smallLight(
                      color: isWeekend || isHoli
                          ? AppColors.error
                          : AppColors.secondaryText,
                    ),
                  ),
                  Text(
                    holiday?.name ?? _getLunarDayShort(day),
                    style: AppTypography.smallLight(
                      color: isWeekend || isHoli
                          ? AppColors.error.withValues(alpha: 0.7)
                          : AppColors.tertiaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 时间刻度
                  SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        for (int h = 0; h <= 24; h += 6)
                          Expanded(
                            child: Text(
                              h == 24 ? '24' : '$h',
                              style: AppTypography.smallLight(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 时间轴区域
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final timelineWidth = constraints.maxWidth;
                      if (allDayEvents.isEmpty && rows.isEmpty) {
                        return Container(
                          height: 38,
                          alignment: Alignment.center,
                          child: Text(
                            '无日程',
                            style: AppTypography.smallLight(),
                          ),
                        );
                      }

                      return SizedBox(
                        height: contentHeight,
                        child: Stack(
                          children: [
                            // 全天日程
                            if (allDayEvents.isNotEmpty)
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: Row(
                                  children: allDayEvents.map((e) {
                                    final colorIndex = e.localId.hashCode.abs();
                                    final color = _getScheduleColor(colorIndex);
                                    return Expanded(
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 2),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          e.title,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: color,
                                            overflow: TextOverflow.ellipsis,
                                            decoration: e.completed
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            // 各行列的普通日程
                            for (int rowIndex = 0;
                                rowIndex < rows.length;
                                rowIndex++)
                              Positioned(
                                top: allDayHeight +
                                    allDayGap +
                                    rowIndex * (rowHeight + rowGap),
                                left: 0,
                                right: 0,
                                child: SizedBox(
                                  height: rowHeight,
                                  child: Stack(
                                    children: rows[rowIndex].map((e) {
                                      final startMin = e.startTime.hour * 60 +
                                          e.startTime.minute;
                                      final endMin = e.endTime.hour * 60 +
                                          e.endTime.minute;
                                      final left =
                                          (startMin / 1440.0) * timelineWidth;
                                      final width =
                                          ((endMin - startMin) / 1440.0) *
                                              timelineWidth;
                                      final colorIndex =
                                          e.localId.hashCode.abs();
                                      final color =
                                          _getScheduleColor(colorIndex);
                                      return Positioned(
                                        left: left,
                                        width: width.clamp(
                                            40, timelineWidth - left),
                                        child: GestureDetector(
                                          onTap: () => _showEditScheduleDialog(
                                              context, e),
                                          child: Container(
                                            height: rowHeight,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withValues(
                                                      alpha: 0.3),
                                                  blurRadius: 2,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    e.title,
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Colors.white,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      decoration: e.completed
                                                          ? TextDecoration
                                                              .lineThrough
                                                          : null,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('HH:mm')
                                                      .format(e.startTime),
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.white
                                                        .withValues(
                                                            alpha: 0.85),
                                                    decoration: e.completed
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DateTime date,
    ScheduleService service,
    HolidayService holidayService, {
    required bool isSelected,
    required bool isToday,
    required bool isWeekend,
    required bool isHoliday,
    required bool isOutside,
    required bool isDisabled,
  }) {
    final events = service.getSchedulesForDate(date);
    final allCompleted = events.isNotEmpty && events.every((s) => s.completed);
    final textColor = isDisabled
        ? AppColors.tertiaryText
        : isSelected
            ? Colors.white
            : isOutside
                ? AppColors.tertiaryText
                : isWeekend || isHoliday
                    ? AppColors.error
                    : null;
    final subTextColor = isDisabled
        ? AppColors.tertiaryText
        : isOutside
            ? AppColors.tertiaryText
            : isHoliday
                ? AppColors.error
                : isWeekend
                    ? AppColors.error
                    : AppColors.secondaryText;
    final lunarDay = _getLunarDayShort(date);
    final holiday = holidayService.isHolidayNameDay(date)
        ? holidayService.getHoliday(date)
        : null;
    final subText = holiday?.name ?? lunarDay;

    return Container(
      margin: const EdgeInsets.all(2),
      child: Stack(
        children: [
          // 左上角日期与农历
          Positioned(
            top: 2,
            left: 2,
            right: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRect(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: isSelected
                            ? BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              )
                            : isToday && events.isEmpty
                                ? BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    shape: BoxShape.circle,
                                  )
                                : events.isNotEmpty
                                    ? BoxDecoration(
                                        color: allCompleted
                                            ? AppColors.success
                                                .withValues(alpha: 0.12)
                                            : AppColors.error
                                                .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: allCompleted
                                              ? AppColors.success
                                              : AppColors.error,
                                          width: 1,
                                        ),
                                      )
                                    : null,
                        child: Text(
                          '${date.day}',
                          style: AppTypography.bodyMediumLight(
                            color: isToday && events.isNotEmpty
                                ? (allCompleted
                                    ? AppColors.success
                                    : AppColors.error)
                                : textColor,
                          ),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 2),
                        _todayBadge(context),
                      ],
                    ],
                  ),
                ),
                if (subText.isNotEmpty)
                  Text(
                    subText,
                    style: AppTypography.smallLight(color: subTextColor),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
              ],
            ),
          ),
          // 日程内容放在底部
          if (events.isNotEmpty)
            Positioned(
              left: 2,
              right: 2,
              bottom: 2,
              top: 44,
              child: ClipRect(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: events.map((e) {
                    final isAllDay =
                        e.startTime.hour == 0 && e.endTime.hour == 23;
                    final timeStr = isAllDay
                        ? '全天'
                        : '${DateFormat('HH:mm').format(e.startTime)}-${DateFormat('HH:mm').format(e.endTime)}';
                    final colorIndex = e.localId.hashCode.abs();
                    final color = _getScheduleColor(colorIndex);
                    return Container(
                      margin: const EdgeInsets.only(top: 1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color:
                            color.withValues(alpha: isSelected ? 0.25 : 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '$timeStr ${e.title}',
                              style: AppTypography.smallLight(color: color)
                                  .copyWith(
                                height: 1.1,
                                decoration: e.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  CalendarBuilders _buildCalendarBuilders(
      HolidayService holidayService, ScheduleService service) {
    return CalendarBuilders(
      defaultBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      todayBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: true,
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      selectedBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: true,
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      holidayBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: true,
        isOutside: false,
        isDisabled: false,
      ),
      outsideBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: true,
        isDisabled: false,
      ),
      disabledBuilder: (context, date, _) => _buildDayCell(
        context,
        date,
        service,
        holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: true,
      ),
      markerBuilder: (context, date, events) =>
          events.isNotEmpty ? const SizedBox.shrink() : null,
    );
  }

  void _deleteSchedule(Schedule schedule) {
    AppDialog.confirm(
      context: context,
      title: '删除日程',
      content: '确定删除"${schedule.title}"吗？',
      confirmLabel: '删除',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.read<ScheduleService>().deleteSchedule(schedule.localId);
      }
    });
  }

  void _showAddScheduleDialog(BuildContext context) {
    _showScheduleEditor(context, null);
  }

  void openAddSchedule() {
    _showAddScheduleDialog(context);
  }

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    _showScheduleEditor(context, schedule);
  }

  void _showScheduleEditor(BuildContext context, Schedule? schedule) {
    final isEditing = schedule != null;
    final titleC = TextEditingController(text: schedule?.title ?? '');
    final descC = TextEditingController(text: schedule?.description ?? '');
    final locationC = TextEditingController(text: schedule?.location ?? '');
    DateTime startDate = isEditing ? schedule.startTime : _selectedDay;
    DateTime endDate = isEditing ? schedule.endTime : _selectedDay;
    TimeOfDay startTime = isEditing
        ? TimeOfDay.fromDateTime(schedule.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = isEditing
        ? TimeOfDay.fromDateTime(schedule.endTime)
        : const TimeOfDay(hour: 10, minute: 0);
    bool isAllDay = isEditing
        ? (schedule.startTime.hour == 0 && schedule.endTime.hour == 23)
        : false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.xl,
                ),
                child: AppCard(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? '编辑日程' : '添加日程',
                          style: AppTypography.h2Light(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppInput(
                          controller: titleC,
                          hintText: '日程标题',
                          prefixIcon: const Icon(Icons.event, size: 20),
                        ),
                        const SizedBox(height: AppSpacing.component),
                        AppInput(
                          controller: descC,
                          hintText: '备注（可选）',
                          prefixIcon: const Icon(Icons.description, size: 20),
                          maxLines: 2,
                        ),
                        const SizedBox(height: AppSpacing.component),
                        Row(
                          children: [
                            Checkbox(
                              value: isAllDay,
                              onChanged: (v) =>
                                  setSheetState(() => isAllDay = v ?? false),
                            ),
                            Text('全天', style: AppTypography.bodyLight()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerCard(
                                label: '开始日期',
                                value: DateFormat('M月d日').format(startDate),
                                icon: Icons.calendar_today,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: ctx,
                                    initialDate: startDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setSheetState(() => startDate = date);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            if (!isAllDay)
                              Expanded(
                                child: _buildDatePickerCard(
                                  label: '开始时间',
                                  value: startTime.format(context),
                                  icon: Icons.access_time,
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: startTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => startTime = time);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.component),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDatePickerCard(
                                label: '结束日期',
                                value: DateFormat('M月d日').format(endDate),
                                icon: Icons.calendar_today,
                                onTap: () async {
                                  final date = await showDatePicker(
                                    context: ctx,
                                    initialDate: endDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 30)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (date != null) {
                                    setSheetState(() => endDate = date);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            if (!isAllDay)
                              Expanded(
                                child: _buildDatePickerCard(
                                  label: '结束时间',
                                  value: endTime.format(context),
                                  icon: Icons.access_time,
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: endTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => endTime = time);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.component),
                        AppInput(
                          controller: locationC,
                          hintText: '地点（可选）',
                          prefixIcon: const Icon(Icons.location_on, size: 20),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: isEditing ? '保存日程' : '添加日程',
                          icon: Icons.check,
                          onPressed: () {
                            if (titleC.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请输入日程标题')),
                              );
                              return;
                            }
                            final start = isAllDay
                                ? DateTime(startDate.year, startDate.month,
                                    startDate.day)
                                : DateTime(
                                    startDate.year,
                                    startDate.month,
                                    startDate.day,
                                    startTime.hour,
                                    startTime.minute);
                            final end = isAllDay
                                ? DateTime(endDate.year, endDate.month,
                                    endDate.day, 23, 59)
                                : DateTime(endDate.year, endDate.month,
                                    endDate.day, endTime.hour, endTime.minute);
                            final description = descC.text.trim().isEmpty
                                ? null
                                : descC.text.trim();
                            final location = locationC.text.trim().isEmpty
                                ? null
                                : locationC.text.trim();

                            if (isEditing) {
                              final updated = schedule.copyWith(
                                title: titleC.text.trim(),
                                description: description,
                                startTime: start,
                                endTime: end,
                                location: location,
                              );
                              context
                                  .read<ScheduleService>()
                                  .updateSchedule(updated);
                            } else {
                              final newSchedule = Schedule(
                                title: titleC.text.trim(),
                                description: description,
                                startTime: start,
                                endTime: end,
                                location: location,
                              );
                              context
                                  .read<ScheduleService>()
                                  .createSchedule(newSchedule);
                            }
                            Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDatePickerCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AppCard(
      shadows: const [],
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondaryText),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.smallLight()),
                Text(value, style: AppTypography.bodyMediumLight()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
