import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  /// Borra tokens y datos de sesión para forzar re-autenticación
  Future<void> signOut() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'token_expiry');
    await _storage.delete(key: 'pkce_code_verifier');
  }
  static const String clientId = '4caddaabcd134c6da47d4f7d1c7877ba';
  static const String redirectUri = 'https://spotify-callback.vercel.app/api/callback';
  static const String scopes = 'user-read-playback-state user-modify-playback-state user-read-currently-playing playlist-read-private playlist-read-collaborative streaming user-top-read';
  static const String tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String authUrl = 'https://accounts.spotify.com/authorize';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _codeVerifier;

  Future<void> authenticate() async {
    try {
      _codeVerifier = _generateCodeVerifier();
      await _storage.write(key: 'pkce_code_verifier', value: _codeVerifier);
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);

      final url = Uri.parse('$authUrl?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=$scopes&code_challenge_method=S256&code_challenge=$codeChallenge');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo abrir el navegador para autenticación';
      }

      // Esperar el callback usando app_links
      final appLinks = AppLinks();
      final callbackUri = await appLinks.uriLinkStream.firstWhere((uri) => uri.toString().startsWith(redirectUri));
      
      
      final code = callbackUri.queryParameters['code'];
      
      
      if (code == null) throw 'No se recibió el código de autorización';
      await _exchangeCodeForToken(code);
    } catch (e, st) {
      
      
      
      rethrow;
    }
  }

  /// Permite intercambiar manualmente el código de autorización por tokens
  Future<void> exchangeManualCode(String code) async {
    _codeVerifier = await _storage.read(key: 'pkce_code_verifier');
    if (_codeVerifier == null) {
      throw 'No se encontró el code_verifier original. Debes iniciar sesión nuevamente.';
    }
    await _exchangeCodeForToken(code);
  }

  Future<void> _exchangeCodeForToken(String code) async {
    // Asegura que el code_verifier esté presente
    _codeVerifier ??= await _storage.read(key: 'pkce_code_verifier');
    if (_codeVerifier == null) {
      throw 'No se encontró el code_verifier original. Debes iniciar sesión nuevamente.';
    }
    
    print('Código recibido: $code');
    print('redirectUri usado: $redirectUri');
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'code_verifier': _codeVerifier!,
        },
      );
    
    print('Status code: ${response.statusCode}');
    print('Body: ${response.body}');
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(key: 'refresh_token', value: data['refresh_token']);
        await _storage.write(key: 'token_expiry', value: (DateTime.now().millisecondsSinceEpoch + (data['expires_in'] * 1000)).toString());
      } else {
        throw 'Error al intercambiar el código por token: ${response.body}';
      }
    }

  Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  /// Obtiene la expiración del token en milisegundos desde epoch
  Future<int?> getTokenExpiry() async {
    final expiryStr = await _storage.read(key: 'token_expiry');
    return expiryStr != null ? int.tryParse(expiryStr) : null;
  }

  /// Obtiene el refresh_token almacenado
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  /// Refresca el access_token usando el refresh_token guardado
  Future<bool> refreshAccessToken() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) return false;
    final response = await http.post(
      Uri.parse(tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': clientId,
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'access_token', value: data['access_token']);
      if (data['refresh_token'] != null) {
        await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      }
      await _storage.write(key: 'token_expiry', value: (DateTime.now().millisecondsSinceEpoch + (data['expires_in'] * 1000)).toString());
      return true;
    } else {
      return false;
    }
  }

  // Utilidades PKCE
  String _generateCodeVerifier() {
    final rand = Random.secure();
    final values = List<int>.generate(64, (i) => rand.nextInt(256));
    return base64UrlEncode(values).replaceAll('=', '');
  }

  String _generateCodeChallenge(String codeVerifier) {
    final bytes = utf8.encode(codeVerifier);
    final digest = sha256.convert(bytes);
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
