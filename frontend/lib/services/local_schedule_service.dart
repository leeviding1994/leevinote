import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/schedule.dart';

class LocalScheduleService extends ChangeNotifier {
  List<Schedule> _schedules = [];
  bool _loaded = false;

  List<Schedule> get schedules => _schedules;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_schedules';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _schedules = list.map((e) => Schedule.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _schedules = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_schedules.map((s) => s.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addSchedule(Schedule schedule) async {
    await ensureLoaded();
    _schedules.insert(0, schedule);
    await _persist();
    notifyListeners();
  }

  Future<void> updateSchedule(Schedule schedule) async {
    await ensureLoaded();
    final index = _schedules.indexWhere((s) => s.localId == schedule.localId);
    if (index != -1) {
      _schedules[index] = schedule;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteSchedule(String localId) async {
    await ensureLoaded();
    _schedules.removeWhere((s) => s.localId == localId);
    await _persist();
    notifyListeners();
  }

  Future<Schedule?> getSchedule(String localId) async {
    await ensureLoaded();
    try {
      return _schedules.firstWhere((s) => s.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<Schedule> schedules) async {
    _schedules = List.from(schedules);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Schedule remote) async {
    await ensureLoaded();
    final i = _schedules.indexWhere((s) => s.id != null && s.id == remote.id);
    if (i != -1) {
      final existing = _schedules[i];
      _schedules[i] = remote.copyWith(localId: existing.localId);
    } else {
      _schedules.add(remote);
    }
    await _persist();
    notifyListeners();
  }
}
