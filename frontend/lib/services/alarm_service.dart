import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leevinote/models/alarm.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_alarm_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class AlarmService extends ChangeNotifier {
  final ApiService _api;
  final LocalAlarmService _local;
  List<Alarm> _alarms = [];
  bool _loading = false;
  bool _syncing = false;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  bool _initialized = false;

  AlarmService(this._api, this._local);

  List<Alarm> get alarms => _alarms;
  bool get loading => _loading;
  bool get syncing => _syncing;
  bool get initialized => _initialized;

  int _notificationId(Alarm alarm) => alarm.localId.hashCode & 0x7FFFFFFF;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();

      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _notificationsPlugin!.initialize(settings: initSettings);

      // Request Android permissions (native system dialog, not grayed out)
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.requestNotificationsPermission();
          // Android 12+ requires runtime permission for exact alarms.
          // This will open a system settings page if the toggle is not grayed out.
          await androidPlugin.requestExactAlarmsPermission();
        }
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize notifications: $e');
    }
  }

  Future<void> load() async {
    await initialize();
    _loading = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();
      _alarms = List.from(_local.alarms);
      // Re-schedule all enabled future alarms after load
      for (final alarm in _alarms) {
        if (alarm.enabled) {
          await _scheduleNotification(alarm);
        }
      }
    } catch (e) {
      debugPrint('Failed to load local alarms: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchAlarms() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getList(ApiConstants.alarms);
      final remoteAlarms = data
          .map((e) => Alarm.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final ra in remoteAlarms) {
        await _local.addOrUpdateFromRemote(ra);
      }
      _alarms = List.from(_local.alarms);
    } catch (e) {
      debugPrint('Failed to fetch alarms, using local data: $e');
      _alarms = List.from(_local.alarms);
    }
    _loading = false;
    notifyListeners();
  }

  Future<Alarm?> createAlarm(Alarm alarm) async {
    final localAlarm = alarm.copyWith(syncStatus: 'local');
    await _local.addAlarm(localAlarm);
    _alarms.insert(0, localAlarm);
    _alarms.sort((a, b) => a.alarmTime.compareTo(b.alarmTime));
    notifyListeners();
    if (_initialized && localAlarm.enabled) {
      await _scheduleNotification(localAlarm);
    }
    return localAlarm;
  }

  Future<void> deleteAlarm(String localId) async {
    final alarm = _alarms.firstWhere(
      (a) => a.localId == localId,
      orElse: () => Alarm(title: '', alarmTime: DateTime.now()),
    );
    // Always cancel the local notification
    if (_initialized) {
      await _notificationsPlugin?.cancel(id: _notificationId(alarm));
    }
    if (alarm.id != null) {
      final updated = alarm.copyWith(syncStatus: 'deleted');
      await _local.updateAlarm(updated);
      final index = _alarms.indexWhere((a) => a.localId == localId);
      if (index != -1) _alarms[index] = updated;
    } else {
      await _local.deleteAlarm(localId);
      _alarms.removeWhere((a) => a.localId == localId);
    }
    notifyListeners();
  }

  Future<void> toggleAlarm(Alarm alarm) async {
    final updated = alarm.copyWith(
      enabled: !alarm.enabled,
      syncStatus: alarm.id != null ? 'modified' : 'local',
    );
    await _local.updateAlarm(updated);
    final index = _alarms.indexWhere((a) => a.localId == alarm.localId);
    if (index != -1) _alarms[index] = updated;
    notifyListeners();
    if (_initialized) {
      if (updated.enabled) {
        await _scheduleNotification(updated);
      } else {
        await _notificationsPlugin?.cancel(id: _notificationId(updated));
      }
    }
  }

  Future<bool> sync() async {
    _syncing = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();

      for (final alarm in List.from(_local.alarms)) {
        if (alarm.syncStatus == 'deleted' && alarm.id != null) {
          try {
            await _api.delete('${ApiConstants.alarms}/${alarm.id}');
            await _local.deleteAlarm(alarm.localId);
          } catch (_) {}
        } else if (alarm.syncStatus == 'local' || alarm.syncStatus == 'modified') {
          try {
            final result = await _api.post(ApiConstants.alarms, alarm.toRemoteJson());
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateAlarm(alarm.copyWith(
              id: newId,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.alarms);
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final alarm in List.from(_local.alarms)) {
        if (alarm.id != null && alarm.syncStatus == 'synced' && !remoteIds.contains(alarm.id)) {
          await _local.deleteAlarm(alarm.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Alarm.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote);
      }

      _alarms = List.from(_local.alarms);
      _syncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Alarm sync failed: $e');
      _syncing = false;
      notifyListeners();
      return false;
    }
  }

  /// 发送一条立即通知，用于诊断通知渠道是否正常工作
  Future<String?> sendTestNotification() async {
    if (_notificationsPlugin == null) return '通知插件未初始化';
    try {
      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        '闹钟提醒',
        channelDescription: '闹钟提醒通知',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      await _notificationsPlugin!.show(
        id: -1,
        title: '测试通知',
        body: '如果你看到这条通知，说明通知渠道是正常的',
        notificationDetails: details,
      );
      return null; // success
    } catch (e) {
      return '发送测试通知失败: $e';
    }
  }

  /// 返回当前待触发的所有通知（用于诊断）
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (_notificationsPlugin == null) return [];
    try {
      return await _notificationsPlugin!.pendingNotificationRequests();
    } catch (e) {
      debugPrint('获取待触发通知失败: $e');
      return [];
    }
  }

  /// 重新调度所有已启用的闹钟（用于诊断/修复）
  Future<String?> rescheduleAll() async {
    if (_notificationsPlugin == null) return '通知插件未初始化';
    try {
      for (final alarm in _alarms.where((a) => a.enabled)) {
        await _scheduleNotification(alarm);
      }
      return null;
    } catch (e) {
      return '重新调度失败: $e';
    }
  }

  /// 立即触发指定闹钟（用于测试）
  /// 优先使用 zonedSchedule 在 5 秒后触发；若精确闹钟权限未授予，
  /// 则立即发送一条通知（show），避免 inexactAllowWhileIdle 被系统延迟 9 分钟。
  Future<String?> triggerAlarmNow(Alarm alarm) async {
    if (_notificationsPlugin == null) return '通知插件未初始化';
    try {
      // 取消原有调度
      await _notificationsPlugin!.cancel(id: _notificationId(alarm));

      const androidDetails = AndroidNotificationDetails(
        'alarm_channel',
        '闹钟提醒',
        channelDescription: '闹钟提醒通知',
        importance: Importance.high,
        priority: Priority.high,
        fullScreenIntent: true,
        playSound: true,
        enableVibration: true,
      );
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final now = tz.TZDateTime.now(tz.local);
      final trigger = now.add(const Duration(seconds: 5));

      const modes = [
        AndroidScheduleMode.alarmClock,
        AndroidScheduleMode.exactAllowWhileIdle,
      ];
      for (final mode in modes) {
        try {
          await _notificationsPlugin!.zonedSchedule(
            id: _notificationId(alarm),
            title: alarm.title,
            body: '测试触发 — 原定 ${alarm.alarmTime.hour}:${alarm.alarmTime.minute.toString().padLeft(2, '0')}',
            scheduledDate: trigger,
            notificationDetails: details,
            androidScheduleMode: mode,
          );
          // 5 秒后重新恢复原调度
          Future.delayed(const Duration(seconds: 6), () {
            _scheduleNotification(alarm);
          });
          return null; // success
        } catch (e) {
          debugPrint('triggerAlarmNow $mode 调度失败: $e');
        }
      }

      // 精确闹钟权限未授予，zonedSchedule 无法保证 5 秒后准时触发
      // 直接立即发送通知，让用户立刻看到效果
      await _notificationsPlugin!.show(
        id: _notificationId(alarm),
        title: alarm.title,
        body: '测试触发（立即）— 原定 ${alarm.alarmTime.hour}:${alarm.alarmTime.minute.toString().padLeft(2, '0')}',
        notificationDetails: details,
      );
      return '未授予精确闹钟权限，已立即显示通知。请前往系统设置 → 应用 → 本应用 → 闹钟与提醒 → 允许精确闹钟，以确保定时闹钟正常工作。';
    } catch (e) {
      return '触发失败: $e';
    }
  }

  Future<void> _scheduleNotification(Alarm alarm) async {
    if (_notificationsPlugin == null || !alarm.enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      '闹钟提醒',
      channelDescription: '闹钟提醒通知',
      importance: Importance.high,
      priority: Priority.high,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final scheduledDate = tz.TZDateTime.from(alarm.alarmTime, tz.local);
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
      if (alarm.repeatPattern != null) {
        final tomorrow = scheduledDate.add(const Duration(days: 1));
        await _zonedScheduleWithFallback(alarm, tomorrow, details);
      }
      return;
    }

    await _zonedScheduleWithFallback(alarm, scheduledDate, details);
  }

  /// 使用 alarmClock 调度（AlarmManager.setAlarmClock），
  /// 这是 Android 闹钟专用 API，无需 SCHEDULE_EXACT_ALARM 权限，
  /// 且在国内 ROM 上通常不会被拦截。
  /// 若失败则依次回退 exactAllowWhileIdle → inexactAllowWhileIdle。
  Future<void> _zonedScheduleWithFallback(
    Alarm alarm,
    tz.TZDateTime scheduledDate,
    NotificationDetails details,
  ) async {
    const modes = [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.exactAllowWhileIdle,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ];
    for (final mode in modes) {
      try {
        await _notificationsPlugin!.zonedSchedule(
          id: _notificationId(alarm),
          title: alarm.title,
          body: alarm.description ?? '闹钟提醒时间到了',
          scheduledDate: scheduledDate,
          notificationDetails: details,
          androidScheduleMode: mode,
          matchDateTimeComponents: _getRepeatComponent(alarm.repeatPattern),
        );
        debugPrint('闹钟 "${alarm.title}" 已使用 $mode 调度于 $scheduledDate');
        return;
      } catch (e) {
        debugPrint('$mode 调度失败: $e');
      }
    }
    debugPrint('所有调度模式均失败，闹钟 "${alarm.title}" 无法触发');
  }

  DateTimeComponents? _getRepeatComponent(String? repeatPattern) {
    switch (repeatPattern) {
      case '每天':
        return DateTimeComponents.time;
      case '每周':
        return DateTimeComponents.dayOfWeekAndTime;
      case '每月':
        return DateTimeComponents.dayOfMonthAndTime;
      default:
        return null;
    }
  }
}
