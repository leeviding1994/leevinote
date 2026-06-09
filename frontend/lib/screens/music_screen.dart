import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:leevinote/models/music.dart';
import 'package:leevinote/services/music_service.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/screens/login_screen.dart';

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
    final auth = context.read<AuthService>();
    if (!auth.isAuthenticated) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      if (loggedIn != true) return;
    }
    final success = await context.read<MusicService>().sync();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '音乐同步完成' : '同步失败'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final musicService = context.watch<MusicService>();

    return Scaffold(
      body: musicService.loading
          ? const Center(child: CircularProgressIndicator())
          : musicService.musicList.isEmpty
              ? _buildEmptyState()
              : _buildMusicList(musicService),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _pickAndAddMusic(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('暂无音乐', style: TextStyle(color: Colors.grey, fontSize: 16)),
          SizedBox(height: 8),
          Text('点击右下角按钮添加', style: TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildMusicList(MusicService service) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: service.musicList.length,
            itemBuilder: (context, index) {
              final music = service.musicList[index];
              return _buildMusicCard(music, service);
            },
          ),
        ),
        if (service.currentTrack != null) _buildPlayerBar(service),
      ],
    );
  }

  Widget _buildMusicCard(Music music, MusicService service) {
    final isCurrent = service.currentTrack?.localId == music.localId;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isCurrent ? 2 : 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCurrent
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.grey.shade200,
          child: Icon(
            isCurrent && service.playing ? Icons.play_arrow : Icons.music_note,
            color: isCurrent
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
        title: Text(
          music.title,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isCurrent ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        subtitle: Text(
          '${music.artist ?? '未知艺术家'}  ·  ${music.durationFormatted}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isCurrent && service.playing ? Icons.pause : Icons.play_arrow,
              ),
              onPressed: () => service.play(music),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除音乐'),
                    content: Text('确定删除"${music.title}"吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () {
                          service.deleteMusic(music.localId);
                          Navigator.pop(ctx);
                        },
                        child: const Text('确定', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        onTap: () => service.play(music),
      ),
    );
  }

  Widget _buildPlayerBar(MusicService service) {
    final track = service.currentTrack!;
    final pos = service.position;
    final dur = service.duration;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            track.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Slider(
            value: dur.inMilliseconds > 0
                ? pos.inMilliseconds / dur.inMilliseconds
                : 0.0,
            onChanged: (v) {
              final newPos = Duration(milliseconds: (v * dur.inMilliseconds).round());
              service.seek(newPos);
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(pos), style: const TextStyle(fontSize: 12)),
                Text(_formatDuration(dur), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.stop),
                onPressed: () => service.stop(),
              ),
              const SizedBox(width: 16),
              IconButton(
                iconSize: 40,
                icon: Icon(
                  service.playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                ),
                onPressed: () => service.play(track),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndAddMusic(BuildContext context) async {
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

      await context.read<MusicService>().createMusic(music);
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
