import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:leevinote/models/schedule.dart';
import 'package:leevinote/services/schedule_service.dart';
import 'package:leevinote/services/holiday_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/screens/login_screen.dart';

enum ScheduleViewMode { day, threeDay, week, month, year }

const _viewModeLabels = {
  ScheduleViewMode.day: '日',
  ScheduleViewMode.threeDay: '3日',
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

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => SchedulesScreenState();
}

class SchedulesScreenState extends State<SchedulesScreen> {
  ScheduleViewMode _viewMode = ScheduleViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  DateTime? _rangeStart;
  CalendarFormat _calendarFormat = CalendarFormat.month;

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

  @override
  Widget build(BuildContext context) {
    final scheduleService = context.watch<ScheduleService>();

    return Scaffold(
      body: Column(
        children: [
          _buildViewModeSelector(),
          Expanded(
            child: _buildContent(scheduleService),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
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
                  _viewMode == ScheduleViewMode.day ||
                  _viewMode == ScheduleViewMode.threeDay) {
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
        return _buildCalendarWithEvents(service);
      case ScheduleViewMode.day:
        return _buildDayView(service);
      case ScheduleViewMode.threeDay:
        return _buildThreeDayView(service);
      case ScheduleViewMode.year:
        return _buildYearView(service);
    }
  }

  Widget _buildCalendarWithEvents(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    final selectedDateEvents = service.getSchedulesForDate(_selectedDay);

    return Column(
      children: [
        TableCalendar(
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
          calendarBuilders: _buildCalendarBuilders(holidayService),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarStyle: CalendarStyle(
            weekendTextStyle: TextStyle(color: Colors.red.shade400),
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
        const Divider(height: 1),
        _buildDayScheduleList(selectedDateEvents),
      ],
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
                  const SizedBox(width: 8),
                  Text(
                    '周${_weekdayNames[_selectedDay.weekday] ?? ''}',
                    style: TextStyle(
                      fontSize: 16,
                      color: isWeekend ? Colors.red.shade400 : Colors.grey,
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
        final startStr = DateFormat('HH:mm').format(event.startTime);
        final endStr = DateFormat('HH:mm').format(event.endTime);
        final isAllDay = event.startTime.hour == 0 && event.endTime.hour == 23;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAllDay ? '全天' : '$startStr - $endStr',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      if (event.location != null &&
                          event.location!.isNotEmpty)
                        Text(
                          event.location!,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _deleteSchedule(event),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildThreeDayView(ScheduleService service) {
    final holidayService = context.watch<HolidayService>();
    final start = _rangeStart ?? _selectedDay;
    final days = List.generate(3, (i) => start.add(Duration(days: i)));

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
                    _rangeStart = start.subtract(const Duration(days: 3));
                  });
                },
              ),
              Text(
                '${DateFormat('M月d日').format(days.first)} - ${DateFormat('M月d日').format(days.last)}',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w500),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _rangeStart = start.add(const Duration(days: 3));
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: days.map((day) {
              final isWeekend = day.weekday == DateTime.saturday ||
                  day.weekday == DateTime.sunday;
              final isHoli = holidayService.isHoliday(day);
              final holiday = holidayService.getHoliday(day);
              final dayEvents = service.getSchedulesForDate(day);
              final isSelected = isSameDay(day, _selectedDay);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _selectedDay = day),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context)
                                .colorScheme
                                .primaryContainer
                            : null,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Text(
                            '${day.month}/${day.day}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isWeekend || isHoli
                                  ? Colors.red.shade400
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '周${_weekdayNames[day.weekday] ?? ''}',
                            style: TextStyle(
                              color: isWeekend || isHoli
                                  ? Colors.red.shade400
                                  : Colors.grey,
                            ),
                          ),
                          if (isHoli && holiday != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(holiday.name,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700)),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            '${dayEvents.length}项',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSelected)
                    ...dayEvents.map((e) => _buildMiniScheduleItem(e)),
                  const Divider(height: 1),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniScheduleItem(Schedule event) {
    final startStr = DateFormat('HH:mm').format(event.startTime);
    final endStr = DateFormat('HH:mm').format(event.endTime);

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 8, top: 4, bottom: 4),
      child: Row(
        children: [
          Text('$startStr-$endStr',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            color: Colors.red.shade300,
            onPressed: () => _deleteSchedule(event),
          ),
        ],
      ),
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
      final hasEvent = service.getSchedulesForDate(date).isNotEmpty;
      final isToday = day == today;

      cells.add(
        Container(
          decoration: isToday
              ? BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                )
              : null,
          child: Center(
            child: Text(
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
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }

  Widget _buildDayScheduleList(List<Schedule> events) {
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Text('点击日期查看日程',
              style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
      );
    }

    events.sort((a, b) => a.startTime.compareTo(b.startTime));

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final startStr = DateFormat('HH:mm').format(event.startTime);
          final endStr = DateFormat('HH:mm').format(event.endTime);
          final isAllDay =
              event.startTime.hour == 0 && event.endTime.hour == 23;

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  isAllDay ? Icons.event : Icons.access_time,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              title: Text(event.title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(
                isAllDay
                    ? '全天'
                    : event.location != null && event.location!.isNotEmpty
                        ? '$startStr - $endStr  ·  ${event.location}'
                        : '$startStr - $endStr',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteSchedule(event),
              ),
            ),
          );
        },
      ),
    );
  }

  CalendarBuilders _buildCalendarBuilders(HolidayService holidayService) {
    return CalendarBuilders(
      markerBuilder: (context, date, events) {
        if (events.isEmpty) return null;
        return Positioned(
          right: 1,
          bottom: 1,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      defaultBuilder: (context, date, _) {
        final isHoli = holidayService.isHoliday(date);
        final name = holidayService.getHoliday(date)?.name ?? '';
        final isWeekend = date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday;

        if (isHoli || isWeekend) {
          return Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${date.day}',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isHoli && name.length <= 2)
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.red.shade300,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          );
        }
        return null;
      },
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                  SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom > 0
                      ? 0
                      : 20),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
