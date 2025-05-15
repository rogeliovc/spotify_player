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

  /// Borra todos los tokens y datos de sesión y fuerza re-autenticación
  Future<void> forceReauth() async {
    await signOut();
    print(
        '[AuthService] Tokens eliminados. Debes iniciar sesión nuevamente para aceptar los nuevos permisos.');
  }

  static const String clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID',
      defaultValue: '4caddaabcd134c6da47d4f7d1c7877ba');
  static const String redirectUri = 'sincronia://callback';
  static const List<String> scopes = [
    'user-read-playback-state',
    'user-modify-playback-state',
    'user-read-currently-playing',
    'playlist-read-private',
    'playlist-read-collaborative',
    'streaming',
    'user-top-read',
    'user-read-recently-played',
    'user-read-email',
    'playlist-modify-private',
    'playlist-modify-public',
  ];
  static const String tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String authUrl = 'https://accounts.spotify.com/authorize';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String? _codeVerifier;
  bool _isAuthenticating = false;

  Future<void> authenticate() async {
    if (_isAuthenticating) {
      print('[AuthService] Ya hay un proceso de autenticación en curso');
      return;
    }

    try {
      _isAuthenticating = true;
      _codeVerifier = _generateCodeVerifier();
      await _storage.write(key: 'pkce_code_verifier', value: _codeVerifier);
      final codeChallenge = _generateCodeChallenge(_codeVerifier!);

      final url = Uri.parse(
          '$authUrl?response_type=code&client_id=$clientId&redirect_uri=$redirectUri&scope=${scopes.join(' ')}&code_challenge_method=S256&code_challenge=$codeChallenge');

      print('[AuthService] Iniciando autenticación...');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'No se pudo abrir el navegador para autenticación';
      }

      // Esperar el callback usando app_links
      print('[AuthService] Esperando callback...');
      final appLinks = AppLinks();
      final callbackUri = await appLinks.uriLinkStream
          .firstWhere(
            (uri) => uri.toString().startsWith(redirectUri),
            orElse: () => throw 'No se recibió el callback de autenticación',
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () =>
                throw 'Tiempo de espera agotado. Por favor, intenta nuevamente.',
          );

      print('[AuthService] Callback recibido: ${callbackUri.toString()}');
      final code = callbackUri.queryParameters['code'];
      if (code == null) {
        throw 'No se recibió el código de autorización';
      }

      print('[AuthService] Intercambiando código por token...');
      await _exchangeCodeForToken(code);
      print('[AuthService] Autenticación completada exitosamente');
    } catch (e, st) {
      print('[AuthService] Error en autenticación: $e\n$st');
      rethrow;
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Permite intercambiar manualmente el código de autorización por tokens
  Future<void> exchangeManualCode(String code) async {
    if (_isAuthenticating) {
      print('[AuthService] Ya hay un proceso de autenticación en curso');
      return;
    }

    try {
      _isAuthenticating = true;
      _codeVerifier = await _storage.read(key: 'pkce_code_verifier');
      if (_codeVerifier == null) {
        throw 'No se encontró el code_verifier original. Debes iniciar sesión nuevamente.';
      }
      print('[AuthService] Intercambiando código manual por token...');
      await _exchangeCodeForToken(code);
      print('[AuthService] Intercambio de código completado exitosamente');
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Obtiene el token de acceso, refrescándolo si es necesario
  Future<String?> getAccessToken() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return null;

    final expiry = await getTokenExpiry();
    if (expiry == null) return null;

    // Si el token expira en menos de 5 minutos, intenta refrescarlo
    if (expiry - DateTime.now().millisecondsSinceEpoch < 5 * 60 * 1000) {
      final refreshed = await refreshAccessToken();
      if (refreshed) {
        return await _storage.read(key: 'access_token');
      }
      return null;
    }

    return token;
  }

  /// Verifica si el token es válido y no ha expirado
  Future<bool> isTokenValid() async {
    final token = await _storage.read(key: 'access_token');
    if (token == null) return false;

    final expiry = await getTokenExpiry();
    if (expiry == null) return false;

    return expiry > DateTime.now().millisecondsSinceEpoch;
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
    try {
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
          await _storage.write(
              key: 'refresh_token', value: data['refresh_token']);
        }
        await _storage.write(
            key: 'token_expiry',
            value: (DateTime.now().millisecondsSinceEpoch +
                    (data['expires_in'] * 1000))
                .toString());
        return true;
      } else {
        print(
            'Error al refrescar token: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error en refreshAccessToken: $e');
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

  Future<void> _exchangeCodeForToken(String code) async {
    _codeVerifier ??= await _storage.read(key: 'pkce_code_verifier');
    if (_codeVerifier == null) {
      throw 'No se encontró el code_verifier original. Debes iniciar sesión nuevamente.';
    }

    try {
      print('[AuthService] Enviando solicitud de token...');
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

      if (response.statusCode == 200) {
        print('[AuthService] Token recibido exitosamente');
        final data = json.decode(response.body);
        await _storage.write(key: 'access_token', value: data['access_token']);
        await _storage.write(
            key: 'refresh_token', value: data['refresh_token']);
        await _storage.write(
            key: 'token_expiry',
            value: (DateTime.now().millisecondsSinceEpoch +
                    (data['expires_in'] * 1000))
                .toString());
      } else {
        final error = json.decode(response.body);
        print(
            '[AuthService] Error al intercambiar código: ${error['error_description'] ?? response.body}');
        throw 'Error al intercambiar el código por token: ${error['error_description'] ?? response.body}';
      }
    } catch (e) {
      print('[AuthService] Error en _exchangeCodeForToken: $e');
      rethrow;
    }
  }
}
