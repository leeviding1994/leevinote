import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/screens/notes_screen.dart';
import 'package:leevinote/screens/alarms_screen.dart';
import 'package:leevinote/screens/music_screen.dart';
import 'package:leevinote/screens/videos_screen.dart';
import 'package:leevinote/screens/schedules_screen.dart';
import 'package:leevinote/services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const NotesScreen(),
    const AlarmsScreen(),
    const MusicScreen(),
    const VideosScreen(),
    const SchedulesScreen(),
  ];

  final List<String> _titles = [
    '笔记',
    '闹钟',
    '音乐',
    '视频',
    '日程',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthService>().logout();
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.note), label: '笔记'),
          NavigationDestination(icon: Icon(Icons.alarm), label: '闹钟'),
          NavigationDestination(icon: Icon(Icons.music_note), label: '音乐'),
          NavigationDestination(icon: Icon(Icons.video_library), label: '视频'),
          NavigationDestination(icon: Icon(Icons.calendar_today), label: '日程'),
        ],
      ),
    );
  }
}
