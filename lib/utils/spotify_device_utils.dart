import 'dart:convert';
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
    final active = devices.firstWhere(
      (d) => d['is_active'] == true,
      orElse: () => null,
    );
    return active != null ? active['id'] as String : null;
  }
  return null;
}

Future<void> transferPlaybackToDevice(String accessToken, String deviceId) async {
  final url = Uri.parse('https://api.spotify.com/v1/me/player');
  final response = await http.put(
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

