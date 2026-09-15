class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.vaia.com.mx/apis_v2/api/Pasajero',
  );

  static const String hostBaseUrl = String.fromEnvironment(
    'HOST_BASE_URL',
    defaultValue: 'https://app.vaia.com.mx/apis_v2',
  );

  static const String pasajeroEndpoint = '/Pasajero';
  static const Duration timeout = Duration(seconds: 30);
  static const Duration shortTimeout = Duration(seconds: 10);

  static String get pasajeroBaseUrl =>
      baseUrl.endsWith('/Pasajero') ? baseUrl : '$baseUrl$pasajeroEndpoint';

  static String get apiRoot =>
      baseUrl.endsWith('/Pasajero') ? baseUrl.substring(0, baseUrl.length - '/Pasajero'.length) : baseUrl;

  static String get servicioHubUrl => '$hostBaseUrl/hubs/servicio';
  static String get chatHubUrl => '$hostBaseUrl/hubs/chat';
  static String get soporteHubUrl => '$hostBaseUrl/hubs/soporte';
}