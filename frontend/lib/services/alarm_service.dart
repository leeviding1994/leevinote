import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:leevinote/models/alarm.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_alarm_service.dart';
import 'package:leevinote/services/holiday_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class AlarmService extends ChangeNotifier {
  final ApiService _api;
  final LocalAlarmService _local;
  HolidayService? _holidayService;
  List<Alarm> _alarms = [];
  bool _loading = false;
  bool _syncing = false;
  FlutterLocalNotificationsPlugin? _notificationsPlugin;
  bool _initialized = false;
  final Map<String, Timer> _desktopTimers = {};

  AlarmService(this._api, this._local, {HolidayService? holidayService})
      : _holidayService = holidayService;

  /// Linux has no OS-level scheduled notifications; fire while the app process
  /// is alive via Dart timers + notification show().
  bool get _usesInAppScheduler => defaultTargetPlatform == TargetPlatform.linux;

  void setHolidayService(HolidayService service) {
    _holidayService = service;
  }

  List<Alarm> get alarms => _alarms;
  bool get loading => _loading;
  bool get syncing => _syncing;
  bool get initialized => _initialized;

  int _notificationId(Alarm alarm) => alarm.localId.hashCode & 0x7FFFFFFF;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      // 设置本地时区为中国东八区（避免 tz.local 默认为 UTC）
      tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));

      _notificationsPlugin = FlutterLocalNotificationsPlugin();

      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
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

      // Request Android permissions and create notification channel
      if (defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _notificationsPlugin!
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          // 1. 删除旧渠道并创建新渠道（Android 渠道一旦创建属性不可更改，必须换 ID）
          await androidPlugin.deleteNotificationChannel(
              channelId: 'alarm_channel');
          const channel = AndroidNotificationChannel(
            'alarm_channel_v2',
            '闹钟提醒',
            description: '闹钟提醒通知',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          );
          await androidPlugin.createNotificationChannel(channel);

          // 2. 请求通知权限（Android 13+）
          final granted = await androidPlugin.requestNotificationsPermission();
          if (granted != true) {
            debugPrint('通知权限未授予，闹钟将无法正常显示');
          }

          // 3. 请求精确闹钟权限（Android 12+）
          // 若已声明 USE_EXACT_ALARM（Android 14 普通权限），通常无需请求。
          // 为兼容 Android 12/13，用 try-catch 避免阻塞整个初始化。
          try {
            await androidPlugin.requestExactAlarmsPermission();
          } catch (e) {
            debugPrint('精确闹钟权限请求被忽略或失败: $e');
          }
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
          .map((e) => Alarm.fromJson(e as Map<String, dynamic>)
              .copyWith(syncStatus: 'synced'))
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

  @override
  void dispose() {
    _cancelAllDesktopTimers();
    super.dispose();
  }

  Future<void> deleteAlarm(String localId) async {
    final alarm = _alarms.firstWhere(
      (a) => a.localId == localId,
      orElse: () => Alarm(title: '', alarmTime: DateTime.now()),
    );
    // Always cancel the local notification
    if (_initialized) {
      _cancelDesktopTimer(localId);
      await _notificationsPlugin?.cancel(id: _notificationId(alarm));
    }
    if (alarm.id != null) {
      // 已同步的闹钟：本地标记为删除（同步时上传到服务端），同时立即从列表移除
      final updated = alarm.copyWith(syncStatus: 'deleted');
      await _local.updateAlarm(updated);
    } else {
      // 未同步的闹钟：直接从本地删除
      await _local.deleteAlarm(localId);
    }
    _alarms.removeWhere((a) => a.localId == localId);
    notifyListeners();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    final updated = alarm.copyWith(
      syncStatus: alarm.id != null ? 'modified' : 'local',
    );
    await _local.updateAlarm(updated);
    final index = _alarms.indexWhere((a) => a.localId == alarm.localId);
    if (index != -1) _alarms[index] = updated;
    notifyListeners();
    if (_initialized && updated.enabled) {
      _cancelDesktopTimer(updated.localId);
      await _notificationsPlugin?.cancel(id: _notificationId(updated));
      await _scheduleNotification(updated);
    } else if (_initialized && !updated.enabled) {
      _cancelDesktopTimer(updated.localId);
      await _notificationsPlugin?.cancel(id: _notificationId(updated));
    }
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
        _cancelDesktopTimer(updated.localId);
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
        } else if (alarm.syncStatus == 'local' ||
            alarm.syncStatus == 'modified') {
          try {
            final result = alarm.id == null
                ? await _api.post(ApiConstants.alarms, alarm.toRemoteJson())
                : await _api.put(
                    '${ApiConstants.alarms}/${alarm.id}',
                    alarm.toRemoteJson(),
                  );
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateAlarm(alarm.copyWith(
              id: newId ?? alarm.id,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.alarms);
      final remoteIds = remoteData
          .map((e) => (e as Map)['id'] as int?)
          .whereType<int>()
          .toSet();
      for (final alarm in List.from(_local.alarms)) {
        if (alarm.id != null &&
            alarm.syncStatus == 'synced' &&
            !remoteIds.contains(alarm.id)) {
          await _local.deleteAlarm(alarm.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Alarm.fromJson(e as Map<String, dynamic>)
            .copyWith(syncStatus: 'synced');
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

  Future<void> _scheduleNotification(Alarm alarm) async {
    if (_notificationsPlugin == null || !alarm.enabled) return;

    const androidDetails = AndroidNotificationDetails(
      'alarm_channel_v2',
      '闹钟提醒',
      channelDescription: '闹钟提醒通知',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
      playSound: true,
      enableVibration: true,
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const linuxDetails = LinuxNotificationDetails(
      urgency: LinuxNotificationUrgency.critical,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    // 计算下一个触发时间
    final nextDate = _calculateNextTriggerDate(alarm);
    if (nextDate == null) {
      debugPrint('闹钟 "${alarm.title}" 无法计算下一个触发时间，自动禁用');
      final updated = alarm.copyWith(
          enabled: false, syncStatus: alarm.id != null ? 'modified' : 'local');
      await _local.updateAlarm(updated);
      final index = _alarms.indexWhere((a) => a.localId == alarm.localId);
      if (index != -1) _alarms[index] = updated;
      notifyListeners();
      return;
    }

    final now = tz.TZDateTime.now(tz.local);
    debugPrint('闹钟 "${alarm.title}" 下次触发: $nextDate, 当前时间: $now');

    // Linux 原生通知 API 不支持 zonedSchedule，改用应用内 Timer。
    if (_usesInAppScheduler) {
      await _scheduleWithDesktopTimer(alarm, nextDate, details);
      return;
    }

    await _zonedScheduleWithFallback(alarm, nextDate, details);
  }

  Future<void> _scheduleWithDesktopTimer(
    Alarm alarm,
    tz.TZDateTime scheduledDate,
    NotificationDetails details,
  ) async {
    _cancelDesktopTimer(alarm.localId);
    final now = tz.TZDateTime.now(tz.local);
    var delay = scheduledDate.difference(now);
    if (delay.isNegative) {
      delay = Duration.zero;
    }

    _desktopTimers[alarm.localId] = Timer(delay, () async {
      _desktopTimers.remove(alarm.localId);
      if (_notificationsPlugin == null) return;

      Alarm? matched;
      for (final item in _alarms) {
        if (item.localId == alarm.localId) {
          matched = item;
          break;
        }
      }
      if (matched == null || !matched.enabled) return;
      final active = matched;

      try {
        await _notificationsPlugin!.show(
          id: _notificationId(active),
          title: active.title,
          body: active.description ?? '闹钟提醒时间到了',
          notificationDetails: details,
        );
        debugPrint('桌面闹钟 "${active.title}" 已触发通知');
      } catch (e) {
        debugPrint('桌面闹钟通知显示失败: $e');
      }

      final isOneShot =
          active.repeatPattern == null || active.repeatPattern == '单次';
      if (isOneShot) {
        final disabled = active.copyWith(
          enabled: false,
          syncStatus: active.id != null ? 'modified' : 'local',
        );
        await _local.updateAlarm(disabled);
        final index = _alarms.indexWhere((a) => a.localId == active.localId);
        if (index != -1) _alarms[index] = disabled;
        notifyListeners();
        return;
      }

      // 重复闹钟：触发后安排下一次。
      await Future<void>.delayed(const Duration(seconds: 1));
      Alarm? latest;
      for (final item in _alarms) {
        if (item.localId == active.localId) {
          latest = item;
          break;
        }
      }
      if (latest != null && latest.enabled) {
        await _scheduleNotification(latest);
      }
    });

    debugPrint(
      '桌面闹钟 "${alarm.title}" 已用应用内定时器调度，'
      '将在 ${delay.inSeconds} 秒后触发（应用需保持运行）',
    );
  }

  void _cancelDesktopTimer(String localId) {
    _desktopTimers.remove(localId)?.cancel();
  }

  void _cancelAllDesktopTimers() {
    for (final timer in _desktopTimers.values) {
      timer.cancel();
    }
    _desktopTimers.clear();
  }

  tz.TZDateTime? _calculateNextTriggerDate(Alarm alarm) {
    final now = tz.TZDateTime.now(tz.local);
    final baseTime = tz.TZDateTime.from(alarm.alarmTime, tz.local);
    final today = tz.TZDateTime.from(
        DateTime(now.year, now.month, now.day, baseTime.hour, baseTime.minute),
        tz.local);

    switch (alarm.repeatPattern) {
      case '单次':
        // 如果今天时间已过，则明天触发
        if (today.isBefore(now)) {
          return today.add(const Duration(days: 1));
        }
        return today;
      case '节假日':
        // 节假日：需要检查是否是节假日
        if (_holidayService == null) return null;
        // 从明天开始查找下一个节假日
        for (int i = 1; i <= 365; i++) {
          final date = today.add(Duration(days: i));
          if (_holidayService!.isHoliday(date)) {
            return date;
          }
        }
        return null;
      case '工作日':
        // 工作日：周一到周五
        for (int i = 0; i <= 7; i++) {
          final date = today.add(Duration(days: i));
          if (date.weekday >= DateTime.monday &&
              date.weekday <= DateTime.friday) {
            if (date.isAfter(now) || (i == 0 && !today.isBefore(now))) {
              return date;
            }
          }
        }
        return null;
      case '自定义':
        // 自定义周几
        if (alarm.weekDays.isEmpty) return null;
        for (int i = 0; i <= 7; i++) {
          final date = today.add(Duration(days: i));
          // weekday: 1=Monday, 7=Sunday
          if (alarm.weekDays.contains(date.weekday)) {
            if (date.isAfter(now) || (i == 0 && !today.isBefore(now))) {
              return date;
            }
          }
        }
        return null;
      default:
        // 兼容旧的 null 单次闹钟
        if (today.isBefore(now)) {
          return today.add(const Duration(days: 1));
        }
        return today;
    }
  }

  /// 使用 alarmClock 调度（AlarmManager.setAlarmClock）。
  /// Android 14 已声明 USE_EXACT_ALARM 普通权限，setAlarmClock 可直接使用。
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
