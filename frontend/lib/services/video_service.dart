import 'package:flutter/foundation.dart';
import 'package:leevinote/models/video.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_video_service.dart';
import 'package:leevinote/utils/constants.dart';

class VideoService extends ChangeNotifier {
  final ApiService _api;
  final LocalVideoService _local;
  List<Video> _videoList = [];
  bool _loading = false;
  bool _syncing = false;

  VideoService(this._api, this._local);

  List<Video> get videoList => _videoList;
  bool get loading => _loading;
  bool get syncing => _syncing;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();
      _videoList = List.from(_local.videoList);
    } catch (e) {
      debugPrint('Failed to load local videos: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchVideos() async {
    _loading = true;
    notifyListeners();
    try {
      final data = await _api.getList(ApiConstants.videos);
      final remoteList = data
          .map((e) => Video.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced'))
          .toList();
      for (final rm in remoteList) {
        await _local.addOrUpdateFromRemote(rm);
      }
      _videoList = List.from(_local.videoList);
    } catch (e) {
      debugPrint('Failed to fetch videos, using local data: $e');
      _videoList = List.from(_local.videoList);
    }
    _loading = false;
    notifyListeners();
  }

  Future<Video?> createVideo(Video video) async {
    final localVideo = video.copyWith(syncStatus: 'local');
    await _local.addVideo(localVideo);
    _videoList.insert(0, localVideo);
    notifyListeners();
    return localVideo;
  }

  Future<void> deleteVideo(String localId) async {
    final video = _videoList.firstWhere(
      (m) => m.localId == localId,
      orElse: () => Video(title: '', fileUrl: ''),
    );
    if (video.id != null) {
      final updated = video.copyWith(syncStatus: 'deleted');
      await _local.updateVideo(updated);
      final index = _videoList.indexWhere((m) => m.localId == localId);
      if (index != -1) _videoList[index] = updated;
    } else {
      await _local.deleteVideo(localId);
      _videoList.removeWhere((m) => m.localId == localId);
    }
    notifyListeners();
  }

  Future<bool> sync() async {
    _syncing = true;
    notifyListeners();
    try {
      await _local.ensureLoaded();

      for (final video in List.from(_local.videoList)) {
        if (video.syncStatus == 'deleted' && video.id != null) {
          try {
            await _api.delete('${ApiConstants.videos}/${video.id}');
            await _local.deleteVideo(video.localId);
          } catch (_) {}
        } else if (video.syncStatus == 'local' || video.syncStatus == 'modified') {
          try {
            final result = await _api.post(ApiConstants.videos, video.toRemoteJson());
            final remoteId = result['id'];
            final newId = remoteId is int
                ? remoteId
                : int.tryParse(remoteId?.toString() ?? '');
            await _local.updateVideo(video.copyWith(
              id: newId,
              syncStatus: 'synced',
            ));
          } catch (_) {}
        }
      }

      final remoteData = await _api.getList(ApiConstants.videos);
      final remoteIds = remoteData.map((e) => (e as Map)['id'] as int?).whereType<int>().toSet();
      for (final video in List.from(_local.videoList)) {
        if (video.id != null && video.syncStatus == 'synced' && !remoteIds.contains(video.id)) {
          await _local.deleteVideo(video.localId);
        }
      }
      for (final e in remoteData) {
        final remote = Video.fromJson(e as Map<String, dynamic>).copyWith(syncStatus: 'synced');
        await _local.addOrUpdateFromRemote(remote);
      }

      _videoList = List.from(_local.videoList);
      _syncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Video sync failed: $e');
      _syncing = false;
      notifyListeners();
      return false;
    }
  }
}
