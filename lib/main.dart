import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/player_provider.dart';




import 'services/auth_service.dart';
import 'screens/main_player_screen.dart';
import 'screens/task_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService().getAccessToken(),
      builder: (context, snapshot) {
        // Mientras carga el token
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final token = snapshot.data;
        return MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => TaskProvider()),
            ChangeNotifierProvider(create: (_) => PlayerProvider(accessToken: token ?? '')),
          ],
          child: MaterialApp(
            title: 'Spotify Player',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            home: token == null ? const HomeScreenLogin() : MainPlayerScreen(),
          ),
        );
      },
    );
  }
}

class HomeScreenLogin extends StatefulWidget {
  const HomeScreenLogin({super.key});

  @override
  State<HomeScreenLogin> createState() => _HomeScreenLoginState();
}

class _HomeScreenLoginState extends State<HomeScreenLogin> {
  final AuthService _authService = AuthService();
  bool _loading = false;
  String? _error;
  final TextEditingController _manualCodeController = TextEditingController();
  bool _showManualInput = false;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
      _showManualInput = false;
    });
    try {
      await _authService.authenticate();
      setState(() {
        _loading = false;
        _showManualInput = false;
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainPlayerScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: ' + e.toString();
        _showManualInput = true;
      });
    }
  }

  Future<void> _exchangeManualCode() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.exchangeManualCode(_manualCodeController.text.trim());
      setState(() {
        _loading = false;
        _showManualInput = false;
      });
      // Navegar a la pantalla principal tras login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainPlayerScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error: ' + e.toString();
        _showManualInput = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Spotify Player')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 18),
              ],
              ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text('Esperando Spotify...'),
                        ],
                      )
                    : Text('Iniciar sesión con Spotify'),
              ),
              const SizedBox(height: 16),
              if (!_showManualInput)
                TextButton(
                  onPressed: _loading ? null : () {
                    setState(() {
                      _showManualInput = true;
                    });
                  },
                  child: const Text('¿Tienes un código? Ingresar manualmente'),
                ),
              if (_showManualInput) ...[
                SizedBox(height: 24),
                Text('¿Tienes un código de autorización? Pégalo aquí:'),
                TextField(
                  controller: _manualCodeController,
                  enabled: !_loading,
                  decoration: InputDecoration(
                    labelText: 'Código de autorización',
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading ? null : _exchangeManualCode,
                  child: Text('Intercambiar código por token'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}





