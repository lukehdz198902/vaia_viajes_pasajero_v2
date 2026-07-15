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
}
