import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/video.dart';
import 'package:leevinote/services/video_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';

class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => VideosScreenState();
}

class VideosScreenState extends State<VideosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VideoService>().load();
    });
  }

  Future<void> sync() async {
    final videoService = context.read<VideoService>();
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;
    final success = await videoService.sync();
    if (mounted) {
      if (success) {
        AppToast.success(context, '视频同步完成');
      } else {
        AppToast.error(context, '同步失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoService = context.watch<VideoService>();

    return AppScaffold.noPadding(
      body: videoService.loading
          ? const Center(child: CircularProgressIndicator())
          : videoService.videoList.isEmpty
              ? _buildEmptyState()
              : _buildVideoList(videoService),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.video_library,
      title: '暂无视频',
      subtitle: '点击右下角按钮添加',
    );
  }

  Widget _buildVideoList(VideoService service) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
      itemCount: service.videoList.length,
      itemBuilder: (context, index) {
        final video = service.videoList[index];
        return AnimatedListItem(
          index: index,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.listItemGap),
            child: _buildVideoCard(video, service),
          ),
        );
      },
    );
  }

  Widget _buildVideoCard(Video video, VideoService service) {
    return AppCard(
      onTap: () => _playVideo(context, video),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primaryText,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Center(
              child:
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.title,
                  style: AppTypography.bodyMediumLight(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${video.description ?? '无描述'} · ${video.durationFormatted}',
                  style: AppTypography.smallLight(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            onPressed: () => _confirmDelete(video, service),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Video video, VideoService service) {
    AppDialog.confirm(
      context: context,
      title: '删除视频',
      content: '确定删除"${video.title}"吗？',
      confirmLabel: '删除',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true) service.deleteVideo(video.localId);
    });
  }

  void _playVideo(BuildContext context, Video video) {
    Navigator.push(
      context,
      AppPageRoute(builder: (_) => _VideoPlayerScreen(video: video)),
    );
  }

  Future<void> openAddVideo() {
    return _pickAndAddVideo();
  }

  Future<void> _pickAndAddVideo() async {
    final videoService = context.read<VideoService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'avi',
          'mov',
          'mkv',
          'wmv',
          'flv',
          'webm',
          'm4v'
        ],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final name = file.name;
      final title = name.replaceAll(RegExp(r'\.[^.]+$'), '');

      final video = Video(
        title: title,
        fileUrl: file.path!,
        duration: file.size > 0 ? file.size : null,
      );

      if (!mounted) return;
      await videoService.createVideo(video);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加视频失败: $e')),
        );
      }
    }
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final Video video;

  const _VideoPlayerScreen({required this.video});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final url = widget.video.fileUrl;
    if (url.startsWith('http')) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      _videoController = VideoPlayerController.file(File(url));
    }

    await _videoController!.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController!,
      autoPlay: true,
      looping: false,
      fullScreenByDefault: false,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      showControls: true,
      showOptions: false,
      placeholder: Container(
        color: Colors.black,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: AppSpacing.md),
              Text('播放失败: $errorMessage',
                  style: AppTypography.bodyLight(color: Colors.white)),
            ],
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _initialized = true);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppAppBar(
        backgroundColor: Colors.black,
        titleWidget: Text(
          widget.video.title,
          style: AppTypography.bodyLight(color: Colors.white),
        ),
        leading: AppIconButton(
          icon: Icons.arrow_back,
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: _initialized && _chewieController != null
            ? Chewie(controller: _chewieController!)
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
