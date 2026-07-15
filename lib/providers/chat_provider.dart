import 'dart:async';
import 'package:flutter/material.dart';
import '../models/mensaje_chat_model.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _api;
  AuthProvider _auth;

  ChatProvider(this._api, this._auth);

  void updateAuth(AuthProvider auth) => _auth = auth;

  List<MensajeChatModel> _mensajes = [];
  bool _loading = false;
  Timer? _pollTimer;

  List<MensajeChatModel> get mensajes => _mensajes;
  bool get loading => _loading;

  Future<void> cargarMensajes(int idServicio) async {
    _loading = true;
    notifyListeners();
    try {
      final res = await _api.get('/ObtenerMensajesChat', params: {
        'idServicio': idServicio.toString(),
        'idPasajero': _auth.userId.toString(),
      });
      if (res.success && res.isList) {
        _mensajes = res.list
            .map((e) => MensajeChatModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    _loading = false;
    notifyListeners();
  }

  Future<bool> enviarMensaje(int idServicio, String mensaje) async {
    try {
      final res = await _api.post('/EnviarMensajeChat', body: {
        'idServicio': idServicio,
        'idPasajero': _auth.userId,
        'mensaje': mensaje,
      });
      if (res.success) {
        _mensajes.add(MensajeChatModel(
          id: DateTime.now().millisecondsSinceEpoch,
          idServicio: idServicio,
          idPasajero: _auth.userId,
          mensaje: mensaje,
          esDelConductor: false,
        ));
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void startPolling(int idServicio) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      cargarMensajes(idServicio);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
