import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen_login.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? userInfo;
  bool loading = true;
  String? error;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final auth = AuthService();
      final token = await auth.getAccessToken();
      if (token == null) throw 'No token';
      final response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        setState(() {
          userInfo = json.decode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          error = 'Error: ${response.statusCode} - ${response.body}';
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _logout() async {
    try {
      final auth = AuthService();
      await auth.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión cerrada correctamente')),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreenLogin()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cerrar sesión: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Configuración',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sección de Perfil
            _buildSectionTitle('Perfil'),
            if (loading)
              const Center(child: CircularProgressIndicator())
            else if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent))
            else if (userInfo != null)
              _buildProfileCard(userInfo!),
            const SizedBox(height: 24),

            // Sección de Preferencias
            _buildSectionTitle('Preferencias'),
            _buildPreferenceCard(
              icon: Icons.notifications,
              title: 'Notificaciones',
              trailing: Switch(
                value: _notificationsEnabled,
                onChanged: (value) =>
                    setState(() => _notificationsEnabled = value),
                activeColor: const Color(0xFFe0c36a),
              ),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Notificaciones'),
                    content: const Text(
                      'Activa las notificaciones para recibir recordatorios de tus tareas y novedades musicales personalizadas en Sincronía. Así, nunca te perderás una tarea importante ni una recomendación musical relevante.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Sección de Cuenta
            _buildSectionTitle('Cuenta'),
            _buildPreferenceCard(
              icon: Icons.privacy_tip,
              title: 'Privacidad',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Privacidad'),
                    content: const Text(
                      'Sincronía utiliza la API oficial de Spotify para acceder a tu información musical y así personalizar tu experiencia y recomendaciones. Nosotros no almacenamos ni compartimos tus datos personales: toda la información se obtiene directamente de Spotify y se usa únicamente para mostrarte contenido relevante dentro de la app.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildPreferenceCard(
              icon: Icons.info,
              title: 'Acerca de',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Acerca de Sincronía'),
                    content: const Text(
                      'Sincronía es un gestor de tareas integrado a una experiencia musical personalizada. Organiza tus pendientes, recibe recomendaciones musicales y disfruta de la productividad acompañada de tu música favorita, todo en un solo lugar.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Botón de Cerrar Sesión
            Center(
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileCard(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (user['images'] != null && user['images'].isNotEmpty)
            CircleAvatar(
              backgroundImage: NetworkImage(user['images'][0]['url']),
              radius: 35,
            )
          else
            const CircleAvatar(
              radius: 35,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 35),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['display_name'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (user['email'] != null)
                  Text(
                    user['email'],
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (user['country'] != null)
                  Text(
                    'País: ${user['country']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceCard({
    required IconData icon,
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      color: Theme.of(context).cardColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFe0c36a)),
        title: Text(title),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
