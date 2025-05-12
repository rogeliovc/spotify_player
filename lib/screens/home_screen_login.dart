import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_player_screen.dart';

class HomeScreenLogin extends StatefulWidget {
  const HomeScreenLogin({super.key});

  @override
  State<HomeScreenLogin> createState() => _HomeScreenLoginState();
}

class _HomeScreenLoginState extends State<HomeScreenLogin> {
  bool _isLoading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = AuthService();
      await auth.authenticate();
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exchangeToken() async {
    final TextEditingController controller = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Intercambiar Token'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Pega tu código de autorización aquí',
          ),
          maxLines: 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final code = controller.text.trim();
              if (code.isEmpty) {
                setState(() {
                  _error = 'Por favor, ingresa un código válido';
                });
                return;
              }

              try {
                final auth = AuthService();
                await auth.exchangeManualCode(code);
                if (mounted) {
                  Navigator.pop(context);
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const MainPlayerScreen()),
                  );
                }
              } catch (e) {
                setState(() {
                  _error = 'Error al intercambiar el token: ${e.toString()}';
                });
              }
            },
            child: const Text('Intercambiar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1928),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo o imagen de la app
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFe0c36a),
                    borderRadius: BorderRadius.circular(60),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Título
                const Text(
                  'Sincronía',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Serif',
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tu música, tu ritmo',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 48),
                
                // Botón de inicio de sesión
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.music_note),
                    label: const Text('Iniciar sesión con Spotify'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1DB954),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                
                // Mensaje de error
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
} 