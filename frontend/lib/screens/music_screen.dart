import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:leevinote/design/app_theme.dart';
import 'package:leevinote/models/music.dart';
import 'package:leevinote/services/music_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/widgets/widgets.dart';
import 'login_screen.dart';

class MusicScreen extends StatefulWidget {
  const MusicScreen({super.key});

  @override
  State<MusicScreen> createState() => MusicScreenState();
}

class MusicScreenState extends State<MusicScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MusicService>().load();
    });
  }

  Future<void> sync() async {
    final musicService = context.read<MusicService>();
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        AppPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    if (!mounted) return;
    final success = await musicService.sync();
    if (mounted) {
      if (success) {
        AppToast.success(context, '音乐同步完成');
      } else {
        AppToast.error(context, '同步失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicService = context.watch<MusicService>();

    return AppScaffold.noPadding(
      body: musicService.loading
          ? const Center(child: CircularProgressIndicator())
          : musicService.musicList.isEmpty
              ? _buildEmptyState()
              : _buildMusicList(musicService),
    );
  }

  Widget _buildEmptyState() {
    return const AppEmptyState(
      icon: Icons.music_note,
      title: '暂无音乐',
      subtitle: '点击右下角按钮添加',
    );
  }

  Widget _buildMusicList(MusicService service) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.pageHorizontal),
            itemCount: service.musicList.length,
            itemBuilder: (context, index) {
              final music = service.musicList[index];
              return AnimatedListItem(
                index: index,
                child: Padding(
                  padding:
                      const EdgeInsets.only(bottom: AppSpacing.listItemGap),
                  child: _buildMusicCard(music, service),
                ),
              );
            },
          ),
        ),
        if (service.currentTrack != null) _buildPlayerBar(service),
      ],
    );
  }

  Widget _buildMusicCard(Music music, MusicService service) {
    final isCurrent = service.currentTrack?.localId == music.localId;

    return AppCard(
      onTap: () => service.play(music),
      shadows: isCurrent ? AppShadows.light : const [],
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isCurrent
                  ? Theme.of(context).colorScheme.primaryContainer
                  : AppColors.surfaceSecondary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              isCurrent && service.playing ? Icons.pause : Icons.music_note,
              color: isCurrent
                  ? Theme.of(context).colorScheme.primary
                  : AppColors.tertiaryText,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  music.title,
                  style: AppTypography.bodyMediumLight(
                    color: isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${music.artist ?? '未知艺术家'} · ${music.durationFormatted}',
                  style: AppTypography.smallLight(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppIconButton(
            icon: isCurrent && service.playing ? Icons.pause : Icons.play_arrow,
            onPressed: () => service.play(music),
          ),
          AppIconButton(
            icon: Icons.delete_outline,
            onPressed: () => _confirmDelete(music, service),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Music music, MusicService service) {
    AppDialog.confirm(
      context: context,
      title: '删除音乐',
      content: '确定删除"${music.title}"吗？',
      confirmLabel: '删除',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true) service.deleteMusic(music.localId);
    });
  }

  Widget _buildPlayerBar(MusicService service) {
    final track = service.currentTrack!;
    final pos = service.position;
    final dur = service.duration;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.md,
        AppSpacing.pageHorizontal,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppShadows.light,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.title,
            style: AppTypography.bodyMediumLight(),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Slider(
            value: dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0,
            onChanged: (v) {
              final newPos =
                  Duration(milliseconds: (v * dur.inMilliseconds).round());
              service.seek(newPos);
            },
            activeColor: Theme.of(context).colorScheme.primary,
            inactiveColor: AppColors.border,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(pos),
                    style: AppTypography.smallMediumLight()),
                Text(_formatDuration(dur),
                    style: AppTypography.smallMediumLight()),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIconButton(
                icon: Icons.stop,
                onPressed: () => service.stop(),
              ),
              const SizedBox(width: AppSpacing.lg),
              AppIconButton(
                iconSize: 40,
                icon: service.playing
                    ? Icons.pause_circle_filled
                    : Icons.play_circle_filled,
                onPressed: () => service.play(track),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> openAddMusic() {
    return _pickAndAddMusic();
  }

  Future<void> _pickAndAddMusic() async {
    final musicService = context.read<MusicService>();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a'],
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final name = file.name;
      final title = name.replaceAll(RegExp(r'\.[^.]+$'), '');

      final music = Music(
        title: title,
        fileUrl: file.path!,
        duration: file.size > 0 ? file.size : null,
      );

      if (!mounted) return;
      await musicService.createMusic(music);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加音乐失败: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
