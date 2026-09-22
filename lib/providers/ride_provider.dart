import 'dart:async';
import 'package:flutter/material.dart';
import '../models/ride_model.dart';
import '../models/conductor_model.dart';
import '../models/parada_model.dart';
import '../models/servicio_programado_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/logger.dart';
import 'auth_provider.dart';

class RideProvider extends ChangeNotifier {
  final ApiService _api;
  final SignalRService _signalr;
  AuthProvider _auth;

  RideProvider(this._api, this._signalr, this._auth) {
    _suscribirSignalR();
  }

  void updateAuth(AuthProvider auth) => _auth = auth;

  RideModel? _currentRide;
  List<ConductorModel> _conductoresDisponibles = [];
  List<RideModel> _historial = [];
  List<ParadaModel> _paradas = [];
  List<ServicioProgramadoModel> _programados = [];
  bool _loading = false;
  String? _error;
  bool _buscandoConductor = false;
  Timer? _pollTimer;
  Timer? _presenceTimer;
  int _idPasajeroPresencia = 0;
  int _pollCount = 0;
  bool _useSimulation = false;
  bool _conectadoWs = false;
  double? _conductorLat;
  double? _conductorLng;
  StreamSubscription? _subEventos;
  StreamSubscription? _subConexion;

  RideModel? get currentRide => _currentRide;
  List<ConductorModel> get conductoresDisponibles => _conductoresDisponibles;
  List<RideModel> get historial => _historial;
  List<ParadaModel> get paradas => _paradas;
  List<ServicioProgramadoModel> get programados => _programados;
  bool get loading => _loading;
  bool get buscandoConductor => _buscandoConductor;
  String? get error => _error;
  bool get useSimulation => _useSimulation;
  bool get conectadoWs => _conectadoWs;
  double? get conductorLat => _conductorLat;
  double? get conductorLng => _conductorLng;

  // ─── SIGNALR ─────────────────────────────────────────────────

  void _suscribirSignalR() {
    _subEventos = _signalr.eventos.listen(_onRealtimeEvent);
    _subConexion = _signalr.estadoConexion.listen((c) {
      _conectadoWs = c;
      notifyListeners();
    });
  }

