import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? userInfo;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    fetchUserInfo();
  }

  Future<void> fetchUserInfo() async {
    setState(() { loading = true; error = null; });
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
      setState(() { error = e.toString(); loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: const Color(0xFF0E1928),
      ),
      backgroundColor: const Color(0xFF0E1928),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Información del usuario', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 18),
          if (loading)
            const Center(child: CircularProgressIndicator()),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.redAccent)),
          if (!loading && userInfo != null)
            _userInfoSection(userInfo!),
          const SizedBox(height: 40),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              final auth = AuthService();
              await auth.signOut();
              await auth.authenticate();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sesión cerrada correctamente')),
                );
                Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _userInfoSection(Map<String, dynamic> user) {
    return Row(
      children: [
        if (user['images'] != null && user['images'].isNotEmpty)
          CircleAvatar(
            backgroundImage: NetworkImage(user['images'][0]['url']),
            radius: 35,
          )
        else
          const CircleAvatar(radius: 35, backgroundColor: Colors.grey),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user['display_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
              if (user['email'] != null)
                Text(user['email'], style: const TextStyle(color: Colors.white70)),
              if (user['id'] != null)
                Text('ID: ${user['id']}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
              if (user['country'] != null)
                Text('País: ${user['country']}', style: const TextStyle(color: Colors.white38, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
