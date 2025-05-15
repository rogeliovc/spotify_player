import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splash_master/splash_master.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'screens/main_player_screen.dart';
import 'screens/task_manager.dart';
import 'screens/home_screen_login.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SplashMaster.initialize();
  SplashMaster.resume();
  final authService = AuthService();
  final playerProvider = PlayerProvider(authService);
  final themeProvider = ThemeProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => themeProvider),
        ChangeNotifierProvider(create: (_) => playerProvider),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
      ],
      child: MyApp(authService: authService),
    ),
  );
}

class MyApp extends StatefulWidget {
  final AuthService authService;

  const MyApp({super.key, required this.authService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final isValid = await widget.authService.isTokenValid();
      setState(() {
        _isAuthenticated = isValid;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isAuthenticated = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'Sincronía',
          theme: themeProvider.theme,
          debugShowCheckedModeBanner: false,
          home: _isLoading
              ? const Scaffold(
                  backgroundColor: Color(0xFF0E1928),
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : _isAuthenticated
                  ? const MainPlayerScreen()
                  : const HomeScreenLogin(),
        );
      },
    );
  }
}
