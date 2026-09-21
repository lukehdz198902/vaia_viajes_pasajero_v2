import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _tokenKey = 'session_token';
  static const _userIdKey = 'user_id';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userPhoneKey = 'user_phone';
  static const _userIdCompaniaKey = 'user_id_compania';
  static const _userDataKey = 'user_data';
  static const _onboardingKey = 'pasajero_onboarding';
  static const _terminosKey = 'pasajero_terminos';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<String?> getSessionToken() => _secure.read(key: _tokenKey);
  Future<void> setSessionToken(String token) => _secure.write(key: _tokenKey, value: token);
  Future<void> removeSessionToken() => _secure.delete(key: _tokenKey);

  Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey, user['id'] ?? 0);
    await prefs.setString(_userNameKey, user['nombre'] ?? '');
    await prefs.setString(_userEmailKey, user['correo'] ?? '');
    await prefs.setString(_userPhoneKey, user['telefono'] ?? '');
    await prefs.setInt(_userIdCompaniaKey, user['idcompania'] ?? 0);
    // Guarda el objeto completo para conservar las banderas de verificacion
    // (correoconfirmado, telefonoconfirmado) entre sesiones.
    try {
      await prefs.setString(_userDataKey, jsonEncode(user));
    } catch (_) {}
    if (user['uuidsesion'] != null) {
      await setSessionToken(user['uuidsesion'].toString());
    }
  }

  Future<Map<String, dynamic>> getUserData() async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> base = {};
    final raw = prefs.getString(_userDataKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) base = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return {
      ...base,
      'id': prefs.getInt(_userIdKey) ?? base['id'] ?? 0,
      'nombre': prefs.getString(_userNameKey) ?? base['nombre'] ?? '',
      'correo': prefs.getString(_userEmailKey) ?? base['correo'] ?? '',
      'telefono': prefs.getString(_userPhoneKey) ?? base['telefono'] ?? '',
      'idcompania': prefs.getInt(_userIdCompaniaKey) ?? base['idcompania'] ?? 0,
    };
  }

  // ─── ONBOARDING / TERMINOS ───────────────────────────────────

  Future<void> setOnboardingCompletado(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, v);
  }

  Future<bool> getOnboardingCompletado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setTerminosAceptados(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_terminosKey, v);
  }

  Future<bool> getTerminosAceptados() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_terminosKey) ?? false;
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _secure.deleteAll();
  }
}
