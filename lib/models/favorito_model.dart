class FavoritoModel {
  final int id;
  final int idPasajero;
  final String nombre;
  final String? direccion;
  final String lat;
  final String lng;
  final String? categoria;
  final bool activo;

  FavoritoModel({
    required this.id,
    required this.idPasajero,
    required this.nombre,
    this.direccion,
    required this.lat,
    required this.lng,
    this.categoria,
    this.activo = true,
  });

  factory FavoritoModel.fromJson(Map<String, dynamic> json) {
    return FavoritoModel(
      id: json['id'] ?? json['Id'] ?? 0,
      idPasajero: json['idpasajero'] ?? json['Idpasajero'] ?? 0,
      nombre: json['favoritonombre'] ?? json['Favoritonombre'] ?? '',
      direccion: json['direccionfavorito'] ?? json['Direccionfavorito'],
      lat: json['lat']?.toString() ?? json['Lat']?.toString() ?? '',
      lng: json['lng']?.toString() ?? json['Lng']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? json['Categoria']?.toString(),
      activo: json['activo'] != false,
    );
  }
}
