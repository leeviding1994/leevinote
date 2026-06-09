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
        onPressed: () => _showAddAlarmSheet(context),
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onLongPress: () => _showDiagnosticDialog(context),
            child: const Icon(Icons.alarm_add, size: 64, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text('暂无闹钟', style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('点击右下角按钮添加', style: TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => _showDiagnosticDialog(context),
            icon: const Icon(Icons.bug_report, size: 18),
            label: const Text('闹钟不响？点此诊断'),
          ),
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
    final dateStr = DateFormat('M月d日').format(alarm.alarmTime);
    final repeatText = alarm.repeatPattern ?? '单次';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: alarm.enabled ? 1 : 0,
      child: Opacity(
        opacity: alarm.enabled ? 1.0 : 0.5,
        child: ListTile(
          leading: GestureDetector(
            onLongPress: () => _showDiagnosticDialog(context),
            child: CircleAvatar(
              backgroundColor: alarm.enabled
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Colors.grey.shade200,
              child: Icon(
                alarm.enabled ? Icons.alarm : Icons.alarm_off,
                color: alarm.enabled
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
            ),
          ),
          title: Text(
            alarm.title,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text('$dateStr  $timeStr  ·  $repeatText'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: alarm.enabled,
                onChanged: (_) => service.toggleAlarm(alarm),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_outline, size: 20),
                tooltip: '立即测试',
                onPressed: () async {
                  final err = await service.triggerAlarmNow(alarm);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err ?? '🕐 5 秒后触发"${alarm.title}"'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAlarmSheet(BuildContext context) {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime selectedDate = DateTime.now();
    String? repeatPattern;

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
                    '添加闹钟',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now()
                                  .add(const Duration(days: 365)),
                            );
                            if (date != null) {
                              setSheetState(() => selectedDate = date);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '日期',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(DateFormat('M月d日').format(selectedDate)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: selectedTime,
                            );
                            if (time != null) {
                              setSheetState(() => selectedTime = time);
                            }
                          },
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: '时间',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.access_time),
                            ),
                            child: Text(selectedTime.format(context)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: repeatPattern,
                    decoration: const InputDecoration(
                      labelText: '重复',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.repeat),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('单次')),
                      DropdownMenuItem(value: '每天', child: Text('每天')),
                      DropdownMenuItem(value: '每周', child: Text('每周')),
                      DropdownMenuItem(value: '每月', child: Text('每月')),
                      DropdownMenuItem(
                          value: '工作日', child: Text('工作日（周一至周五）')),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => repeatPattern = v),
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
                        final alarm = Alarm(
                          title: titleC.text.trim(),
                          description: descC.text.trim().isEmpty
                              ? null
                              : descC.text.trim(),
                          alarmTime: DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          ),
                          enabled: true,
                          repeatPattern: repeatPattern,
                        );
                        context.read<AlarmService>().createAlarm(alarm);
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('添加闹钟'),
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

  void _showDiagnosticDialog(BuildContext context) {
    final service = context.read<AlarmService>();
    String testResult = '';
    String pendingInfo = '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, size: 24),
            SizedBox(width: 8),
            Text('闹钟诊断'),
          ],
        ),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _diagRow('通知插件已初始化', service.initialized),
                  const SizedBox(height: 12),
                  if (testResult.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(testResult,
                          style: TextStyle(
                              color: testResult.contains('失败')
                                  ? Colors.red
                                  : Colors.green)),
                    ),
                  if (pendingInfo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(pendingInfo, style: const TextStyle(fontSize: 13)),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final err = await service.sendTestNotification();
                        setDialogState(() {
                          testResult = err ?? '✅ 测试通知已发送，请查看手机通知栏';
                        });
                      },
                      icon: const Icon(Icons.notifications_active),
                      label: const Text('1. 发送测试通知'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final err = await service.rescheduleAll();
                        setDialogState(() {
                          testResult = err ?? '✅ 已重新调度所有闹钟';
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('2. 重新调度所有闹钟'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final pending = await service.getPendingNotifications();
                        setDialogState(() {
                          if (pending.isEmpty) {
                            pendingInfo = '⚠️ 没有待触发的通知 — 闹钟未被调度';
                          } else {
                            pendingInfo = '待触发通知 (${pending.length}个):\n';
                            for (final p in pending) {
                              pendingInfo += '  · ID $p\n';
                            }
                          }
                        });
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('3. 查看待触发通知列表'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _diagRow(String label, bool ok) {
    return Row(
      children: [
        Icon(ok ? Icons.check_circle : Icons.error,
            size: 18, color: ok ? Colors.green : Colors.red),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
      ],
    );
  }
}
