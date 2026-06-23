import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:lunar/lunar.dart';
import 'package:leevinote/models/schedule.dart';
import 'package:leevinote/services/schedule_service.dart';
import 'package:leevinote/services/holiday_service.dart';
import 'package:leevinote/services/auth_service.dart';
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
  Color(0xFF5B8FF9),  // 蓝色
  Color(0xFF5AD8A6),  // 绿色
  Color(0xFFF6BD16),  // 黄色
  Color(0xFF6DC8EC),  // 青色
  Color(0xFF9270CA),  // 紫色
  Color(0xFFFF9D4D),  // 橙色
  Color(0xFF269A99),  // 深青
  Color(0xFFFF99C3),  // 粉色
  Color(0xFFB5C334),  // 黄绿
  Color(0xFF6D64A8),  // 深紫
  Color(0xFFE8684A),  // 红色
  Color(0xFF7CB305),  // 草绿
];

  Color _getScheduleColor(int index) {
    return _scheduleColors[index % _scheduleColors.length];
  }

  Widget _todayBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        '今',
        style: TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
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
      return lunar.getMonthInChinese() + '月';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleService>().load();
      context.read<HolidayService>().fetchHolidays(DateTime.now().year);
    });
  }

  Future<void> sync() async {
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    final success = await context.read<ScheduleService>().sync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '日程同步完成' : '同步失败'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
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
      floatingActionButton: _isSearching
          ? null
          : FloatingActionButton(
              heroTag: 'schedules_fab',
              onPressed: () => _showAddScheduleDialog(context),
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildViewModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${_selectedDay.month}月${_selectedDay.day}日',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 6),
                    _todayBadge(context),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '周${_weekdayNames[_selectedDay.weekday] ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isWeekend ? Colors.red.shade400 : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lunarFull,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              if (isHoli && holiday != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      holiday.name,
                      style: TextStyle(
                          color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedDay = _selectedDay.subtract(const Duration(days: 1));
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
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
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('暂无日程', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final colorIndex = event.localId.hashCode.abs();
        final color = _getScheduleColor(colorIndex);
        final startStr = DateFormat('HH:mm').format(event.startTime);
        final endStr = DateFormat('HH:mm').format(event.endTime);
        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

        return GestureDetector(
          onTap: () => _showEditScheduleDialog(context, event),
          child: Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: event.completed,
                    onChanged: (v) {
                      context.read<ScheduleService>().toggleCompleted(event.localId);
                    },
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          event.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            decoration: event.completed ? TextDecoration.lineThrough : null,
                            color: event.completed ? Colors.grey : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAllDay ? '全天' : '$startStr - $endStr',
                          style: TextStyle(
                            color: event.completed ? Colors.grey.shade400 : Colors.grey.shade600,
                            decoration: event.completed ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (event.location != null &&
                            event.location!.isNotEmpty)
                          Text(
                            event.location!,
                            style: TextStyle(
                              color: event.completed ? Colors.grey.shade400 : Colors.grey.shade500,
                              decoration: event.completed ? TextDecoration.lineThrough : null,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
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
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
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
              final daysInMonth =
                  DateTime(currentYear, month + 1, 0).day;
              final firstWeekday =
                  DateTime(currentYear, month, 1).weekday;
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
                      color: allCompleted ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '搜索日程名称...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, size: 18),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () {
                  _searchController.clear();
                  _performSearch();
                },
              ),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onSubmitted: (_) => _performSearch(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _searchStartDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => _searchStartDate = date);
                      _performSearch();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '开始日期',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      _searchStartDate != null
                          ? DateFormat('yyyy-MM-dd').format(_searchStartDate!)
                          : '不限',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _searchEndDate ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                    );
                    if (date != null) {
                      setState(() => _searchEndDate = date);
                      _performSearch();
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '结束日期',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: Text(
                      _searchEndDate != null
                          ? DateFormat('yyyy-MM-dd').format(_searchEndDate!)
                          : '不限',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _performSearch,
              child: const Text('搜索'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('未找到日程', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final event = _searchResults[index];
        final startStr = DateFormat('MM-dd HH:mm').format(event.startTime);
        final endStr = DateFormat('MM-dd HH:mm').format(event.endTime);
        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                isAllDay ? Icons.event : Icons.access_time,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              isAllDay
                  ? '${DateFormat('yyyy-MM-dd').format(event.startTime)} 全天'
                  : '$startStr - $endStr',
            ),
            onTap: () => _showEditScheduleDialog(context, event),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteSchedule(event),
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
    final events = service.getSchedulesForDate(day);
    final holidayService = context.read<HolidayService>();
    final isHoli = holidayService.isHoliday(day);
    final holiday = holidayService.getHoliday(day);
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final lunarFull = _getLunarFull(day);
    final isToday = isSameDay(day, DateTime.now());

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
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
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (isToday) ...[
                                  const SizedBox(width: 6),
                                  _todayBadge(context),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  '周${_weekdayNames[day.weekday] ?? ''}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isWeekend || isHoli
                                        ? Colors.red.shade400
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  lunarFull,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                if (isHoli && holiday != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      holiday.name,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.red.shade700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (events.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        '暂无日程',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      shrinkWrap: true,
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        final colorIndex = event.localId.hashCode.abs();
                        final color = _getScheduleColor(colorIndex);
                        final startStr = DateFormat('HH:mm').format(event.startTime);
                        final endStr = DateFormat('HH:mm').format(event.endTime);
                        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.15),
                              child: Icon(
                                isAllDay ? Icons.event : Icons.access_time,
                                color: color,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              event.title,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              isAllDay
                                  ? '全天'
                                  : event.location != null && event.location!.isNotEmpty
                                      ? '$startStr - $endStr  ·  ${event.location}'
                                      : '$startStr - $endStr',
                            ),
                            onTap: () {
                              Navigator.pop(ctx);
                              _showEditScheduleDialog(context, event);
                            },
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () {
                                _deleteSchedule(event);
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeekView(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    // weekStart: Monday (DateTime.monday = 1, so weekday - 1 days back)
    final weekStart = _selectedDay.subtract(
      Duration(days: (_selectedDay.weekday - DateTime.monday) % 7),
    );
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDay = _selectedDay.subtract(const Duration(days: 7));
                  });
                },
              ),
              Text(
                '${DateFormat('M月d日').format(days.first)} - ${DateFormat('M月d日').format(days.last)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
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
    final isWeekend = day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
    final isHoli = holidayService.isHoliday(day);
    final isToday = isSameDay(day, DateTime.now());

    // 全天日程
    final allDayEvents = events.where((e) =>
        e.startTime.hour == 0 && e.endTime.hour == 23).toList();
    // 普通日程
    final timedEvents = events.where((e) =>
        !(e.startTime.hour == 0 && e.endTime.hour == 23)).toList();

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
    final double allDayGap = allDayEvents.isNotEmpty && rows.isNotEmpty ? 4.0 : 0.0;
    final double timelineHeight = rows.isEmpty
        ? 0
        : rows.length * rowHeight + (rows.length - 1) * rowGap;
    final double contentHeight = allDayHeight + allDayGap + timelineHeight;

    return InkWell(
      onTap: () => _showDayEventsBubble(context, day, service),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.shade200),
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
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: events.every((s) => s.completed)
                                          ? Colors.green
                                          : Colors.red,
                                      width: 1.5,
                                    ),
                                  )
                                : null,
                        child: Text(
                          '${day.day}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isToday
                                ? Colors.white
                                : events.isNotEmpty
                                    ? (events.every((s) => s.completed)
                                        ? Colors.green
                                        : Colors.red)
                                    : isWeekend || isHoli
                                        ? Colors.red.shade400
                                        : null,
                          ),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 4),
                        _todayBadge(context),
                      ],
                    ],
                  ),
                  Text(
                    '周${_weekdayNames[day.weekday] ?? ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: isWeekend || isHoli
                          ? Colors.red.shade400
                          : Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    _getLunarDayShort(day),
                    style: TextStyle(
                      fontSize: 10,
                      color: isWeekend || isHoli
                          ? Colors.red.shade300
                          : Colors.grey.shade500,
                    ),
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
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.grey.shade400,
                              ),
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
                          child: const Text(
                            '无日程',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      }

                      return Container(
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
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          e.title,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: color,
                                            overflow: TextOverflow.ellipsis,
                                            decoration: e.completed ? TextDecoration.lineThrough : null,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            // 各行列的普通日程
                            for (int rowIndex = 0; rowIndex < rows.length; rowIndex++)
                              Positioned(
                                top: allDayHeight + allDayGap + rowIndex * (rowHeight + rowGap),
                                left: 0,
                                right: 0,
                                child: SizedBox(
                                  height: rowHeight,
                                  child: Stack(
                                    children: rows[rowIndex].map((e) {
                                      final startMin = e.startTime.hour * 60 + e.startTime.minute;
                                      final endMin = e.endTime.hour * 60 + e.endTime.minute;
                                      final left = (startMin / 1440.0) * timelineWidth;
                                      final width = ((endMin - startMin) / 1440.0) * timelineWidth;
                                      final colorIndex = e.localId.hashCode.abs();
                                      final color = _getScheduleColor(colorIndex);
                                      return Positioned(
                                        left: left,
                                        width: width.clamp(40, timelineWidth - left),
                                        child: GestureDetector(
                                          onTap: () => _showEditScheduleDialog(context, e),
                                          child: Container(
                                            height: rowHeight,
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(4),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: color.withValues(alpha: 0.3),
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
                                                      overflow: TextOverflow.ellipsis,
                                                      decoration: e.completed ? TextDecoration.lineThrough : null,
                                                    ),
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('HH:mm').format(e.startTime),
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.white.withValues(alpha: 0.85),
                                                    decoration: e.completed ? TextDecoration.lineThrough : null,
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
    final somePending = events.isNotEmpty && events.any((s) => !s.completed);
    final textColor = isDisabled
        ? Colors.grey.shade400
        : isSelected
            ? Colors.white
            : isWeekend || isHoliday
                ? Colors.red.shade400
                : null;
    final lunarDay = _getLunarDayShort(date);

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
                                    color: Theme.of(context).colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  )
                                : events.isNotEmpty
                                    ? BoxDecoration(
                                        color: allCompleted
                                            ? Colors.green.withValues(alpha: 0.15)
                                            : Colors.red.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: allCompleted ? Colors.green : Colors.red,
                                          width: 1,
                                        ),
                                      )
                                    : null,
                        child: Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isToday && events.isNotEmpty
                                ? (allCompleted ? Colors.green : Colors.red)
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
                if (lunarDay.isNotEmpty)
                  Text(
                    lunarDay,
                    style: TextStyle(
                      fontSize: 9,
                      color: textColor?.withValues(alpha: 0.7) ?? Colors.grey.shade500,
                    ),
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
                    final isAllDay = e.startTime.hour == 0 && e.endTime.hour == 23;
                    final timeStr = isAllDay
                        ? '全天'
                        : '${DateFormat('HH:mm').format(e.startTime)}-${DateFormat('HH:mm').format(e.endTime)}';
                    final colorIndex = e.localId.hashCode.abs();
                    final color = _getScheduleColor(colorIndex);
                    return Container(
                      margin: const EdgeInsets.only(top: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isSelected ? 0.25 : 0.15),
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
                              style: TextStyle(
                                fontSize: 8,
                                height: 1.1,
                                color: color,
                                overflow: TextOverflow.ellipsis,
                                decoration: e.completed ? TextDecoration.lineThrough : null,
                              ),
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
        context, date, service, holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      todayBuilder: (context, date, _) => _buildDayCell(
        context, date, service, holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: true,
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      selectedBuilder: (context, date, _) => _buildDayCell(
        context, date, service, holidayService,
        isSelected: true,
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: false,
      ),
      holidayBuilder: (context, date, _) => _buildDayCell(
        context, date, service, holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: true,
        isOutside: false,
        isDisabled: false,
      ),
      outsideBuilder: (context, date, _) => _buildDayCell(
        context, date, service, holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: true,
        isDisabled: false,
      ),
      disabledBuilder: (context, date, _) => _buildDayCell(
        context, date, service, holidayService,
        isSelected: isSameDay(_selectedDay, date),
        isToday: isSameDay(date, DateTime.now()),
        isWeekend: date.weekday == DateTime.saturday || date.weekday == DateTime.sunday,
        isHoliday: holidayService.isHoliday(date),
        isOutside: false,
        isDisabled: true,
      ),
      markerBuilder: (context, date, events) =>
          events.isNotEmpty ? const SizedBox.shrink() : null,
    );
  }

  void _deleteSchedule(Schedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除日程'),
        content: Text('确定删除"${schedule.title}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<ScheduleService>().deleteSchedule(schedule.localId);
              Navigator.pop(ctx);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    final locationC = TextEditingController();
    DateTime startDate = _selectedDay;
    DateTime endDate = _selectedDay;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 10, minute: 0);
    bool isAllDay = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '添加日程',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleC,
                          decoration: const InputDecoration(
                            labelText: '日程标题',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descC,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('全天'),
                          value: isAllDay,
                          onChanged: (v) =>
                              setSheetState(() => isAllDay = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
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
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '开始日期',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('M月d日').format(startDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isAllDay)
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: startTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => startTime = time);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '开始时间',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(startTime.format(context)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
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
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '结束日期',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('M月d日').format(endDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isAllDay)
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: endTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => endTime = time);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '结束时间',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(endTime.format(context)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationC,
                          decoration: const InputDecoration(
                            labelText: '地点（可选）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (titleC.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请输入日程标题')),
                                );
                                return;
                              }
                              final schedule = Schedule(
                                title: titleC.text.trim(),
                                description: descC.text.trim().isEmpty
                                    ? null
                                    : descC.text.trim(),
                                startTime: isAllDay
                                    ? DateTime(
                                        startDate.year,
                                        startDate.month,
                                        startDate.day,
                                      )
                                    : DateTime(
                                        startDate.year,
                                        startDate.month,
                                        startDate.day,
                                        startTime.hour,
                                        startTime.minute,
                                      ),
                                endTime: isAllDay
                                    ? DateTime(
                                        endDate.year,
                                        endDate.month,
                                        endDate.day,
                                        23,
                                        59,
                                      )
                                    : DateTime(
                                        endDate.year,
                                        endDate.month,
                                        endDate.day,
                                        endTime.hour,
                                        endTime.minute,
                                      ),
                                location: locationC.text.trim().isEmpty
                                    ? null
                                    : locationC.text.trim(),
                              );
                              context
                                  .read<ScheduleService>()
                                  .createSchedule(schedule);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('添加日程'),
                          ),
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

  void _showEditScheduleDialog(BuildContext context, Schedule schedule) {
    final titleC = TextEditingController(text: schedule.title);
    final descC = TextEditingController(text: schedule.description ?? '');
    final locationC = TextEditingController(text: schedule.location ?? '');
    DateTime startDate = schedule.startTime;
    DateTime endDate = schedule.endTime;
    TimeOfDay startTime = TimeOfDay.fromDateTime(schedule.startTime);
    TimeOfDay endTime = TimeOfDay.fromDateTime(schedule.endTime);
    bool isAllDay = schedule.startTime.hour == 0 && schedule.endTime.hour == 23;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '编辑日程',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleC,
                          decoration: const InputDecoration(
                            labelText: '日程标题',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descC,
                          decoration: const InputDecoration(
                            labelText: '备注（可选）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.description),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('全天'),
                          value: isAllDay,
                          onChanged: (v) =>
                              setSheetState(() => isAllDay = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
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
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '开始日期',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('M月d日').format(startDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isAllDay)
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: startTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => startTime = time);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '开始时间',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(startTime.format(context)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
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
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: '结束日期',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                  child: Text(DateFormat('M月d日').format(endDate)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            if (!isAllDay)
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final time = await showTimePicker(
                                      context: ctx,
                                      initialTime: endTime,
                                    );
                                    if (time != null) {
                                      setSheetState(() => endTime = time);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: '结束时间',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(Icons.access_time),
                                    ),
                                    child: Text(endTime.format(context)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationC,
                          decoration: const InputDecoration(
                            labelText: '地点（可选）',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.location_on),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (titleC.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请输入日程标题')),
                                );
                                return;
                              }
                              final updated = schedule.copyWith(
                                title: titleC.text.trim(),
                                description: descC.text.trim().isEmpty
                                    ? null
                                    : descC.text.trim(),
                                startTime: isAllDay
                                    ? DateTime(
                                        startDate.year,
                                        startDate.month,
                                        startDate.day,
                                      )
                                    : DateTime(
                                        startDate.year,
                                        startDate.month,
                                        startDate.day,
                                        startTime.hour,
                                        startTime.minute,
                                      ),
                                endTime: isAllDay
                                    ? DateTime(
                                        endDate.year,
                                        endDate.month,
                                        endDate.day,
                                        23,
                                        59,
                                      )
                                    : DateTime(
                                        endDate.year,
                                        endDate.month,
                                        endDate.day,
                                        endTime.hour,
                                        endTime.minute,
                                      ),
                                location: locationC.text.trim().isEmpty
                                    ? null
                                    : locationC.text.trim(),
                              );
                              context
                                  .read<ScheduleService>()
                                  .updateSchedule(updated);
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('保存日程'),
                          ),
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
}
