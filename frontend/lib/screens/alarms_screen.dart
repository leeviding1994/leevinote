import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/models/alarm.dart';
import 'package:leevinote/services/alarm_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/screens/login_screen.dart';
import 'package:intl/intl.dart';

class AlarmsScreen extends StatefulWidget {
  const AlarmsScreen({super.key});

  @override
  State<AlarmsScreen> createState() => AlarmsScreenState();
}

class AlarmsScreenState extends State<AlarmsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<AlarmService>();
      // load() 内部会调用 initialize()，不要单独调用，避免并发权限请求
      service.load();
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
    final success = await context.read<AlarmService>().sync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '闹钟同步完成' : '同步失败'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarmService = context.watch<AlarmService>();

    return Scaffold(
      body: alarmService.loading
          ? const Center(child: CircularProgressIndicator())
          : alarmService.alarms.isEmpty
              ? _buildEmptyState()
              : _buildAlarmList(alarmService),
      floatingActionButton: FloatingActionButton(
        heroTag: 'alarms_fab',
        onPressed: () => _showAlarmEditor(context),
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.alarm_add, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('暂无闹钟', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildAlarmList(AlarmService service) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: service.alarms.length,
      itemBuilder: (context, index) {
        final alarm = service.alarms[index];
        return _buildAlarmCard(alarm, service);
      },
    );
  }

  Widget _buildAlarmCard(Alarm alarm, AlarmService service) {
    final timeStr = DateFormat('HH:mm').format(alarm.alarmTime);
    final repeatText = alarm.repeatPattern ?? '单次';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: alarm.enabled ? 1 : 0,
      child: Opacity(
        opacity: alarm.enabled ? 1.0 : 0.5,
        child: InkWell(
          onTap: () => _showAlarmEditor(context, alarm: alarm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 时间显示
                SizedBox(
                  width: 72,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: alarm.enabled
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 标题和重复信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        repeatText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // 开关（阻止事件冒泡）
                Switch(
                  value: alarm.enabled,
                  onChanged: (_) => service.toggleAlarm(alarm),
                ),
                // 删除按钮（阻止事件冒泡）
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('删除闹钟'),
                        content: Text('确定删除"${alarm.title}"吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              service.deleteAlarm(alarm.localId);
                              Navigator.pop(ctx);
                            },
                            child: const Text('确定',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.delete_outline, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlarmEditor(BuildContext context, {Alarm? alarm}) {
    final isEditing = alarm != null;
    final titleC = TextEditingController(text: isEditing ? alarm.title : '');
    int selectedHour = isEditing ? alarm.alarmTime.hour : TimeOfDay.now().hour;
    int selectedMinute = isEditing ? alarm.alarmTime.minute : TimeOfDay.now().minute;
    String? repeatPattern = isEditing ? alarm.repeatPattern : null;
    final weekDays = isEditing ? List<int>.from(alarm.weekDays) : <int>[];

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
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? '编辑闹钟' : '添加闹钟',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: titleC,
                          decoration: const InputDecoration(
                            labelText: '闹钟标题',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.title),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 时间直接显示滚轮选择器
                        SizedBox(
                          height: 180,
                          child: Row(
                            children: [
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: 40,
                                  onSelectedItemChanged: (index) {
                                    setSheetState(() => selectedHour = index);
                                  },
                                  controller: FixedExtentScrollController(initialItem: selectedHour),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      if (index < 0 || index >= 24) return null;
                                      return Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: selectedHour == index ? FontWeight.bold : FontWeight.normal,
                                            color: selectedHour == index ? Theme.of(context).colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: 24,
                                  ),
                                ),
                              ),
                              const Text(':', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: ListWheelScrollView.useDelegate(
                                  itemExtent: 40,
                                  onSelectedItemChanged: (index) {
                                    setSheetState(() => selectedMinute = index);
                                  },
                                  controller: FixedExtentScrollController(initialItem: selectedMinute),
                                  childDelegate: ListWheelChildBuilderDelegate(
                                    builder: (context, index) {
                                      if (index < 0 || index >= 60) return null;
                                      return Center(
                                        child: Text(
                                          index.toString().padLeft(2, '0'),
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: selectedMinute == index ? FontWeight.bold : FontWeight.normal,
                                            color: selectedMinute == index ? Theme.of(context).colorScheme.primary : Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                    childCount: 60,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('重复类型', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final type in ['单次', '节假日', '工作日', '自定义'])
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: OutlinedButton(
                                    onPressed: () => setSheetState(() => repeatPattern = type),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: repeatPattern == type
                                          ? Theme.of(context).colorScheme.primary
                                          : null,
                                      foregroundColor: repeatPattern == type
                                          ? Colors.white
                                          : null,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    child: Text(type, style: const TextStyle(fontSize: 12)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (repeatPattern == '自定义')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Wrap(
                              spacing: 8,
                              children: [
                                for (int i = 1; i <= 7; i++)
                                  FilterChip(
                                    label: Text({1: '周一', 2: '周二', 3: '周三', 4: '周四', 5: '周五', 6: '周六', 7: '周日'}[i]!),
                                    selected: weekDays.contains(i),
                                    onSelected: (selected) {
                                      setSheetState(() {
                                        if (selected) {
                                          weekDays.add(i);
                                        } else {
                                          weekDays.remove(i);
                                        }
                                      });
                                    },
                                  ),
                              ],
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
                                  const SnackBar(content: Text('请输入闹钟标题')),
                                );
                                return;
                              }
                              if (repeatPattern == '自定义' && weekDays.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('请选择至少一天')),
                                );
                                return;
                              }
                              final alarmTime = DateTime(
                                DateTime.now().year,
                                DateTime.now().month,
                                DateTime.now().day,
                                selectedHour,
                                selectedMinute,
                              );
                              if (isEditing) {
                                final updated = alarm.copyWith(
                                  title: titleC.text.trim(),
                                  alarmTime: alarmTime,
                                  repeatPattern: repeatPattern,
                                  weekDays: weekDays,
                                );
                                context.read<AlarmService>().updateAlarm(updated);
                              } else {
                                final newAlarm = Alarm(
                                  title: titleC.text.trim(),
                                  alarmTime: alarmTime,
                                  enabled: true,
                                  repeatPattern: repeatPattern,
                                  weekDays: weekDays,
                                );
                                context.read<AlarmService>().createAlarm(newAlarm);
                              }
                              Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.check),
                            label: Text(isEditing ? '保存闹钟' : '添加闹钟'),
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
