import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mensaje_chat_model.dart';
import '../services/api_service.dart';
import '../services/signalr_service.dart';
import '../services/logger.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  final SignalRService _signalr;
  AuthProvider _auth;

  ChatProvider(this._api, this._signalr, this._auth) {
    _suscribirSignalR();
  }

  void updateAuth(AuthProvider auth) => _auth = auth;

  List<MensajeChatModel> _mensajes = [];
  bool _loading = false;
  bool _enviando = false;
  Timer? _pollTimer;
  int _idServicioActivo = 0;
  StreamSubscription? _subChat;

  List<MensajeChatModel> get mensajes => _mensajes;
  bool get loading => _loading;
  bool get enviando => _enviando;

  void _suscribirSignalR() {
    _subChat = _signalr.chatEventos.listen((event) {
      if (event.tipo == 'NuevoMensaje') {
        final idServicio = _toInt(event.data['idServicio']);
        if (idServicio != _idServicioActivo) return;
        final emisor = event.data['emisor']?.toString() ?? '';
        // Solo agregar los del conductor (los del pasajero ya se agregan localmente)
        if (emisor == 'conductor') {
          _mensajes.add(MensajeChatModel(
            id: _toInt(event.data['id'] ?? DateTime.now().millisecondsSinceEpoch),
            idServicio: idServicio,
            idPasajero: _auth.userId,
            mensaje: event.data['mensaje']?.toString() ?? '',
            esDelConductor: true,
            fechaCreacion: event.data['fecha']?.toString(),
          ));
          notifyListeners();
        }
      }
    });
  }

  /// Carga los mensajes y se une al chat en tiempo real.
  Future<void> iniciarChat(int idServicio) async {
    _idServicioActivo = idServicio;
    await cargarMensajes(idServicio);
    await _signalr.unirseAlChat(idServicio);
    // Polling de respaldo cada 20s por si el WS se cae
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) => cargarMensajes(idServicio));
  }

  Future<void> cargarMensajes(int idServicio) async {
    _loading = true;
    notifyListeners();
    Logger.i('Chat', 'cargarMensajes: idServicio=$idServicio');
    try {
      final res = await _api.get('/ObtenerMensajesChat', params: {
        'idServicio': idServicio.toString(),
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.isList) {
        _mensajes = res.list
            .map((e) => MensajeChatModel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
    } catch (e) {
      Logger.e('Chat', 'cargarMensajes: $e');
    }
    _loading = false;
    notifyListeners();
  }

  Future<bool> enviarMensaje(int idServicio, String mensaje) async {
    if (mensaje.trim().isEmpty) return false;
    _enviando = true;
    notifyListeners();
    try {
      final res = await _api.post('/EnviarMensajeChat', body: {
        'idServicio': idServicio,
        'idPasajero': _auth.userId,
        'mensaje': mensaje.trim(),
      });
      if (res.success) {
        _mensajes.add(MensajeChatModel(
          id: DateTime.now().millisecondsSinceEpoch,
          idServicio: idServicio,
          idPasajero: _auth.userId,
          mensaje: mensaje.trim(),
          esDelConductor: false,
          fechaCreacion: DateTime.now().toIso8601String(),
        ));
        // Notificar por WebSocket
        await _signalr.enviarMensajeChat(idServicio, mensaje.trim(), _auth.user?.nombreCompleto ?? 'Pasajero');
        _enviando = false;
        notifyListeners();
        return true;
      }
      _enviando = false;
      notifyListeners();
      return false;
    } catch (e) {
      Logger.e('Chat', 'enviarMensaje: $e');
      _enviando = false;
      notifyListeners();
      return false;
    }
  }

  void notificarEscribiendo() {
    if (_idServicioActivo > 0) _signalr.notificarEscribiendo(_idServicioActivo);
  }

  /// Mantener compatibilidad con el codigo existente.
  void startPolling(int idServicio) => iniciarChat(idServicio);

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (_idServicioActivo > 0) {
      _signalr.salirDelChat(_idServicioActivo);
      _idServicioActivo = 0;
    }
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _subChat?.cancel();
    super.dispose();
  }
}