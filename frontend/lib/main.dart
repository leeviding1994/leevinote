import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/screens/home_screen.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/services/local_note_service.dart';
import 'package:leevinote/services/local_folder_service.dart';
import 'package:leevinote/services/alarm_service.dart';
import 'package:leevinote/services/music_service.dart';
import 'package:leevinote/services/schedule_service.dart';
import 'package:leevinote/services/holiday_service.dart';
import 'package:leevinote/services/local_alarm_service.dart';
import 'package:leevinote/services/local_music_service.dart';
import 'package:leevinote/services/local_video_service.dart';
import 'package:leevinote/services/local_schedule_service.dart';
import 'package:leevinote/services/video_service.dart';
import 'package:leevinote/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (exception, stack) {
    debugPrint('Unhandled exception: $exception\n$stack');
    return true;
  };

  runApp(const LeevinoteApp());
}

class LeevinoteApp extends StatelessWidget {
  const LeevinoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LocalNoteService()),
        ChangeNotifierProvider(create: (_) => LocalFolderService()),
        ChangeNotifierProvider(create: (_) => LocalAlarmService()),
        ChangeNotifierProvider(create: (_) => LocalMusicService()),
        ChangeNotifierProvider(create: (_) => LocalVideoService()),
        ChangeNotifierProvider(create: (_) => LocalScheduleService()),
        ChangeNotifierProvider(create: (context) => AlarmService(context.read<ApiService>(), context.read<LocalAlarmService>())),
        ChangeNotifierProvider(create: (context) => MusicService(context.read<ApiService>(), context.read<LocalMusicService>())),
        ChangeNotifierProvider(create: (context) => VideoService(context.read<ApiService>(), context.read<LocalVideoService>())),
        ChangeNotifierProvider(create: (context) => ScheduleService(context.read<ApiService>(), context.read<LocalScheduleService>())),
        ChangeNotifierProvider(create: (_) => HolidayService()),
      ],
      child: MaterialApp(
        title: 'Leevinote',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
