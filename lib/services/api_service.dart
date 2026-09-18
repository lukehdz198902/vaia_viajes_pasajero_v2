import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import 'storage_service.dart';
import 'logger.dart';

class ApiService {
  final StorageService _storage;
  late String _baseUrl;

  ApiService(this._storage) {
    _baseUrl = ApiConfig.pasajeroBaseUrl;
  }

  String get baseUrl => _baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getSessionToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<ApiResponse> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return ApiResponse.ok(null);
      try {
        final decoded = json.decode(response.body);
        if (decoded is Map) {
          return ApiResponse.ok(
            decoded['data'] ?? decoded,
            message: decoded['message']?.toString(),
          );
        }
        return ApiResponse.ok(decoded);
      } catch (e) {
        Logger.e('ApiService', 'Error parseando respuesta exitosa: $e');
        return ApiResponse.ok(response.body);
      }
    }

    String msg = 'Error del servidor (${response.statusCode})';
    String? errorCode;
    try {
      final body = json.decode(response.body);
      if (body is Map) {
        msg = body['message'] ?? body['mensaje'] ?? body['error'] ?? msg;
        errorCode = body['code']?.toString();
      }
    } catch (_) {}
    Logger.w('ApiService', 'HTTP ${response.statusCode} en ${response.request?.url}: $msg');
    return ApiResponse.error(msg, code: response.statusCode, errorCode: errorCode);
  }

  Future<ApiResponse> get(String endpoint, {Map<String, String>? params}) async {
    final url = '$_baseUrl$endpoint';
    Logger.apiRequest('GET', url, params?.cast<String, dynamic>());
    try {
      var uri = Uri.parse(url);
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: {
          for (var e in params.entries) e.key: e.value,
        });
      }
      final response = await http
          .get(uri, headers: await _headers())
          .timeout(ApiConfig.timeout);
      Logger.apiResponse('GET', url, response.statusCode, response.body);
      return _handleResponse(response);
    } catch (e) {
      Logger.apiError('GET', url, e);
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  Future<ApiResponse> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = '$_baseUrl$endpoint';
    Logger.apiRequest('POST', url, body);
    try {
      final uri = Uri.parse(url);
      final response = await http
          .post(
            uri,
            headers: await _headers(),
            body: body != null ? json.encode(body) : null,
          )
          .timeout(ApiConfig.timeout);
      Logger.apiResponse('POST', url, response.statusCode, response.body);
      return _handleResponse(response);
    } catch (e) {
      Logger.apiError('POST', url, e);
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  /// Llama a un endpoint de otro controlador (ej. Servicio, Soporte) que no
  /// cuelga de /Pasajero. `controller` es el nombre sin slash, ej. "Servicio".
  String _rootUrl(String controller, String action) => '${ApiConfig.apiRoot}/$controller/$action';

  Future<ApiResponse> getRoot(String controller, String action, {Map<String, String>? params}) async {
    final url = _rootUrl(controller, action);
    try {
      var uri = Uri.parse(url);
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: params);
      }
      final response = await http.get(uri, headers: await _headers()).timeout(ApiConfig.timeout);
      Logger.apiResponse('GET', url, response.statusCode, response.body);
      return _handleResponse(response);
    } catch (e) {
      Logger.apiError('GET', url, e);
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  Future<ApiResponse> postRoot(String controller, String action, {Map<String, dynamic>? body}) async {
    final url = _rootUrl(controller, action);
    try {
      final uri = Uri.parse(url);
      final response = await http
          .post(uri, headers: await _headers(), body: body != null ? json.encode(body) : null)
          .timeout(ApiConfig.timeout);
      Logger.apiResponse('POST', url, response.statusCode, response.body);
      return _handleResponse(response);
    } catch (e) {
      Logger.apiError('POST', url, e);
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  // ─── PAGO EN LINEA ───────────────────────────────────────────

  Future<ApiResponse> mercadoPagoPreferencia(int idServicio) =>
      postRoot('Pago', 'MercadoPagoPreferencia', body: { 'idServicio': idServicio });

  Future<ApiResponse> mercadoPagoConfirmar(int idServicio, String paymentId) =>
      postRoot('Pago', 'MercadoPagoConfirmar', body: { 'idServicio': idServicio, 'paymentId': paymentId });

  Future<ApiResponse> paypalCrearOrden(int idServicio) =>
      postRoot('Pago', 'PayPalCrearOrden', body: { 'idServicio': idServicio });

  Future<ApiResponse> paypalCapturar(int idServicio, String orderId) =>
      postRoot('Pago', 'PayPalCapturar', body: { 'idServicio': idServicio, 'orderId': orderId });

  /// Registra/actualiza el token de notificaciones push (FCM) del pasajero.
  Future<ApiResponse> actualizarToken(int idPasajero, String token) =>
      postRoot('Pasajero', 'ActualizarToken', body: {
        'idPasajero': idPasajero,
        'googlekey': token,
      });

  /// Obtiene la configuracion de tarifas (costo minimo, por km, por minuto).
  Future<ApiResponse> obtenerConfiguracionCostos(int idCompania) =>
      get('/ObtenerConfiguracionCostos', params: {'idCompania': idCompania.toString()});

  // ─── PARADAS INTERMEDIAS ─────────────────────────────────────

  Future<ApiResponse> agregarParada(int idServicio, int orden, String direccion, String lat, String lng, {String? referencia, String? notas}) =>
      postRoot('Servicio', 'AgregarParada', body: {
        'idservicio': idServicio,
        'orden': orden,
        'direccion': direccion,
        'lat': lat,
        'lng': lng,
        if (referencia != null) 'referencia': referencia,
        if (notas != null) 'notas': notas,
      });

  Future<ApiResponse> listarParadas(int idServicio) =>
      getRoot('Servicio', 'ListarParadas', params: {'idservicio': idServicio.toString()});

  Future<ApiResponse> completarParada(int idParada, int idConductor) =>
      postRoot('Servicio', 'CompletarParada', body: {'idParada': idParada, 'idConductor': idConductor});

  Future<ApiResponse> eliminarParada(int idParada) =>
      postRoot('Servicio', 'EliminarParada', body: {'idParada': idParada});

  // ─── SERVICIOS PROGRAMADOS ───────────────────────────────────

  Future<ApiResponse> programarServicio(Map<String, dynamic> data) =>
      postRoot('Servicio', 'Programar', body: data);

  Future<ApiResponse> listarProgramados(int idPasajero, {String? estado}) =>
      getRoot('Servicio', 'ListarProgramados', params: {
        'idPasajero': idPasajero.toString(),
        if (estado != null) 'estado': estado,
      });

  Future<ApiResponse> obtenerProgramado(int id, int idPasajero) =>
      getRoot('Servicio', 'ObtenerProgramado', params: {
        'id': id.toString(),
        'idPasajero': idPasajero.toString(),
      });

  Future<ApiResponse> cancelarProgramado(int id, int idPasajero, {String? motivo}) =>
      postRoot('Servicio', 'CancelarProgramado', body: {
        'id': id,
        'idPasajero': idPasajero,
        if (motivo != null) 'motivo': motivo,
      });

  // ─── SOPORTE ─────────────────────────────────────────────────

  Future<ApiResponse> crearSolicitudSoporte(int idServicio, int idPasajero, String asunto, String descripcion, {String prioridad = 'Normal'}) =>
      postRoot('Soporte', 'CrearSolicitud', body: {
        'idservicio': idServicio,
        'idpasajero': idPasajero,
        'tipoSolicitante': 'pasajero',
        'asunto': asunto,
        'descripcion': descripcion,
        'prioridad': prioridad,
      });

  Future<ApiResponse> listarSolicitudesSoporte({String? estatus, int pagina = 1, int tamano = 50}) =>
      getRoot('Soporte', 'ListarSolicitudes', params: {
        if (estatus != null) 'estatus': estatus,
        'pagina': pagina.toString(),
        'tamano': tamano.toString(),
      });

  Future<ApiResponse> obtenerSolicitudSoporte(int id) =>
      getRoot('Soporte', 'ObtenerSolicitud', params: {'id': id.toString()});

  Future<ApiResponse> enviarMensajeSoporte(int idSolicitud, String emisor, int idEmisor, String nombreEmisor, String mensaje) =>
      postRoot('Soporte', 'EnviarMensaje', body: {
        'idsolicitud': idSolicitud,
        'emisor': emisor,
        'idemisor': idEmisor,
        'nombreEmisor': nombreEmisor,
        'mensaje': mensaje,
      });

  Future<ApiResponse> listarMensajesSoporte(int idSolicitud) =>
      getRoot('Soporte', 'ListarMensajes', params: {'idsolicitud': idSolicitud.toString()});

  Future<ApiResponse> cerrarSolicitudSoporte(int id, {int? idUsuarioSoporte, String? comentario}) =>
      postRoot('Soporte', 'CerrarSolicitud', body: {
        'id': id,
        if (idUsuarioSoporte != null) 'idUsuarioSoporte': idUsuarioSoporte,
        if (comentario != null) 'comentario': comentario,
      });

  // ─── VERIFICACION DE CORREO / GOOGLE ─────────────────────────

  Future<ApiResponse> enviarCodigoCorreo(int idPasajero, {String? correoNuevo}) =>
      post('/EnviarCodigoCorreo', body: {
        'idPasajero': idPasajero,
        if (correoNuevo != null) 'correoNuevo': correoNuevo,
      });

  Future<ApiResponse> validarCodigoCorreo(int idPasajero, String codigo) =>
      post('/ValidarCodigoCorreo', body: {'idPasajero': idPasajero, 'codigo': codigo});

  Future<ApiResponse> cambiarCorreo(int idPasajero, String correoNuevo, String codigo) =>
      post('/CambiarCorreo', body: {'idPasajero': idPasajero, 'correoNuevo': correoNuevo, 'codigo': codigo});

  Future<ApiResponse> iniciarSesionGoogle(String idToken, {int idCompania = 1, String? googlekey}) =>
      post('/IniciarSesionGoogle', body: {
        'idToken': idToken,
        'idCompania': idCompania,
        if (googlekey != null) 'googlekey': googlekey,
      });
}