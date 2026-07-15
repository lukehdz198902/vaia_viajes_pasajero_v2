class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;

  ApiResponse({required this.success, this.data, this.message, this.statusCode});

  factory ApiResponse.ok(dynamic data) => ApiResponse(success: true, data: data);
  factory ApiResponse.error(String msg, {int? code}) =>
      ApiResponse(success: false, message: msg, statusCode: code);

  bool get isList => data is List;
  bool get isMap => data is Map;
  List<dynamic> get list => data as List<dynamic>? ?? [];
  Map<String, dynamic> get map => data as Map<String, dynamic>? ?? {};

  dynamic firstOrNull() {
    if (data is List && data.length > 0) return data[0];
    if (data is Map) return data;
    return null;
  }

  int getResultado() {
    var item = firstOrNull();
    if (item is Map) return item['resultado'] ?? item['Resultado'] ?? 0;
    return 0;
  }

  String getMensaje() {
    var item = firstOrNull();
    if (item is Map) return item['mensaje'] ?? item['Mensaje'] ?? message ?? '';
    return message ?? '';
  }

  int? getNuevoId() {
    var item = firstOrNull();
    if (item is Map) return (item['id'] ?? item['Id'])?.toInt();
    return null;
  }
}
