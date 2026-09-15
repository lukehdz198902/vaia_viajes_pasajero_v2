class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;
  final String? errorCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
    this.errorCode,
  });

  factory ApiResponse.ok(dynamic data, {String? message}) =>
      ApiResponse(success: true, data: data, message: message);

  factory ApiResponse.error(String msg, {int? code, String? errorCode}) =>
      ApiResponse(success: false, message: msg, statusCode: code, errorCode: errorCode);

  bool get isList => data is List;
  bool get isMap => data is Map;
  List<dynamic> get list => data is List ? data : (data is Map ? (data['data'] is List ? data['data'] : <dynamic>[]) : <dynamic>[]);
  Map<String, dynamic> get map {
    if (data is Map<String, dynamic>) return data as Map<String, dynamic>;
    if (data is Map && (data as Map).isNotEmpty) return Map<String, dynamic>.from(data as Map);
    return <String, dynamic>{};
  }

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
    if (message != null && message!.isNotEmpty) return message!;
    var item = firstOrNull();
    if (item is Map) return item['mensaje'] ?? item['Mensaje'] ?? '';
    return '';
  }

  int? getNuevoId() {
    var item = firstOrNull();
    if (item is Map) return (item['id'] ?? item['Id'])?.toInt();
    if (item is int) return item;
    if (item is double) return item.toInt();
    if (item is num) return item.toInt();
    if (item is String) return int.tryParse(item);
    if (data is int) return data;
    if (data is num) return (data as num).toInt();
    return null;
  }
}