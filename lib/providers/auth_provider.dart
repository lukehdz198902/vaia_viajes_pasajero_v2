import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/signalr_service.dart';
import '../services/notification_service.dart';
import '../services/logger.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;
  final SignalRService _signalr;

  AuthProvider(this._api, this._storage, this._signalr);

  UserModel? _user;
  bool _loading = false;
  String? _error;
  String? _pendingAccount;
  String? _pendingPass;
  String? _pendingTelefono;
  String? _pendingCodigoPais;

  UserModel? get user => _user;
  bool get loading => _loading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  int get userId => _user?.id ?? 0;
  int get idCompania => _user?.idCompania ?? 0;
  bool get hasPendingVerification => _pendingAccount != null;
  bool get correoConfirmado => _user?.correoConfirmado ?? true;

  /// Guarda los datos del formulario de registro mientras se verifica el telefono.
  void setPendingRegistration({
    required String account,
    required String pass,
    required String telefono,
    required String codigopaistel,
  }) {
    _pendingAccount = account;
    _pendingPass = pass;
    _pendingTelefono = telefono;
    _pendingCodigoPais = codigopaistel;
  }

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
        // Conectar WebSocket
        try {
          await _signalr.iniciar(_user!.id);
        } catch (e) {
          Logger.w('Auth', 'No se pudo iniciar SignalR: $e');
        }
        _loading = false;
        notifyListeners();
        Logger.i('Auth', 'login() OK - user ${_user!.nombreCompleto} logged in');
        _registrarToken();
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
          _loading = false;
          notifyListeners();
          Logger.i('Auth', 'register() OK - iniciando sesion');
          return await login(data['account'] as String, data['pass'] as String);
        }
        _error = res.getMensaje();
        if (id == -1) { _error = 'El usuario ya existe'; }
        else if (id == -2) { _error = 'El correo ya esta registrado'; }
        else if (id == -3) { _error = 'El telefono ya esta registrado'; }
        else if (id == -4) { _error = 'Debes verificar tu telefono por WhatsApp'; }
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

  /// Envia (por WhatsApp) el codigo de verificacion al telefono indicado.
  Future<bool> enviarCodigoVerificacion({String? telefono, String? codigopaistel}) async {
    final tel = telefono ?? _pendingTelefono;
    final pais = codigopaistel ?? _pendingCodigoPais;
    if (tel == null || tel.isEmpty) return false;
    try {
      final res = await _api.post('/EnviarCodigoVerificacion', body: {
        'telefono': tel,
        'codigopaistel': pais ?? '52',
      });
      Logger.i('Auth', 'enviarCodigoVerificacion() success=${res.success}');
      return res.success;
    } catch (e) {
      Logger.e('Auth', 'enviarCodigoVerificacion() exception: $e');
      return false;
    }
  }

  /// Valida el codigo de WhatsApp SIN crear la cuenta todavia.
  /// La cuenta se crea despues con register().
  Future<bool> validarCodigoTelefono(String code, {String? telefono, String? codigopaistel}) async {
    final tel = telefono ?? _pendingTelefono;
    final pais = codigopaistel ?? _pendingCodigoPais;
    if (tel == null || tel.isEmpty) {
      _error = 'Falta el telefono';
      return false;
    }
    try {
      final res = await _api.post('/ValidarCodigoVerificacion', body: {
        'codigo': code,
        'telefono': tel,
        'codigopaistel': pais ?? '52',
      });
      if (!res.success) {
        _error = res.getMensaje();
        Logger.w('Auth', 'validarCodigoTelefono() rechazado: $_error');
        return false;
      }
      Logger.i('Auth', 'validarCodigoTelefono() OK');
      return true;
    } catch (e) {
      Logger.e('Auth', 'validarCodigoTelefono() exception: $e');
      _error = 'Error de conexion';
      return false;
    }
  }

  /// Inicia sesion / registra con Google usando el idToken.
  Future<bool> loginConGoogle(String idToken) async {
    Logger.i('Auth', 'loginConGoogle() called');
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.iniciarSesionGoogle(idToken, idCompania: 1, googlekey: NotificationService.token);
      if (res.success && res.firstOrNull() is Map) {
        final data = res.firstOrNull() as Map<String, dynamic>;
        _user = UserModel.fromJson(data);
        await _storage.saveUserData(data);
        try {
          await _signalr.iniciar(_user!.id);
        } catch (e) {
          Logger.w('Auth', 'No se pudo iniciar SignalR (Google): $e');
        }
        _loading = false;
        notifyListeners();
        _registrarToken();
        return true;
      }
      _error = res.getMensaje() ?? 'No se pudo iniciar sesion con Google';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      Logger.e('Auth', 'loginConGoogle() exception: $e');
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  /// Envia un codigo de verificacion al correo (o al correo nuevo).
  Future<bool> enviarCodigoCorreo({String? correoNuevo}) async {
    if (_user == null) return false;
    try {
      final res = await _api.enviarCodigoCorreo(_user!.id, correoNuevo: correoNuevo);
      if (!res.success) {
        _error = res.getMensaje();
        return false;
      }
      return true;
    } catch (e) {
      Logger.e('Auth', 'enviarCodigoCorreo() exception: $e');
      _error = 'Error de conexion';
      return false;
    }
  }

  /// Valida el codigo de correo y marca el correo como confirmado.
  Future<bool> validarCodigoCorreo(String codigo) async {
    if (_user == null) return false;
    try {
      final res = await _api.validarCodigoCorreo(_user!.id, codigo);
      if (!res.success) {
        _error = res.getMensaje();
        return false;
      }
      _user = _user!.copyWith(correoConfirmado: true);
      await _storage.saveUserData(_user!.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      Logger.e('Auth', 'validarCodigoCorreo() exception: $e');
      _error = 'Error de conexion';
      return false;
    }
  }

  /// Cambia el correo (valida el codigo enviado al correo nuevo).
  Future<bool> cambiarCorreo(String correoNuevo, String codigo) async {
    if (_user == null) return false;
    try {
      final res = await _api.cambiarCorreo(_user!.id, correoNuevo, codigo);
      if (!res.success) {
        _error = res.getMensaje();
        return false;
      }
      _user = _user!.copyWith(correo: correoNuevo, correoConfirmado: true);
      await _storage.saveUserData(_user!.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      Logger.e('Auth', 'cambiarCorreo() exception: $e');
      _error = 'Error de conexion';
      return false;
    }
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
    try { await _signalr.detener(); } catch (_) {}
    await _storage.clearAll();
    _user = null;
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final userData = await _storage.getUserData();
    final token = await _storage.getSessionToken();
    if (userData['id'] != null && userData['id'] > 0 && token != null) {
      _user = UserModel.fromJson(userData);
      try {
        await _signalr.iniciar(_user!.id);
      } catch (e) {
        Logger.w('Auth', 'No se pudo iniciar SignalR en auto-login: $e');
      }
      notifyListeners();
      _registrarToken();
      return true;
    }
    return false;
  }

  /// Registra el token de notificaciones push (FCM) en el backend.
  Future<void> _registrarToken() async {
    final t = NotificationService.token;
    if (t == null || t.isEmpty || _user == null) return;
    try {
      await _api.actualizarToken(_user!.id, t);
      Logger.i('Auth', 'Token FCM registrado');
    } catch (e) {
      Logger.w('Auth', 'No se pudo registrar el token FCM: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
