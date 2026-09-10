import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

class ApiException implements Exception {
  final int status; final String code, message;
  ApiException(this.status, this.code, this.message);
  @override String toString() => message;
}

/// Thin REST client for the Node backend. All calls carry the Supabase access token.
class Backend {
  static bool get on => AppConfig.backendUrl.isNotEmpty && AppConfig.supabaseUrl.isNotEmpty;
  static SupabaseClient get sb => Supabase.instance.client;
  static String? get token => sb.auth.currentSession?.accessToken;
  static String? get userId => sb.auth.currentUser?.id;
  static bool get signedIn => token != null;
  static String get platform => kIsWeb ? 'web' : Platform.isIOS ? 'ios' : 'android';

  static Future<void> init() async {
    if (!on) return;
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    final sp = await SharedPreferences.getInstance();
    var id = sp.getString('chaupal:device');
    if (id == null) { final r = Random.secure(); id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join(); await sp.setString('chaupal:device', id); }
    AppConfig.deviceId = id;
  }

  static Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
        if (AppConfig.deviceId.isNotEmpty) 'x-device-id': AppConfig.deviceId,
      };

  static Future<dynamic> _send(String method, String path, [Object? body]) async {
    final uri = Uri.parse('${AppConfig.backendUrl}$path');
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));
    final text = res.body.isEmpty ? 'null' : res.body;
    final json = jsonDecode(text);
    if (res.statusCode >= 400) {
      final err = (json is Map ? json['error'] : null) ?? {};
      throw ApiException(res.statusCode, err['code'] ?? 'ERROR', err['message'] ?? 'Request failed (${res.statusCode})');
    }
    return json;
  }
  static Future<dynamic> get(String path) => _send('GET', path);
  static Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body ?? {});
  static Future<dynamic> patch(String path, Object body) => _send('PATCH', path, body);
  static Future<dynamic> delete(String path) => _send('DELETE', path);

  /* ---- auth ---- */
  static Future<void> sendOtp(String phoneE164) => sb.auth.signInWithOtp(phone: phoneE164);
  static Future<void> verifyOtp(String phoneE164, String code) => sb.auth.verifyOTP(type: OtpType.sms, token: code, phone: phoneE164);
  static Future<void> sendEmailOtp(String email) => sb.auth.signInWithOtp(email: email);
  static Future<void> verifyEmailOtp(String email, String code) => sb.auth.verifyOTP(type: OtpType.email, token: code, email: email);
  static Future<void> googleSignIn() => sb.auth.signInWithOAuth(OAuthProvider.google);
  static Future<void> signOut() => sb.auth.signOut();

  /// Register this install once per app start (device binding + attestation hook).
  static Future<void> registerDevice() async {
    if (!on || !signedIn) return;
    try { await post('/v1/device', {'deviceId': AppConfig.deviceId, 'platform': platform, 'appVersion': AppConfig.appVersion}); } catch (_) {}
  }
}
