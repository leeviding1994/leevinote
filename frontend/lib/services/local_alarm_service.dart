import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/alarm.dart';

class LocalAlarmService extends ChangeNotifier {
  List<Alarm> _alarms = [];
  bool _loaded = false;

  List<Alarm> get alarms => _alarms;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_alarms';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _alarms = list.map((e) => Alarm.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _alarms = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_alarms.map((a) => a.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addAlarm(Alarm alarm) async {
    await ensureLoaded();
    _alarms.insert(0, alarm);
    await _persist();
    notifyListeners();
  }

  Future<void> updateAlarm(Alarm alarm) async {
    await ensureLoaded();
    final index = _alarms.indexWhere((a) => a.localId == alarm.localId);
    if (index != -1) {
      _alarms[index] = alarm;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteAlarm(String localId) async {
    await ensureLoaded();
    _alarms.removeWhere((a) => a.localId == localId);
    await _persist();
    notifyListeners();
  }

  Future<Alarm?> getAlarm(String localId) async {
    await ensureLoaded();
    try {
      return _alarms.firstWhere((a) => a.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<Alarm> alarms) async {
    _alarms = List.from(alarms);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Alarm remote) async {
    await ensureLoaded();
    final i = _alarms.indexWhere((a) => a.id != null && a.id == remote.id);
    if (i != -1) {
      final existing = _alarms[i];
      _alarms[i] = remote.copyWith(localId: existing.localId);
    } else {
      _alarms.add(remote);
    }
    await _persist();
    notifyListeners();
  }
}
