import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/music.dart';

class LocalMusicService extends ChangeNotifier {
  List<Music> _musicList = [];
  bool _loaded = false;

  List<Music> get musicList => _musicList;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_music';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _musicList = list.map((e) => Music.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _musicList = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_musicList.map((m) => m.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addMusic(Music music) async {
    await ensureLoaded();
    _musicList.insert(0, music);
    await _persist();
    notifyListeners();
  }

  Future<void> updateMusic(Music music) async {
    await ensureLoaded();
    final index = _musicList.indexWhere((m) => m.localId == music.localId);
    if (index != -1) {
      _musicList[index] = music;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteMusic(String localId) async {
    await ensureLoaded();
    _musicList.removeWhere((m) => m.localId == localId);
    await _persist();
    notifyListeners();
  }

  Future<Music?> getMusic(String localId) async {
    await ensureLoaded();
    try {
      return _musicList.firstWhere((m) => m.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<Music> list) async {
    _musicList = List.from(list);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Music remote) async {
    await ensureLoaded();
    final i = _musicList.indexWhere((m) => m.id != null && m.id == remote.id);
    if (i != -1) {
      final existing = _musicList[i];
      _musicList[i] = remote.copyWith(localId: existing.localId);
    } else {
      _musicList.add(remote);
    }
    await _persist();
    notifyListeners();
  }
}
