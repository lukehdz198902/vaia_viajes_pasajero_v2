import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  AuthProvider(this._api, this._storage);

  UserModel? _user;
  bool _loading = false;
  String? _error;

  UserModel? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  int get userId => _user?.id ?? 0;
  int get idCompania => _user?.idCompania ?? 0;

  Future<bool> login(String account, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    // Simular login — usar datos fijos mientras no haya API disponible
    await Future.delayed(const Duration(milliseconds: 800));
    final mockUser = {
      'id': 1,
      'idcompania': 1,
      'nombre': 'María',
      'appaterno': 'García',
      'apmaterno': 'López',
      'correo': 'maria@ejemplo.com',
      'codigopaistel': '+52',
      'telefono': '5551234567',
      'account': 'maria_g',
      'uuidsesion': 'mock-session-token-001',
      'bloqueado': false,
      'conectado': true,
      'eslogueadocongoogle': false,
    };
    _user = UserModel.fromJson(mockUser);
    await _storage.saveUserData(mockUser);
    _loading = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(Map<String, dynamic> data) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/Registrar', body: data);
      if (res.success) {
        var id = res.getNuevoId();
        if (id != null && id > 0) {
          return await login(data['account'], data['pass']);
        }
        _error = res.getMensaje();
        if (id == -1) _error = 'El usuario ya existe';
        if (id == -2) _error = 'El correo ya esta registrado';
        if (id == -3) _error = 'El telefono ya esta registrado';
      } else {
        _error = res.message ?? 'Error al registrarse';
      }
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    if (_user != null) {
      await _api.post('/CerrarSesion', body: {
        'idPasajero': _user!.id,
      });
    }
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final userData = await _storage.getUserData();
    final token = await _storage.getSessionToken();
    if (userData['id'] != null && userData['id'] > 0 && token != null) {
      _user = UserModel.fromJson(userData);
      notifyListeners();
      return true;
    }
    return false;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
