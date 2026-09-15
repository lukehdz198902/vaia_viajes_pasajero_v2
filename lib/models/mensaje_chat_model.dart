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
    var esDelConductor = false;
    if (json['tipomensaje'] != null) {
      esDelConductor = json['tipomensaje'] == 'conductor' || json['Tipomensaje'] == 'conductor';
    } else if (json['desdeappconductor'] != null) {
      esDelConductor = json['desdeappconductor'] == true || json['desdeappconductor'] == 1;
    } else if (json['Desdeappconductor'] != null) {
      esDelConductor = json['Desdeappconductor'] == true || json['Desdeappconductor'] == 1;
    } else if (json['esDelConductor'] != null) {
      esDelConductor = json['esDelConductor'] == true;
    }
    return MensajeChatModel(
      id: json['id'] ?? json['Id'] ?? 0,
      idServicio: json['idservicio'] ?? json['Idservicio'] ?? 0,
      idPasajero: json['idpasajero'] ?? json['Idpasajero'] ?? 0,
      mensaje: json['mensaje'] ?? json['Mensaje'] ?? '',
      esDelConductor: esDelConductor,
      fechaCreacion: json['fechacreacion'] ?? json['Fechacreacion'],
    );
  }
}
