import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
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
import 'package:leevinote/services/settings_service.dart';
import 'package:leevinote/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await windowManager.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final savedWidth = prefs.getDouble('window_width');
    final savedHeight = prefs.getDouble('window_height');

    WindowOptions windowOptions = const WindowOptions(
      size: Size(1200, 800),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      if (savedWidth != null && savedHeight != null) {
        await windowManager.setSize(Size(savedWidth, savedHeight));
      }
    });

    windowManager.addListener(_WindowSizeListener());
  }

  final apiService = ApiService();
  final settings = SettingsService(apiService: apiService);
  await settings.ensureLoaded();

  FlutterError.onError = (details) {
    final errorStr = details.exception.toString();
    if (errorStr.contains('hardware_keyboard.dart') &&
        errorStr.contains('_pressedKeys.containsKey')) {
      return;
    }
    if (errorStr.contains('RenderFlex overflowed')) {
      return;
    }
    debugPrint('FlutterError: ${details.exception}\n${details.stack}');
  };

  PlatformDispatcher.instance.onError = (exception, stack) {
    final errorStr = exception.toString();
    if (errorStr.contains('hardware_keyboard.dart') &&
        errorStr.contains('_pressedKeys.containsKey')) {
      return true;
    }
    if (errorStr.contains('RenderFlex overflowed')) {
      return true;
    }
    debugPrint('Unhandled exception: $exception\n$stack');
    return true;
  };

  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Container();
  };

  runApp(LeevinoteApp(settings: settings));
}

class _WindowSizeListener extends WindowListener {
  @override
  void onWindowResize() async {
    final size = await windowManager.getSize();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  }
}

class LeevinoteApp extends StatelessWidget {
  final SettingsService settings;
  const LeevinoteApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService(onLogin: () async { await settings.syncFromServer(); })),
        ChangeNotifierProvider.value(value: settings),
        Provider(create: (_) => ApiService()),
        ChangeNotifierProvider(create: (_) => LocalNoteService()),
        ChangeNotifierProvider(create: (_) => LocalFolderService()),
        ChangeNotifierProvider(create: (_) => LocalAlarmService()),
        ChangeNotifierProvider(create: (_) => LocalMusicService()),
        ChangeNotifierProvider(create: (_) => LocalVideoService()),
        ChangeNotifierProvider(create: (_) => LocalScheduleService()),
        ChangeNotifierProvider(create: (_) => HolidayService()),
        ChangeNotifierProvider(create: (context) => AlarmService(context.read<ApiService>(), context.read<LocalAlarmService>(), holidayService: context.read<HolidayService>())),
        ChangeNotifierProvider(create: (context) => MusicService(context.read<ApiService>(), context.read<LocalMusicService>())),
        ChangeNotifierProvider(create: (context) => VideoService(context.read<ApiService>(), context.read<LocalVideoService>())),
        ChangeNotifierProvider(create: (context) => ScheduleService(context.read<ApiService>(), context.read<LocalScheduleService>())),
      ],
      child: Builder(
        builder: (context) {
          final settings = context.watch<SettingsService>();
          return MaterialApp(
            title: 'LeeviNote',
            theme: AppTheme.lightTheme(seedColor: settings.themeColor),
            darkTheme: AppTheme.darkTheme(seedColor: settings.themeColor),
            themeMode: settings.flutterThemeMode,
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
          );
        },
      ),
    );
  }
}
