import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../models/conductor_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider _auth;

  RideProvider(this._api, this._auth);

  void updateAuth(AuthProvider auth) => _auth = auth;

  RideModel? _currentRide;
  List<ConductorModel> _conductoresDisponibles = [];
  List<RideModel> _historial = [];
  bool _loading = false;
  String? _error;
  bool _buscandoConductor = false;
  Timer? _pollTimer;

  RideModel? get currentRide => _currentRide;
  List<ConductorModel> get conductoresDisponibles => _conductoresDisponibles;
  List<RideModel> get historial => _historial;
  bool get loading => _loading;
  bool get buscandoConductor => _buscandoConductor;
  String? get error => _error;

  Future<bool> solicitarServicio({
    required String dirOrigen,
    required String latOrigen,
    required String lngOrigen,
    required String dirDestino,
    required String latDestino,
    required String lngDestino,
    required int distanciaMetros,
    int idTipoPago = 1,
    String? codigoPromocional,
    String? tipoviaje,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/SolicitarServicio', body: {
        'idPasajero': _auth.userId,
        'idCompania': _auth.idCompania,
        'dirOrigen': dirOrigen,
        'latOrigen': latOrigen,
        'lngOrigen': lngOrigen,
        'dirDestino': dirDestino,
        'latDestino': latDestino,
        'lngDestino': lngDestino,
        'distanciaMetros': distanciaMetros,
        'idTipoPago': idTipoPago,
        'codigoPromocional': codigoPromocional,
        'tipoviaje': tipoviaje ?? 'URBANO',
      });
      if (res.success && res.firstOrNull() is Map) {
        final data = res.firstOrNull() as Map<String, dynamic>;
        _currentRide = RideModel.fromJson({
          ...data,
          'idpasajero': _auth.userId,
          'direccionorigen': dirOrigen,
          'latorigen': latOrigen,
          'lngorigen': lngOrigen,
          'direcciondestination': dirDestino,
          'latdestination': latDestino,
          'lngdestination': lngDestino,
          'estatus': 'Solicitado',
        });
        _loading = false;
        notifyListeners();
        _startPolling();
        return true;
      }
      _error = res.message ?? 'Error al solicitar servicio';
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

  Future<void> buscarConductores({String? lat, String? lng, int? idZona}) async {
    try {
      final params = <String, String>{};
      if (lat != null) params['lat'] = lat;
      if (lng != null) params['lng'] = lng;
      if (idZona != null) params['idZona'] = idZona.toString();
      final res = await _api.get('/ConductoresDisponibles', params: params);
      if (res.success && res.isList) {
        _conductoresDisponibles = res.list
            .map((e) => ConductorModel.fromJson(e as Map<String, dynamic>))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _buscandoConductor = true;
    notifyListeners();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_currentRide == null) return;
    try {
      final res = await _api.get('/ObtenerEstadoServicio', params: {
        'idServicio': _currentRide!.id.toString(),
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.firstOrNull() is Map) {
        final data = res.firstOrNull() as Map<String, dynamic>;
        _currentRide = RideModel.fromJson(data);
        _buscandoConductor = _currentRide?.idConductor == null &&
            (_currentRide?.estatus ?? '').toLowerCase() == 'solicitado';
        notifyListeners();
        var estatus = (_currentRide?.estatus ?? '').toLowerCase();
        if (estatus == 'finalizado' || estatus.contains('cancel') || estatus.contains('lleg')) {
          _pollTimer?.cancel();
        }
      }
    } catch (_) {}
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _buscandoConductor = false;
    notifyListeners();
  }

  Future<bool> cancelarServicio({String? motivo}) async {
    if (_currentRide == null) return false;
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/CancelarServicio', body: {
        'idServicio': _currentRide!.id,
        'idPasajero': _auth.userId,
        'motivo': motivo,
      });
      _loading = false;
      if (res.success) {
        _pollTimer?.cancel();
        _buscandoConductor = false;
        _currentRide = null;
        notifyListeners();
        return true;
      }
      _error = res.message;
      notifyListeners();
      return false;
    } catch (e) {
      _loading = false;
      _error = 'Error al cancelar';
      notifyListeners();
      return false;
    }
  }

  Future<bool> calificarViaje(int idServicio, int calificacion, {String? comentarios}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/CalificarViaje', body: {
        'idServicio': idServicio,
        'idPasajero': _auth.userId,
        'calificacion': calificacion,
        'comentarios': comentarios,
      });
      _loading = false;
      notifyListeners();
      return res.success;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> activarAlarmaSOS(int idServicio) async {
    try {
      final res = await _api.post('/ActivarAlarmaSOS', body: {
        'idServicio': idServicio,
        'idPasajero': _auth.userId,
      });
      return res.success;
    } catch (_) {
      return false;
    }
  }

  Future<void> cargarHistorial({int pagina = 1, int tamano = 20}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get('/HistorialViajes', params: {
        'idPasajero': _auth.userId.toString(),
        'pagina': pagina.toString(),
        'tamano': tamano.toString(),
      });
      if (res.success && res.isList) {
        _historial = res.list
            .map((e) => RideModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<RideModel?> detalleViaje(int idServicio) async {
    try {
      final res = await _api.get('/DetalleViaje', params: {
        'idServicio': idServicio.toString(),
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.firstOrNull() is Map) {
        return RideModel.fromJson(res.firstOrNull() as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  void clearCurrentRide() {
    _pollTimer?.cancel();
    _currentRide = null;
    _buscandoConductor = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
