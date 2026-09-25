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
  final String? marca;
  final String? submarca;
  final String? modelo;
  final int? numeroAsientos;
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
    this.marca,
    this.submarca,
    this.modelo,
    this.numeroAsientos,
    this.lat,
    this.lng,
    this.distanciaKm,
  });

  String get nombreCompleto => '$nombre $appaterno $apmaterno'.trim();

  /// Descripcion corta del vehiculo: "Marca Submarca Modelo".
  String get vehiculoDescripcion =>
      [marca, submarca, modelo].where((e) => e != null && e.toString().trim().isNotEmpty).join(' ').trim();

  factory ConductorModel.fromJson(Map<String, dynamic> json) {
    return ConductorModel(
      id: json['id'] ?? json['Id'] ?? 0,
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      appaterno: json['appaterno'] ?? json['Appaterno'] ?? '',
      apmaterno: json['apmaterno'] ?? json['Apmaterno'] ?? '',
      telefono: json['telefono'] ?? json['Telefono'],
      correo: json['correo'] ?? json['Correo'],
      fotoperfil: json['fotoperfil'] ?? json['Fotoperfil'],
      calificacion: (json['calificacionpromedio'] ?? json['Calificacionpromedio'] ?? json['calificacion'] ?? json['Calificacion'])?.toDouble(),
      totalViajes: json['totalviajes'] ?? json['Totalviajes'],
      unidad: json['unidad'] ?? json['Unidad'],
      placas: json['placas'] ?? json['Placas'],
      colorUnidad: json['colorhex'] ?? json['Colorhex'],
      marca: json['nombremarca']?.toString() ?? json['marca']?.toString(),
      submarca: json['nombresubmarca']?.toString() ?? json['submarca']?.toString(),
      modelo: json['modelo']?.toString(),
      numeroAsientos: json['numeroasientos'] is int ? json['numeroasientos'] : int.tryParse('${json['numeroasientos']}'),
      lat: json['ultimalat'] ?? json['Ultimalat'] ?? json['lat'] ?? json['Lat'],
      lng: json['ultimalng'] ?? json['Ultimalng'] ?? json['lng'] ?? json['Lng'],
      distanciaKm: (json['distancia_km'] ?? json['DistanciaKm'])?.toDouble(),
    );
  }
}
