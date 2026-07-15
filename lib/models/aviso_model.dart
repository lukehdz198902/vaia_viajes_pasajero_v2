class AvisoModel {
  final int id;
  final String? titulo;
  final String? descripcion;
  final bool esAvisoPasajero;
  final bool activo;

  AvisoModel({
    required this.id,
    this.titulo,
    this.descripcion,
    this.esAvisoPasajero = true,
    this.activo = true,
  });

  factory AvisoModel.fromJson(Map<String, dynamic> json) {
    return AvisoModel(
      id: json['id'] ?? json['Id'] ?? 0,
      titulo: json['tituloaviso'] ?? json['Tituloaviso'],
      descripcion: json['descripcionaviso'] ?? json['Descripcionaviso'],
      esAvisoPasajero: json['esavisopasajero'] == true || json['Esavisopasajero'] == true,
      activo: json['activo'] != false,
    );
  }
}
