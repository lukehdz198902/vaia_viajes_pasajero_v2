class MensajeChatModel {
  final int id;
  final int idServicio;
  final int idPasajero;
  final String mensaje;
  final bool esDelConductor;
  final String? fechaCreacion;

  MensajeChatModel({
    required this.id,
    required this.idServicio,
    required this.idPasajero,
    required this.mensaje,
    this.esDelConductor = false,
    this.fechaCreacion,
  });

  factory MensajeChatModel.fromJson(Map<String, dynamic> json) {
    return MensajeChatModel(
      id: json['id'] ?? json['Id'] ?? 0,
      idServicio: json['idservicio'] ?? json['Idservicio'] ?? 0,
      idPasajero: json['idpasajero'] ?? json['Idpasajero'] ?? 0,
      mensaje: json['mensaje'] ?? json['Mensaje'] ?? '',
      esDelConductor: json['tipomensaje'] == 'conductor' || json['Tipomensaje'] == 'conductor',
      fechaCreacion: json['fechacreacion'] ?? json['Fechacreacion'],
    );
  }
}
