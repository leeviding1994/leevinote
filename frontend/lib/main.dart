import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:window_manager/window_manager.dart';
import 'package:leevinote/providers/note_editor_provider.dart';
import 'package:leevinote/screens/home_screen.dart';
import 'package:leevinote/screens/login_screen.dart';
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
import 'package:leevinote/services/local_transaction_service.dart';
import 'package:leevinote/services/local_transaction_category_service.dart';
import 'package:leevinote/services/transaction_service.dart';
import 'package:leevinote/services/transaction_category_service.dart';
import 'package:leevinote/services/settings_service.dart';
import 'package:leevinote/utils/theme.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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
  final localNoteService = LocalNoteService();
  final localFolderService = LocalFolderService();
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

  runApp(
    ProviderScope(
      overrides: [
        apiServiceProvider.overrideWithValue(apiService),
        localNoteServiceProvider.overrideWithValue(localNoteService),
        localFolderServiceProvider.overrideWithValue(localFolderService),
      ],
      child: LeevinoteApp(
        settings: settings,
        apiService: apiService,
        localNoteService: localNoteService,
        localFolderService: localFolderService,
      ),
    ),
  );
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
  final ApiService apiService;
  final LocalNoteService localNoteService;
  final LocalFolderService localFolderService;

  const LeevinoteApp({
    super.key,
    required this.settings,
    required this.apiService,
    required this.localNoteService,
    required this.localFolderService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
            create: (_) => AuthService(apiService: apiService, onLogin: () async {
                  await settings.syncFromServer();
                })),
        ChangeNotifierProvider.value(value: settings),
        Provider.value(value: apiService),
        ChangeNotifierProvider.value(value: localNoteService),
        ChangeNotifierProvider.value(value: localFolderService),
        ChangeNotifierProvider(create: (_) => LocalAlarmService()),
        ChangeNotifierProvider(create: (_) => LocalMusicService()),
        ChangeNotifierProvider(create: (_) => LocalVideoService()),
        ChangeNotifierProvider(create: (_) => LocalScheduleService()),
        ChangeNotifierProvider(create: (_) => LocalTransactionService()),
        ChangeNotifierProvider(
            create: (_) => LocalTransactionCategoryService()),
        ChangeNotifierProvider(create: (_) => HolidayService()),
        ChangeNotifierProvider(
            create: (context) => AlarmService(
                context.read<ApiService>(), context.read<LocalAlarmService>(),
                holidayService: context.read<HolidayService>())),
        ChangeNotifierProvider(
            create: (context) => MusicService(
                context.read<ApiService>(), context.read<LocalMusicService>())),
        ChangeNotifierProvider(
            create: (context) => VideoService(
                context.read<ApiService>(), context.read<LocalVideoService>())),
        ChangeNotifierProvider(
            create: (context) => ScheduleService(context.read<ApiService>(),
                context.read<LocalScheduleService>())),
        ChangeNotifierProvider(
            create: (context) => TransactionService(context.read<ApiService>(),
                context.read<LocalTransactionService>(),
                categoryLocal:
                    context.read<LocalTransactionCategoryService>())),
        ChangeNotifierProvider(
            create: (context) => TransactionCategoryService(
                context.read<ApiService>(),
                context.read<LocalTransactionCategoryService>())),
      ],
      child: _AuthCallbackSetter(
        apiService: apiService,
        child: Builder(
          builder: (context) {
            final settings = context.watch<SettingsService>();
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'LeeviNote',
              theme: AppTheme.lightTheme(seedColor: settings.themeColor),
              darkTheme: AppTheme.darkTheme(seedColor: settings.themeColor),
              themeMode: settings.flutterThemeMode,
              localizationsDelegates: const [
                ...GlobalMaterialLocalizations.delegates,
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
      ),
    );
  }
}

class _AuthCallbackSetter extends StatefulWidget {
  final ApiService apiService;
  final Widget child;
  const _AuthCallbackSetter({required this.apiService, required this.child});

  @override
  State<_AuthCallbackSetter> createState() => _AuthCallbackSetterState();
}

class _AuthCallbackSetterState extends State<_AuthCallbackSetter> {
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    final apiServices = <ApiService>{
      widget.apiService,
      context.read<ApiService>(),
    };

    void onUnauthorized() async {
      await auth.logout();
      if (mounted) {
        navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => route.isFirst,
        );
      }
    }

    for (final api in apiServices) {
      api.onUnauthorized = onUnauthorized;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
