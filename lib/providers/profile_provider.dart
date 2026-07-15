import 'package:flutter/material.dart';
import '../models/favorito_model.dart';
import '../models/promocion_model.dart';
import '../models/aviso_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ProfileProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider _auth;

  ProfileProvider(this._api, this._auth);

  void updateAuth(AuthProvider auth) => _auth = auth;

  List<FavoritoModel> _favoritos = [];
  List<PromocionModel> _promociones = [];
  List<AvisoModel> _avisos = [];
  bool _loading = false;
  String? _error;

  List<FavoritoModel> get favoritos => _favoritos;
  List<PromocionModel> get promociones => _promociones;
  List<AvisoModel> get avisos => _avisos;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> cargarPerfil() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get('/ObtenerPerfil', params: {
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.firstOrNull() is Map) {}
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<bool> actualizarPerfil(Map<String, dynamic> data) async {
    _loading = true;
    notifyListeners();
    data['idPasajero'] = _auth.userId;
    try {
      final res = await _api.post('/ActualizarPerfil', body: data);
      _loading = false;
      notifyListeners();
      return res.success;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarPassword(String passActual, String passNuevo) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/CambiarPassword', body: {
        'idPasajero': _auth.userId,
        'passActual': passActual,
        'passNuevo': passNuevo,
      });
      _loading = false;
      notifyListeners();
      return res.success && res.getResultado() == 1;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarTelefono(String codigoPais, String telefono, String codigo) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/CambiarTelefono', body: {
        'idPasajero': _auth.userId,
        'codigopaistel': codigoPais,
        'telefonoNuevo': telefono,
        'codigoVerificacion': codigo,
      });
      _loading = false;
      notifyListeners();
      return res.success && res.getResultado() == 1;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cargarFavoritos() async {
    try {
      final res = await _api.get('/ListarFavoritos', params: {
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.isList) {
        _favoritos = res.list
            .map((e) => FavoritoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> agregarFavorito(Map<String, dynamic> data) async {
    data['idPasajero'] = _auth.userId;
    try {
      final res = await _api.post('/AgregarFavorito', body: data);
      if (res.success) {
        await cargarFavoritos();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> eliminarFavorito(int idFavorito) async {
    try {
      final res = await _api.post('/EliminarFavorito', body: {
        'idFavorito': idFavorito,
        'idPasajero': _auth.userId,
      });
      if (res.success) {
        _favoritos.removeWhere((f) => f.id == idFavorito);
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cargarPromociones() async {
    try {
      final res = await _api.get('/ObtenerPromociones');
      if (res.success && res.isList) {
        _promociones = res.list
            .map((e) => PromocionModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> cargarAvisos() async {
    try {
      final res = await _api.get('/ObtenerAvisos', params: {
        'idCompania': _auth.idCompania.toString(),
      });
      if (res.success && res.isList) {
        _avisos = res.list
            .map((e) => AvisoModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> validarCodigoPromocional(String codigo, double montoViaje) async {
    try {
      final res = await _api.post('/ValidarCodigoPromocional', body: {
        'codigo': codigo,
        'idPasajero': _auth.userId,
        'montoViaje': montoViaje,
      });
      if (res.success && res.firstOrNull() is Map) {
        return res.firstOrNull() as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
