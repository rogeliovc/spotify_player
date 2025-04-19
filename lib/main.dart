import 'package:flutter/material.dart';
import 'package:provider/provider.dart';




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
    return ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: MaterialApp(
        title: 'Spotify Player',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashDecider(),
      ),
    );
  }
}

class SplashDecider extends StatefulWidget {
  const SplashDecider({Key? key}) : super(key: key);

  @override
  State<SplashDecider> createState() => _SplashDeciderState();
}

class _SplashDeciderState extends State<SplashDecider> {
  final AuthService _authService = AuthService();

  String? _token;
  String? _refreshToken;
  int? _expiry;
  bool _isValid = false;
  String _status = 'Verificando sesión...';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await _authService.getAccessToken();
    final expiry = await _authService.getTokenExpiry();
    final refreshToken = await _authService.getRefreshToken();
    final now = DateTime.now().millisecondsSinceEpoch;
    bool isValid = false;
    String status = '';
    if (token != null && expiry != null && expiry > now) {
      isValid = true;
      status = 'Sesión activa: token válido.';
      setState(() {
        _token = token;
        _refreshToken = refreshToken;
        _expiry = expiry;
        _isValid = isValid;
        _status = status;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPlayerScreen()));
      }
    } else if (token != null) {
      status = 'Token expirado. Intentando refrescar...';
      setState(() {
        _token = token;
        _refreshToken = refreshToken;
        _expiry = expiry;
        _isValid = false;
        _status = status;
      });
      final refreshed = await _authService.refreshAccessToken();
      if (refreshed) {
        status = 'Token refrescado exitosamente.';
        final newToken = await _authService.getAccessToken();
        final newRefreshToken = await _authService.getRefreshToken();
        final newExpiry = await _authService.getTokenExpiry();
        setState(() {
          _token = newToken;
          _refreshToken = newRefreshToken;
          _expiry = newExpiry;
          _isValid = true;
          _status = status;
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => MainPlayerScreen()));
        }
      } else {
        status = 'No se pudo refrescar el token. Debes iniciar sesión.';
        setState(() {
          _isValid = false;
          _status = status;
        });
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreenLogin()));
        }
      }
    } else {
      status = 'No hay sesión activa. Debes iniciar sesión.';
      setState(() {
        _isValid = false;
        _status = status;
      });
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreenLogin()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(_status, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              if (_token != null) ...[
                SelectableText('Access Token: ${_token!.substring(0, 16)}...', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
              ],
              if (_refreshToken != null) ...[
                SelectableText('Refresh Token: ${_refreshToken!.substring(0, 16)}...', style: const TextStyle(fontSize: 13, color: Colors.teal)),
              ],
              if (_expiry != null) ...[
                Text('Expira en: ${DateTime.fromMillisecondsSinceEpoch(_expiry!).toLocal()}'),
                Text('¿Token válido?: ${_isValid ? 'Sí' : 'No'}'),
              ],
            ],
          ),
        ),
      ),
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
      _loading = false; // Nunca bloqueamos la UI manual
      _showManualInput = true; // Siempre mostramos el campo manual tras login
      _error = null;
    });
    try {
      await _authService.authenticate();
    } catch (e) {
      setState(() {
        _error = 'Error: ' + e.toString();
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
              ElevatedButton(
                onPressed: _login,
                child: Text('Iniciar sesión con Spotify'),
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
              if (_loading) ...[
                SizedBox(height: 24),
                CircularProgressIndicator(),
              ],
              if (_error != null) ...[
                SizedBox(height: 24),
                Text(
                  _error!,
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}





