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
    try {
      final res = await _api.post('/IniciarSesion', body: {
        'account': account,
        'pass': password,
      });
      if (res.success && res.data != null) {
        List<dynamic> list = res.data is List ? res.data : [res.data];
        if (list.isNotEmpty) {
          _user = UserModel.fromJson(list[0] as Map<String, dynamic>);
          if (_user!.id <= 0 || _user!.id.toString() == '-1') {
            _error = 'Credenciales invalidas';
            _user = null;
            _loading = false;
            notifyListeners();
            return false;
          }
          await _storage.saveUserData(list[0] as Map<String, dynamic>);
          _loading = false;
          notifyListeners();
          return true;
        }
      }
      _error = res.message ?? 'Error al iniciar sesion';
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
