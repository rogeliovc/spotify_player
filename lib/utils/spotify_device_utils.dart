import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

Future<String?> getActiveDeviceId(String accessToken) async {
  final url = Uri.parse('https://api.spotify.com/v1/me/player/devices');
  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
  );
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final devices = data['devices'] as List<dynamic>;
    // LOG: Mostrar la lista de dispositivos
    developer.log('SPOTIFY DEVICES:');
    for (var d in devices) {
      developer.log(
          '  - ${d['name']} (id: ${d['id']}, is_active: ${d['is_active']}, type: ${d['type']})');
    }
    final active = devices.firstWhere(
      (d) => d['is_active'] == true,
      orElse: () => null,
    );
    if (active != null) {
      developer.log(
          'DISPOSITIVO ACTIVO SELECCIONADO: ${active['name']} (id: ${active['id']})');
      return active['id'] as String;
    } else {
      developer.log('NO SE ENCONTRÓ DISPOSITIVO ACTIVO');
    }
  } else {
    developer.log(
        'Error al obtener dispositivos: ${response.statusCode} ${response.body}');
  }
  return null;
}

Future<void> transferPlaybackToDevice(
    String accessToken, String deviceId) async {
  final url = Uri.parse('https://api.spotify.com/v1/me/player');
  await http.put(
    url,
    headers: {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      "device_ids": [deviceId],
      "play": false
    }),
  );
  // No importa el status, solo intentamos transferir el playback
}
