import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/alarm.dart';
import 'package:leevinote/services/alarm_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';

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
      service.load();
    });
  }

  Future<void> sync() async {
    final alarmService = context.read<AlarmService>();
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;
    final success = await alarmService.sync();
    if (mounted) {
      if (success) {
        AppToast.success(context, '闹钟同步完成');
      } else {
        AppToast.error(context, '同步失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final alarmService = context.watch<AlarmService>();

    return AppScaffold.noPadding(
      body: alarmService.loading
          ? const Center(child: CircularProgressIndicator())
          : alarmService.alarms.isEmpty
              ? _buildEmptyState()
              : _buildAlarmList(alarmService),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.alarm_add,
      title: '暂无闹钟',
      subtitle: '点击右下角按钮添加',
    );
  }

  Widget _buildAlarmList(AlarmService service) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: service.alarms.length,
      itemBuilder: (context, index) {
        final alarm = service.alarms[index];
        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
            child: _buildAlarmCard(alarm, service),
          ),
        );
      },
    );
  }

  Widget _buildAlarmCard(Alarm alarm, AlarmService service) {
    final timeStr = DateFormat('HH:mm').format(alarm.alarmTime);
    final repeatText = alarm.repeatPattern ?? '单次';

    return AppCard(
      onTap: () => _showAlarmEditor(context, alarm: alarm),
      shadows: alarm.enabled ? AppShadows.light : const [],
      child: Opacity(
        opacity: alarm.enabled ? 1.0 : 0.5,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              child: Text(
                timeStr,
                style: AppTypography.h2Light(
                  color: alarm.enabled
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.tertiaryText,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alarm.title,
                    style: AppTypography.bodyMediumLight(),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    repeatText,
                    style: AppTypography.smallLight(),
                  ),
                ],
              ),
            ),
            Switch(
              value: alarm.enabled,
              onChanged: (_) => service.toggleAlarm(alarm),
            ),
            AppIconButton(
              icon: Icons.delete_outline,
              onPressed: () => _confirmDelete(alarm, service),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Alarm alarm, AlarmService service) {
    AppDialog.confirm(
      context: context,
      title: '删除闹钟',
      content: '确定删除"${alarm.title}"吗？',
      confirmLabel: '删除',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true) service.deleteAlarm(alarm.localId);
    });
  }

  void openAddAlarm() {
    _showAlarmEditor(context);
  }

  void _showAlarmEditor(BuildContext context, {Alarm? alarm}) {
    final isEditing = alarm != null;
    final titleC = TextEditingController(text: isEditing ? alarm.title : '');
    int selectedHour = isEditing ? alarm.alarmTime.hour : TimeOfDay.now().hour;
    int selectedMinute =
        isEditing ? alarm.alarmTime.minute : TimeOfDay.now().minute;
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pageHorizontal,
                  vertical: AppSpacing.xl,
                ),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? '编辑闹钟' : '添加闹钟',
                          style: AppTypography.h2Light(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        AppInput(
                          controller: titleC,
                          hintText: '闹钟标题',
                          prefixIcon: const Icon(Icons.title, size: 20),
                        ),
                        const SizedBox(height: AppSpacing.component),
                        if (isEditing) ...[
                          Row(
                            children: [
                              Text('当前类型：',
                                  style: AppTypography.captionLight()),
                              Text(
                                repeatPattern ?? '单次',
                                style: AppTypography.captionMediumLight(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                        ],
                        SizedBox(
                          height: 180,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildTimeWheel(
                                  count: 24,
                                  selected: selectedHour,
                                  onChanged: (v) =>
                                      setSheetState(() => selectedHour = v),
                                ),
                              ),
                              Text(':',
                                  style: AppTypography.h2Light(
                                      color: AppColors.secondaryText)),
                              Expanded(
                                child: _buildTimeWheel(
                                  count: 60,
                                  selected: selectedMinute,
                                  onChanged: (v) =>
                                      setSheetState(() => selectedMinute = v),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.component),
                        Text('重复类型', style: AppTypography.captionMediumLight()),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: ['单次', '节假日', '工作日', '自定义'].map((type) {
                            final selected = repeatPattern == type;
                            return AppChip(
                              label: type,
                              selected: selected,
                              onSelected: (_) =>
                                  setSheetState(() => repeatPattern = type),
                            );
                          }).toList(),
                        ),
                        if (repeatPattern == '自定义')
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: [
                                for (int i = 1; i <= 7; i++)
                                  AppChip(
                                    label: {
                                      1: '周一',
                                      2: '周二',
                                      3: '周三',
                                      4: '周四',
                                      5: '周五',
                                      6: '周六',
                                      7: '周日'
                                    }[i]!,
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
                        const SizedBox(height: AppSpacing.xl),
                        AppButton(
                          label: isEditing ? '保存闹钟' : '添加闹钟',
                          icon: Icons.check,
                          onPressed: () => _saveAlarm(
                            ctx: ctx,
                            titleC: titleC,
                            selectedHour: selectedHour,
                            selectedMinute: selectedMinute,
                            repeatPattern: repeatPattern,
                            weekDays: weekDays,
                            alarm: alarm,
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

  Widget _buildTimeWheel({
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      itemExtent: 40,
      onSelectedItemChanged: onChanged,
      controller: FixedExtentScrollController(initialItem: selected),
      physics: const FixedExtentScrollPhysics(),
      childDelegate: ListWheelChildBuilderDelegate(
        builder: (context, index) {
          if (index < 0 || index >= count) return null;
          final isSelected = selected == index;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: AppTypography.h3Light(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : AppColors.tertiaryText,
              ),
            ),
          );
        },
        childCount: count,
      ),
    );
  }

  void _saveAlarm({
    required BuildContext ctx,
    required TextEditingController titleC,
    required int selectedHour,
    required int selectedMinute,
    required String? repeatPattern,
    required List<int> weekDays,
    Alarm? alarm,
  }) {
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
    if (alarm != null) {
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
  }
}
