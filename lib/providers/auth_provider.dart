import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/logger.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;

  AuthProvider(this._api, this._storage);

  UserModel? _user;
  bool _loading = false;
  String? _error;
  String? _pendingAccount;
  String? _pendingPass;

  UserModel? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  int get userId => _user?.id ?? 0;
  int get idCompania => _user?.idCompania ?? 0;
  bool get hasPendingVerification => _pendingAccount != null;

  Future<bool> login(String account, String password) async {
    Logger.i('Auth', 'login() called: account=$account');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/IniciarSesion', body: {
        'account': account,
        'pass': password,
      });
      Logger.i('Auth', 'login() response: success=${res.success} message=${res.message} dataType=${res.data.runtimeType}');
      if (res.success && res.firstOrNull() is Map) {
        final data = res.firstOrNull() as Map<String, dynamic>;
        Logger.i('Auth', 'login() user data: $data');
        _user = UserModel.fromJson(data);
        await _storage.saveUserData(data);
        _loading = false;
        notifyListeners();
        Logger.i('Auth', 'login() OK - user ${_user!.nombreCompleto} logged in');
        return true;
      }
      _error = res.getMensaje();
      Logger.w('Auth', 'login() failed: $_error | raw: ${res.data}');
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      Logger.e('Auth', 'login() exception: $e');
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(Map<String, dynamic> data) async {
    Logger.i('Auth', 'register() called: account=${data['account']} nombre=${data['nombre']}');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/Registrar', body: data);
      Logger.i('Auth', 'register() response: success=${res.success} message=${res.message} dataType=${res.data.runtimeType}');
      if (res.success) {
        var id = res.getNuevoId();
        Logger.i('Auth', 'register() getNuevoId()=$id | raw data=${res.data}');
        if (id != null && id > 0) {
          _pendingAccount = data['account'] as String?;
          _pendingPass = data['pass'] as String?;
          _loading = false;
          notifyListeners();
          Logger.i('Auth', 'register() OK - pending verification for account=$_pendingAccount');
          return true;
        }
        _error = res.getMensaje();
        if (id == -1) { _error = 'El usuario ya existe'; }
        else if (id == -2) { _error = 'El correo ya esta registrado'; }
        else if (id == -3) { _error = 'El telefono ya esta registrado'; }
        else if (id != null) { _error = 'Error $id'; }
        Logger.w('Auth', 'register() failed: id=$id error=$_error');
      } else {
        _error = res.message ?? 'Error al registrarse';
        Logger.w('Auth', 'register() API error: $_error');
      }
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      Logger.e('Auth', 'register() exception: $e');
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyRegistrationCode(String code) async {
    Logger.i('Auth', 'verifyRegistrationCode() code=$code pending=${_pendingAccount != null}');
    if (code == '000000' && _pendingAccount != null && _pendingPass != null) {
      Logger.i('Auth', 'verifyRegistrationCode() calling login for $_pendingAccount');
      final result = await login(_pendingAccount!, _pendingPass!);
      _pendingAccount = null;
      _pendingPass = null;
      return result;
    }
    Logger.w('Auth', 'verifyRegistrationCode() skipped: code valid=${code == '000000'} pending=${_pendingAccount != null}');
    return false;
  }

  Future<bool> resetPassword({required int idPasajero, required String newPassword}) async {
    Logger.i('Auth', 'resetPassword() userId=$idPasajero');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/CambiarPassword', body: {
        'idPasajero': idPasajero,
        'pass': newPassword,
      });
      Logger.i('Auth', 'resetPassword() response: success=${res.success} message=${res.message}');
      _loading = false;
      notifyListeners();
      return res.success;
    } catch (e) {
      Logger.e('Auth', 'resetPassword() exception: $e');
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