  void _onRealtimeEvent(RealtimeEvent event) {
    Logger.i('Ride', 'Realtime: ${event.tipo}');
    switch (event.tipo) {
      case 'ServicioAceptado':
        if (_currentRide != null) {
          _buscandoConductor = false;
          _currentRide = RideModel.fromJson({
            ..._currentRide!.toJson(),
            'idconductor': event.data['idConductor'],
            'estatus': 'En Camino',
            'c_nombre': event.data['conductorNombre'] ?? 'Conductor',
          });
          _pollTimer?.cancel();
          notifyListeners();
        }
        break;
      case 'EstatusCambiado':
        if (_currentRide != null) {
          final estatus = event.data['estatus']?.toString();
          if (estatus != null && estatus != 'ParadaAgregada' && estatus != 'ParadaCompletada') {
            _currentRide = RideModel.fromJson({
              ..._currentRide!.toJson(),
              'estatus': estatus,
            });
            notifyListeners();
          }
        }
        break;
      case 'UbicacionConductor':
        final lat = double.tryParse(event.data['lat']?.toString() ?? '');
        final lng = double.tryParse(event.data['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          _conductorLat = lat;
          _conductorLng = lng;
          notifyListeners();
        }
        break;
      case 'CostoActualizado':
        // Taximetro: costo en vivo durante el viaje
        final costo = double.tryParse(event.data['costo']?.toString() ?? '');
        if (_currentRide != null && costo != null) {
          _currentRide = RideModel.fromJson({
            ..._currentRide!.toJson(),
            'costoencurso': costo,
          });
          notifyListeners();
        }
        break;
      case 'ServicioCancelado':
        _currentRide = null;
        _buscandoConductor = false;
        _pollTimer?.cancel();
        notifyListeners();
        break;
    }
  }

  // ─── SERVICIO ────────────────────────────────────────────────

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
    List<Map<String, dynamic>> paradas = const [],
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      Logger.i('Ride', 'solicitarServicio: origen=$dirOrigen destino=$dirDestino paradas=${paradas.length}');
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
        final idServicio = _toInt(data['idservicio'] ?? data['id']);
        _currentRide = RideModel.fromJson({
          ...data,
          'id': idServicio,
          'idpasajero': _auth.userId,
          'direccionorigen': dirOrigen,
          'latorigen': latOrigen,
          'lngorigen': lngOrigen,
          'direcciondestination': dirDestino,
          'latdestination': latDestino,
          'lngdestination': lngDestino,
          'estatus': 'Solicitado',
        });

        // Registrar paradas si las hay
        if (paradas.isNotEmpty && idServicio > 0) {
          for (var i = 0; i < paradas.length; i++) {
            final p = paradas[i];
            await _api.agregarParada(
              idServicio,
              i + 1,
              p['direccion']?.toString() ?? '',
              p['lat']?.toString() ?? '0',
              p['lng']?.toString() ?? '0',
              referencia: p['referencia']?.toString(),
            );
          }
          await listarParadas(idServicio);
        }

        // Unirse al WebSocket del servicio
        if (idServicio > 0) {
          await _signalr.unirseAServicio(idServicio);
        }

        _loading = false;
        notifyListeners();
        _startPolling();
        return true;
      }
      _error = res.getMensaje().isNotEmpty ? res.getMensaje() : (res.message ?? 'Error al solicitar servicio');
      _loading = false;
      notifyListeners();
      return false;
    } catch (e) {
      Logger.e('Ride', 'solicitarServicio: $e');
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
            .map((e) => ConductorModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _buscandoConductor = true;
    _pollCount = 0;
    _useSimulation = false;
    notifyListeners();
    // El polling es respaldo del WebSocket: si el WS esta conectado, espaciamos mas
    final intervalo = _conectadoWs ? const Duration(seconds: 15) : const Duration(seconds: 5);
    _pollTimer = Timer.periodic(intervalo, (_) => _checkStatus());
  }

  /// Recupera el servicio en curso al reabrir la app y reanuda el seguimiento.
  Future<bool> restaurarServicioActivo(int idPasajero) async {
    try {
      final res = await _api.get('/ObtenerServicioActivo', params: {'idPasajero': idPasajero.toString()});
      if (res.success && res.firstOrNull() is Map) {
        final data = Map<String, dynamic>.from(res.firstOrNull() as Map);
        _currentRide = RideModel.fromJson(data);
        _buscandoConductor = _currentRide?.idConductor == null;
        notifyListeners();
        try { await _signalr.unirseAServicio(_currentRide!.id); } catch (_) {}
        await listarParadas(_currentRide!.id);
        _startPolling();
        return true;
      }
    } catch (e) {
      Logger.e('Ride', 'restaurarServicioActivo error: $e');
    }
    return false;
  }

  Future<void> _checkStatus() async {
    if (_currentRide == null) return;
    _pollCount++;
    try {
      final res = await _api.get('/ObtenerEstadoServicio', params: {
        'idServicio': _currentRide!.id.toString(),
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.firstOrNull() is Map) {
        final data = Map<String, dynamic>.from(res.firstOrNull() as Map);
        _currentRide = RideModel.fromJson(data);
        var estatus = (_currentRide?.estatus ?? '').toLowerCase();
        _buscandoConductor = _currentRide?.idConductor == null && estatus == 'solicitado';
        notifyListeners();
        if (estatus == 'finalizado' || estatus.contains('cancel') || estatus.contains('lleg')) {
          _pollTimer?.cancel();
        }
      }
    } catch (_) {
      Logger.e('Ride', 'Status poll error');
    }
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
        await _signalr.salirDeServicio(_currentRide!.id);
        _currentRide = null;
        _paradas.clear();
        notifyListeners();
        return true;
      }
      _error = res.getMensaje();
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
      if (res.success) {
        await _signalr.salirDeServicio(idServicio);
      }
      notifyListeners();
      return res.success;
    } catch (e) {
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> iniciarServicio(int idServicio, String codigoInicio) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.post('/IniciarServicio', body: {
        'idServicio': idServicio,
        'idPasajero': _auth.userId,
        'codigoInicio': codigoInicio,
      });
      _loading = false;
      if (res.success) {
        if (_currentRide != null) {
          _currentRide = RideModel.fromJson({
            ..._currentRide!.toJson(),
            'estatus': 'En Viaje',
            'servicioiniciado': true,
          });
        }
        notifyListeners();
        return true;
      }
      _error = res.getMensaje().isNotEmpty ? res.getMensaje() : 'Error al iniciar servicio';
      notifyListeners();
      return false;
    } catch (e) {
      _loading = false;
      _error = 'Error de conexion';
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
            .map((e) => RideModel.fromJson(Map<String, dynamic>.from(e as Map)))
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
        return RideModel.fromJson(Map<String, dynamic>.from(res.firstOrNull() as Map));
      }
    } catch (_) {}
    return null;
  }

  // ─── PARADAS ─────────────────────────────────────────────────

  Future<void> listarParadas(int idServicio) async {
    try {
      final res = await _api.listarParadas(idServicio);
      _paradas.clear();
      if (res.success && res.isList) {
        for (final item in res.list) {
          if (item is Map) {
            _paradas.add(ParadaModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      notifyListeners();
    } catch (e) {
      Logger.e('Ride', 'listarParadas: $e');
    }
  }

  Future<bool> agregarParada(int idServicio, int orden, String direccion, String lat, String lng, {String? referencia}) async {
    try {
      final res = await _api.agregarParada(idServicio, orden, direccion, lat, lng, referencia: referencia);
      if (res.success) {
        await listarParadas(idServicio);
        return true;
      }
      _error = res.getMensaje();
      notifyListeners();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> eliminarParada(int idParada) async {
    try {
      final res = await _api.eliminarParada(idParada);
      if (res.success && _currentRide != null) {
        await listarParadas(_currentRide!.id);
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── SERVICIOS PROGRAMADOS ───────────────────────────────────

  Future<int?> programarServicio({
    required String dirOrigen,
    required String latOrigen,
    required String lngOrigen,
    required String dirDestino,
    required String latDestino,
    required String lngDestino,
    required DateTime fechaProgramada,
    int idTipoPago = 1,
    int anticipacionMinutos = 15,
    List<Map<String, dynamic>> paradas = const [],
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.programarServicio({
        'idPasajero': _auth.userId,
        'idCompania': _auth.idCompania,
        'dirOrigen': dirOrigen,
        'latOrigen': latOrigen,
        'lngOrigen': lngOrigen,
        'dirDestino': dirDestino,
        'latDestino': latDestino,
        'lngDestino': lngDestino,
        'fechaProgramada': fechaProgramada.toIso8601String(),
        'anticipacionMinutos': anticipacionMinutos,
        'idTipoPago': idTipoPago,
        if (paradas.isNotEmpty) 'paradasJson': _encodeParadas(paradas),
      });
      _loading = false;
      if (res.success) {
        notifyListeners();
        return res.getNuevoId();
      }
      _error = res.getMensaje();
      notifyListeners();
      return null;
    } catch (e) {
      Logger.e('Ride', 'programarServicio: $e');
      _error = 'Error de conexion';
      _loading = false;
      notifyListeners();
      return null;
    }
  }

  String _encodeParadas(List<Map<String, dynamic>> paradas) {
    final list = paradas.asMap().entries.map((e) => {
      'orden': e.key + 1,
      'dir': e.value['direccion'] ?? '',
      'lat': e.value['lat'] ?? '0',
      'lng': e.value['lng'] ?? '0',
      'ref': e.value['referencia'] ?? '',
    }).toList();
    return _jsonEncode(list);
  }

  String _jsonEncode(Object obj) {
    final buffer = StringBuffer();
    _writeJson(buffer, obj);
    return buffer.toString();
  }

  void _writeJson(StringBuffer b, Object? o) {
    if (o == null) { b.write('null'); return; }
    if (o is String) { b.write(_escape(o)); return; }
    if (o is num || o is bool) { b.write(o.toString()); return; }
    if (o is List) {
      b.write('[');
      for (var i = 0; i < o.length; i++) { if (i > 0) b.write(','); _writeJson(b, o[i]); }
      b.write(']');
      return;
    }
    if (o is Map) {
      b.write('{');
      var first = true;
      o.forEach((k, v) { if (!first) b.write(','); first = false; b.write(_escape(k.toString())); b.write(':'); _writeJson(b, v); });
      b.write('}');
      return;
    }
    b.write(_escape(o.toString()));
  }

  String _escape(String s) {
    final sb = StringBuffer('"');
    for (final r in s.runes) {
      final c = String.fromCharCode(r);
      switch (c) {
        case '"': sb.write('\\"'); break;
        case '\\': sb.write('\\\\'); break;
        case '\n': sb.write('\\n'); break;
        case '\r': sb.write('\\r'); break;
        case '\t': sb.write('\\t'); break;
        default: sb.write(c);
      }
    }
    sb.write('"');
    return sb.toString();
  }

  Future<void> cargarProgramados({String? estado}) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.listarProgramados(_auth.userId, estado: estado);
      _programados.clear();
      if (res.success && res.isList) {
        for (final item in res.list) {
          if (item is Map) {
            _programados.add(ServicioProgramadoModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
    } catch (e) {
      Logger.e('Ride', 'cargarProgramados: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> cancelarProgramado(int id, {String? motivo}) async {
    try {
      final res = await _api.cancelarProgramado(id, _auth.userId, motivo: motivo);
      if (res.success) {
        await cargarProgramados();
        return true;
      }
      _error = res.getMensaje();
      notifyListeners();
      return false;
    } catch (_) {
      return false;
    }
  }

  void clearCurrentRide() {
    _pollTimer?.cancel();
    _currentRide = null;
    _buscandoConductor = false;
    _useSimulation = false;
    _pollCount = 0;
    _paradas.clear();
    _conductorLat = null;
    _conductorLng = null;
    notifyListeners();
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  // ─── PRESENCIA (ligera) ──────────────────────────────────────
  //
  // El pasajero NO reporta su ubicacion de forma constante (para no
  // cargar el servidor con miles de usuarios). Solo envia un latido
  // para que el sistema sepa que esta usando la app. Los origenes se
  // registran del lado del servidor al solicitar un servicio.

  void iniciarPresencia(int idPasajero) {
    if (idPasajero <= 0) return;
    if (_idPasajeroPresencia == idPasajero && _presenceTimer != null) return;

    _idPasajeroPresencia = idPasajero;
    _presenceTimer?.cancel();

    _signalr.latido();
    _presenceTimer = Timer.periodic(const Duration(seconds: 60), (_) => _signalr.latido());
  }

  void detenerPresencia() {
    _presenceTimer?.cancel();
    _presenceTimer = null;
    _idPasajeroPresencia = 0;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    detenerPresencia();
    _subEventos?.cancel();
    _subConexion?.cancel();
    super.dispose();
  }
}