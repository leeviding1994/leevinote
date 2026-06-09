import 'package:flutter/foundation.dart';
import 'package:leevinote/models/schedule.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_schedule_service.dart';
import 'package:leevinote/utils/constants.dart';

class ScheduleService extends ChangeNotifier {
  final ApiService _api;
  final LocalScheduleService _local;
  List<Schedule> _schedules = [];
  bool _loading = false;
  bool _syncing = false;

  ScheduleService(this._api, this._local);

  List<Schedule> get schedules => _schedules;
  bool get loading => _loading;
  bool get syncing => _syncing;

  Map<DateTime, List<Schedule>> get schedulesByDate {
    final map = <DateTime, List<Schedule>>{};
    for (final s in _schedules) {
      final dateKey = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      map.putIfAbsent(dateKey, () => []).add(s);
    }
    return map;
  }

  List<Schedule> getSchedulesForDate(DateTime date) {
    final dateKey = DateTime(date.year, date.month, date.day);
    return schedulesByDate[dateKey] ?? [];
  }

  List<Schedule> getSchedulesForRange(DateTime start, DateTime end) {
    return _schedules.where((s) {
      return !s.startTime.isAfter(end) && !s.endTime.isBefore(start);
    }).toList();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();
      _schedules = List.from(_local.schedules);
    } catch (e) {
      debugPrint('Failed to load local schedules: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchSchedules() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getList(ApiConstants.schedules);
      final remoteSchedules = data
          .map((e) => Schedule.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final rs in remoteSchedules) {
        await _local.addOrUpdateFromRemote(rs);
      }
      _schedules = List.from(_local.schedules);
    } catch (e) {
      debugPrint('Failed to fetch schedules, using local data: $e');
      _schedules = List.from(_local.schedules);
    }
    _loading = false;
    notifyListeners();
  }

  Future<Schedule?> createSchedule(Schedule schedule) async {
    final localSchedule = schedule.copyWith(syncStatus: 'local');
    await _local.addSchedule(localSchedule);
    _schedules.insert(0, localSchedule);
    _schedules.sort((a, b) => a.startTime.compareTo(b.startTime));
    notifyListeners();
    return localSchedule;
  }

  Future<void> deleteSchedule(String localId) async {
    final schedule = _schedules.firstWhere(
      (s) => s.localId == localId,
      orElse: () => Schedule(title: '', startTime: DateTime.now(), endTime: DateTime.now()),
    );
    if (schedule.id != null) {
      final updated = schedule.copyWith(syncStatus: 'deleted');
      await _local.updateSchedule(updated);
      final index = _schedules.indexWhere((s) => s.localId == localId);
      if (index != -1) _schedules[index] = updated;
    } else {
      await _local.deleteSchedule(localId);
      _schedules.removeWhere((s) => s.localId == localId);
    }
    notifyListeners();
  }

  Future<bool> sync() async {
    _syncing = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();

      for (final schedule in List.from(_local.schedules)) {
        if (schedule.syncStatus == 'deleted' && schedule.id != null) {
          try {
            await _api.delete('${ApiConstants.schedules}/${schedule.id}');
            await _local.deleteSchedule(schedule.localId);
          } catch (_) {}
        } else if (schedule.syncStatus == 'local' || schedule.syncStatus == 'modified') {
          try {
            final result = await _api.post(ApiConstants.schedules, schedule.toRemoteJson());
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateSchedule(schedule.copyWith(
              id: newId,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.schedules);
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final schedule in List.from(_local.schedules)) {
        if (schedule.id != null && schedule.syncStatus == 'synced' && !remoteIds.contains(schedule.id)) {
          await _local.deleteSchedule(schedule.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Schedule.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote);
      }

      _schedules = List.from(_local.schedules);
      _syncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Schedule sync failed: $e');
      _syncing = false;
      notifyListeners();
      return false;
    }
  }
}
