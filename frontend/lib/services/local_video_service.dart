import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:leevinote/models/video.dart';

class LocalVideoService extends ChangeNotifier {
  List<Video> _videoList = [];
  bool _loaded = false;

  List<Video> get videoList => _videoList;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await _load();
    _loaded = true;
  }

  String get _key => 'local_video';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_key) ?? '[]';
      final list = jsonDecode(json) as List;
      _videoList = list.map((e) => Video.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      _videoList = [];
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = jsonEncode(_videoList.map((m) => m.toJson()).toList());
      await prefs.setString(_key, json);
    } catch (_) {}
  }

  Future<void> addVideo(Video video) async {
    await ensureLoaded();
    _videoList.insert(0, video);
    await _persist();
    notifyListeners();
  }

  Future<void> updateVideo(Video video) async {
    await ensureLoaded();
    final index = _videoList.indexWhere((m) => m.localId == video.localId);
    if (index != -1) {
      _videoList[index] = video;
      await _persist();
      notifyListeners();
    }
  }

  Future<void> deleteVideo(String localId) async {
    await ensureLoaded();
    _videoList.removeWhere((m) => m.localId == localId);
    await _persist();
    notifyListeners();
  }

  Future<Video?> getVideo(String localId) async {
    await ensureLoaded();
    try {
      return _videoList.firstWhere((m) => m.localId == localId);
    } catch (_) {
      return null;
    }
  }

  Future<void> replaceAll(List<Video> list) async {
    _videoList = List.from(list);
    await _persist();
    notifyListeners();
  }

  Future<void> addOrUpdateFromRemote(Video remote) async {
    await ensureLoaded();
    final i = _videoList.indexWhere((m) => m.id != null && m.id == remote.id);
    if (i != -1) {
      final existing = _videoList[i];
      _videoList[i] = remote.copyWith(localId: existing.localId);
    } else {
      _videoList.add(remote);
    }
    await _persist();
    notifyListeners();
  }
}
