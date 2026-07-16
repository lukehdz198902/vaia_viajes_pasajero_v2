import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_response.dart';
import 'storage_service.dart';

class ApiService {
  final StorageService _storage;
  late String _baseUrl;

  ApiService(this._storage) {
    _baseUrl = '${ApiConfig.baseUrl}${ApiConfig.pasajeroEndpoint}';
  }

  String get baseUrl => _baseUrl;

  bool get _useMock => true;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.getSessionToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<ApiResponse> _handleResponse(http.Response response) async {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return ApiResponse.ok(null);
      final decoded = json.decode(response.body);
      return ApiResponse.ok(decoded);
    }
    String msg = 'Error del servidor';
    try {
      final body = json.decode(response.body);
      msg = body['message'] ?? body['mensaje'] ?? msg;
    } catch (_) {}
    return ApiResponse.error(msg, code: response.statusCode);
  }

  Future<ApiResponse> get(String endpoint, {Map<String, String>? params}) async {
    if (_useMock) return _mockGet(endpoint, params);
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (params != null && params.isNotEmpty) {
        uri = uri.replace(queryParameters: params);
      }
      final response = await http.get(uri, headers: await _headers())
          .timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  Future<ApiResponse> post(String endpoint, {Map<String, dynamic>? body}) async {
    if (_useMock) return _mockPost(endpoint, body);
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: await _headers(),
        body: body != null ? json.encode(body) : null,
      ).timeout(ApiConfig.timeout);
      return _handleResponse(response);
    } catch (e) {
      return ApiResponse.error('Error de conexion: ${e.toString()}');
    }
  }

  // ─── Mock responses ───────────────────────────────────────────────

  Future<ApiResponse> _mockGet(String endpoint, Map<String, String>? params) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (endpoint.contains('/ObtenerPerfil')) {
      return ApiResponse.ok([{
        'id': 1, 'idcompania': 1, 'nombre': 'María', 'appaterno': 'García',
        'apmaterno': 'López', 'correo': 'maria@ejemplo.com', 'telefono': '5551234567',
        'account': 'maria_g',
      }]);
    }
    if (endpoint.contains('/HistorialViajes')) {
      return ApiResponse.ok([
        {'id': 101, 'direccionorigen': 'Av. Reforma 123', 'direcciondestination': 'Polanco 456', 'costoestimado': 185.50, 'fechacreacion': '2026-07-14 10:30', 'estatus': 'Finalizado', 'calificacion': 5},
        {'id': 102, 'direccionorigen': 'Insurgentes Sur 789', 'direcciondestination': 'Condesa 101', 'costoestimado': 120.00, 'fechacreacion': '2026-07-13 15:45', 'estatus': 'Finalizado', 'calificacion': 4},
        {'id': 103, 'direccionorigen': 'Coyoacán 234', 'direcciondestination': 'Centro 567', 'costoestimado': 95.00, 'fechacreacion': '2026-07-12 09:15', 'estatus': 'Finalizado', 'calificacion': 5},
      ]);
    }
    if (endpoint.contains('/DetalleViaje')) {
      return ApiResponse.ok({
        'id': params?['idServicio'], 'direccionorigen': 'Av. Reforma 123',
        'direcciondestination': 'Polanco 456', 'costoestimado': 185.50,
        'costofinal': 185.50, 'distanciametros': 8500, 'fechacreacion': '2026-07-14 10:30',
        'estatus': 'Finalizado', 'calificacion': 5, 'comentarios': 'Excelente servicio',
        'conductor': {'nombre': 'Carlos', 'appaterno': 'Mendoza', 'calificacion': 4.8, 'unidad': 'Tsuru', 'placas': 'XYZ-123'},
      });
    }
    if (endpoint.contains('/ListarFavoritos')) {
      return ApiResponse.ok([
        {'id': 1, 'nombre': 'Casa', 'direccion': 'Av. Reforma 123'},
        {'id': 2, 'nombre': 'Trabajo', 'direccion': 'Insurgentes Sur 789'},
        {'id': 3, 'nombre': 'Gimnasio', 'direccion': 'Polanco 456'},
      ]);
    }
    if (endpoint.contains('/ObtenerPromociones')) {
      return ApiResponse.ok([
        {'id': 1, 'codigo': 'BIENVENIDO', 'descripcion': '50% de descuento en tu primer viaje', 'porcentaje_descuento': 50, 'vigencia': '2026-12-31'},
        {'id': 2, 'codigo': 'VIAJERO', 'descripcion': '\$50 de descuento en viajes nocturnos', 'montodescuento': 50, 'vigencia': '2026-12-31'},
      ]);
    }
    if (endpoint.contains('/ObtenerAvisos')) {
      return ApiResponse.ok([
        {'id': 1, 'titulo': 'Mantenimiento programado', 'contenido': 'La app estará en mantenimiento el domingo 2AM-4AM', 'fechapublicacion': '2026-07-10'},
      ]);
    }
    if (endpoint.contains('/ConductoresDisponibles')) {
      return ApiResponse.ok([
        {'id': 10, 'nombre': 'Carlos', 'appaterno': 'Mendoza', 'lat': '19.4326', 'lng': '-99.1332', 'unidad': 'Tsuru', 'placas': 'XYZ-123', 'calificacion': 4.8},
        {'id': 11, 'nombre': 'Ana', 'appaterno': 'López', 'lat': '19.4275', 'lng': '-99.1412', 'unidad': 'Versa', 'placas': 'ABC-789', 'calificacion': 4.9},
      ]);
    }
    if (endpoint.contains('/ObtenerEstadoServicio')) {
      return ApiResponse.ok({
        'id': 1001, 'idservicioestatus': 2, 'estatus': 'En Camino',
        'idconductor': 10, 'conductorNombre': 'Carlos Mendoza',
        'unidad': 'Tsuru', 'placas': 'XYZ-123',
        'lat_conductor': '19.4300', 'lng_conductor': '-99.1350',
        'duracionSegundos': 480, 'distanciametros': 2500,
      });
    }
    if (endpoint.contains('/ObtenerMensajesChat')) {
      return ApiResponse.ok([
        {'id': 1, 'emisor': 'Conductor', 'mensaje': 'Hola, ya voy en camino', 'fechaenvio': '10:35', 'leido': true},
        {'id': 2, 'emisor': 'Pasajero', 'mensaje': 'Perfecto, te espero', 'fechaenvio': '10:36', 'leido': true},
        {'id': 3, 'emisor': 'Conductor', 'mensaje': 'Llegaré en 5 minutos', 'fechaenvio': '10:38', 'leido': false},
      ]);
    }
    return ApiResponse.ok([]);
  }

  Future<ApiResponse> _mockPost(String endpoint, Map<String, dynamic>? body) async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (endpoint.contains('/SolicitarServicio')) {
      return ApiResponse.ok([{
        'id': 1001, 'idpasajero': body?['idPasajero'], 'estatus': 'Solicitado',
        'direccionorigen': body?['dirOrigen'], 'latorigen': body?['latOrigen'],
        'lngorigen': body?['lngOrigen'], 'direcciondestination': body?['dirDestino'],
        'latdestination': body?['latDestino'], 'lngdestination': body?['lngDestino'],
        'distanciametros': body?['distanciaMetros'], 'costoestimado': 150.00,
        'tipoviaje': body?['tipoviaje'] ?? 'URBANO',
      }]);
    }
    if (endpoint.contains('/CancelarServicio')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Servicio cancelado'}]);
    }
    if (endpoint.contains('/CalificarViaje')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Calificación guardada'}]);
    }
    if (endpoint.contains('/ActivarAlarmaSOS')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Alarma enviada'}]);
    }
    if (endpoint.contains('/ActualizarPerfil')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Perfil actualizado'}]);
    }
    if (endpoint.contains('/CambiarPassword')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Contraseña cambiada'}]);
    }
    if (endpoint.contains('/CambiarTelefono')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Teléfono actualizado'}]);
    }
    if (endpoint.contains('/AgregarFavorito')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Favorito agregado'}]);
    }
    if (endpoint.contains('/EliminarFavorito')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Favorito eliminado'}]);
    }
    if (endpoint.contains('/ValidarCodigoPromocional')) {
      return ApiResponse.ok([{'valido': true, 'descuento': 50, 'mensaje': 'Código válido'}]);
    }
    if (endpoint.contains('/EnviarMensajeChat')) {
      return ApiResponse.ok([{'resultado': 1, 'mensaje': 'Mensaje enviado'}]);
    }
    return ApiResponse.ok([{'resultado': 1}]);
  }
}
