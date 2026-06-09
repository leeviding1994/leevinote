import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:leevinote/models/music.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_music_service.dart';
import 'package:leevinote/utils/constants.dart';
import 'package:just_audio/just_audio.dart';

class MusicService extends ChangeNotifier {
  final ApiService _api;
  final LocalMusicService _local;
  List<Music> _musicList = [];
  bool _loading = false;
  bool _syncing = false;

  final AudioPlayer _player = AudioPlayer();
  Music? _currentTrack;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _stateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _processingSub;

  MusicService(this._api, this._local);

  List<Music> get musicList => _musicList;
  bool get loading => _loading;
  bool get syncing => _syncing;

  AudioPlayer get player => _player;
  Music? get currentTrack => _currentTrack;
  bool get playing => _playing;
  Duration get position => _position;
  Duration get duration => _duration;

  void _onPlayerStateChanged(PlayerState state) {
    _playing = state.playing;
    notifyListeners();
  }

  void _onPositionChanged(Duration? pos) {
    _position = pos ?? Duration.zero;
    notifyListeners();
  }

  void _onDurationChanged(Duration? dur) {
    _duration = dur ?? Duration.zero;
    notifyListeners();
  }

  void _onPlayerComplete() {
    _currentTrack = null;
    _playing = false;
    _position = Duration.zero;
    notifyListeners();
  }

  void _cancelSubscriptions() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _processingSub?.cancel();
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();
      _musicList = List.from(_local.musicList);
    } catch (e) {
      debugPrint('Failed to load local music: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchMusic() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getList(ApiConstants.music);
      final remoteList = data
          .map((e) => Music.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final rm in remoteList) {
        await _local.addOrUpdateFromRemote(rm);
      }
      _musicList = List.from(_local.musicList);
    } catch (e) {
      debugPrint('Failed to fetch music, using local data: $e');
      _musicList = List.from(_local.musicList);
    }
    _loading = false;
    notifyListeners();
  }

  Future<Music?> createMusic(Music music) async {
    final localMusic = music.copyWith(syncStatus: 'local');
    await _local.addMusic(localMusic);
    _musicList.insert(0, localMusic);
    notifyListeners();
    return localMusic;
  }

  Future<void> deleteMusic(String localId) async {
    final music = _musicList.firstWhere(
      (m) => m.localId == localId,
      orElse: () => Music(title: '', fileUrl: ''),
    );
    if (music.id != null) {
      final updated = music.copyWith(syncStatus: 'deleted');
      await _local.updateMusic(updated);
      final index = _musicList.indexWhere((m) => m.localId == localId);
      if (index != -1) _musicList[index] = updated;
    } else {
      await _local.deleteMusic(localId);
      _musicList.removeWhere((m) => m.localId == localId);
    }

    if (_currentTrack?.localId == localId) {
      await stop();
    }
    notifyListeners();
  }

  Future<void> play(Music music) async {
    try {
      if (_currentTrack?.localId == music.localId && _playing) {
        await _player.pause();
        return;
      }
      if (_currentTrack?.localId == music.localId) {
        await _player.play();
        return;
      }

      _cancelSubscriptions();

      _stateSub = _player.playerStateStream.listen(_onPlayerStateChanged);
      _positionSub = _player.positionStream.listen(_onPositionChanged);
      _durationSub = _player.durationStream.listen(_onDurationChanged);
      _processingSub = _player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          _onPlayerComplete();
        }
      });

      await _player.setFilePath(music.fileUrl);
      _currentTrack = music;
      await _player.play();
    } catch (e) {
      debugPrint('Failed to play music: $e');
    }
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> stop() async {
    await _player.stop();
    _cancelSubscriptions();
    _currentTrack = null;
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Future<bool> sync() async {
    _syncing = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();

      for (final music in List.from(_local.musicList)) {
        if (music.syncStatus == 'deleted' && music.id != null) {
          try {
            await _api.delete('${ApiConstants.music}/${music.id}');
            await _local.deleteMusic(music.localId);
          } catch (_) {}
        } else if (music.syncStatus == 'local' || music.syncStatus == 'modified') {
          try {
            final result = await _api.post(ApiConstants.music, music.toRemoteJson());
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateMusic(music.copyWith(
              id: newId,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.music);
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final music in List.from(_local.musicList)) {
        if (music.id != null && music.syncStatus == 'synced' && !remoteIds.contains(music.id)) {
          await _local.deleteMusic(music.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Music.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote);
      }

      _musicList = List.from(_local.musicList);
      _syncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Music sync failed: $e');
      _syncing = false;
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    _player.dispose();
    super.dispose();
  }
}
