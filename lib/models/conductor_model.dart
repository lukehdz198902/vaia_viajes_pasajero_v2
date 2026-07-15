class ConductorModel {
  final int id;
  final String nombre;
  final String appaterno;
  final String apmaterno;
  final String? telefono;
  final String? correo;
  final String? fotoperfil;
  final double? calificacion;
  final int? totalViajes;
  final String? unidad;
  final String? placas;
  final String? colorUnidad;
  final String? lat;
  final String? lng;
  final double? distanciaKm;

  ConductorModel({
    required this.id,
    required this.nombre,
    required this.appaterno,
    this.apmaterno = '',
    this.telefono,
    this.correo,
    this.fotoperfil,
    this.calificacion,
    this.totalViajes,
    this.unidad,
    this.placas,
    this.colorUnidad,
    this.lat,
    this.lng,
    this.distanciaKm,
  });

  String get nombreCompleto => '$nombre $appaterno $apmaterno'.trim();

  factory ConductorModel.fromJson(Map<String, dynamic> json) {
    return ConductorModel(
      id: json['id'] ?? json['Id'] ?? 0,
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      appaterno: json['appaterno'] ?? json['Appaterno'] ?? '',
      apmaterno: json['apmaterno'] ?? json['Apmaterno'] ?? '',
      telefono: json['telefono'] ?? json['Telefono'],
      correo: json['correo'] ?? json['Correo'],
      fotoperfil: json['fotoperfil'] ?? json['Fotoperfil'],
      calificacion: json['calificacionpromedio'] ?? json['Calificacionpromedio'],
      totalViajes: json['totalviajes'] ?? json['Totalviajes'],
      unidad: json['unidad'] ?? json['Unidad'],
      placas: json['placas'] ?? json['Placas'],
      colorUnidad: json['colorhex'] ?? json['Colorhex'],
      lat: json['ultimalat'] ?? json['Ultimalat'],
      lng: json['ultimalng'] ?? json['Ultimalng'],
      distanciaKm: (json['distancia_km'] ?? json['DistanciaKm'])?.toDouble(),
    );
  }
}
