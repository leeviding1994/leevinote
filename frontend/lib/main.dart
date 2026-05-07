import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leevinote/screens/home_screen.dart';
import 'package:leevinote/screens/login_screen.dart';
import 'package:leevinote/services/auth_service.dart';
import 'package:leevinote/services/api_service.dart';
import 'package:leevinote/utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      ],
      child: MaterialApp(
        title: 'Leevinote',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: Consumer<AuthService>(
          builder: (context, auth, _) {
            return auth.isAuthenticated ? const HomeScreen() : const LoginScreen();
          },
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
