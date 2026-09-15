class SoporteSolicitudModel {
  final int id;
  final int? idServicio;
  final int? idPasajero;
  final int? idConductor;
  final String tipoSolicitante;
  final String? asunto;
  final String? descripcionInicial;
  final String estatus;
  final String prioridad;
  final int? idUsuarioSoporte;
  final String? soporteNombre;
  final String? pasajeroNombre;
  final String? pasajeroTel;
  final String? conductorNombre;
  final String? conductorTel;
  final String? servicioEstatus;
  final int totalMensajes;
  final int noLeidos;
  final String? fechaCreacion;
  final String? fechaCierre;

  SoporteSolicitudModel({
    required this.id,
    this.idServicio,
    this.idPasajero,
    this.idConductor,
    required this.tipoSolicitante,
    this.asunto,
    this.descripcionInicial,
    this.estatus = 'Abierto',
    this.prioridad = 'Normal',
    this.idUsuarioSoporte,
    this.soporteNombre,
    this.pasajeroNombre,
    this.pasajeroTel,
    this.conductorNombre,
    this.conductorTel,
    this.servicioEstatus,
    this.totalMensajes = 0,
    this.noLeidos = 0,
    this.fechaCreacion,
    this.fechaCierre,
  });

  bool get abierta => estatus == 'Abierto' || estatus == 'EnAtencion';

  factory SoporteSolicitudModel.fromJson(Map<String, dynamic> json) {
    return SoporteSolicitudModel(
      id: _toInt(json['id']),
      idServicio: json['idservicio'] != null ? _toInt(json['idservicio']) : null,
      idPasajero: json['idpasajero'] != null ? _toInt(json['idpasajero']) : null,
      idConductor: json['idconductor'] != null ? _toInt(json['idconductor']) : null,
      tipoSolicitante: json['tipo_solicitante']?.toString() ?? 'pasajero',
      asunto: json['asunto']?.toString(),
      descripcionInicial: json['descripcion_inicial']?.toString(),
      estatus: json['estatus']?.toString() ?? 'Abierto',
      prioridad: json['prioridad']?.toString() ?? 'Normal',
      idUsuarioSoporte: json['idusuariosoporte'] != null ? _toInt(json['idusuariosoporte']) : null,
      soporteNombre: json['soporte_nombre']?.toString(),
      pasajeroNombre: json['pasajero_nombre']?.toString(),
      pasajeroTel: json['pasajero_tel']?.toString(),
      conductorNombre: json['conductor_nombre']?.toString(),
      conductorTel: json['conductor_tel']?.toString(),
      servicioEstatus: json['servicio_estatus']?.toString(),
      totalMensajes: _toInt(json['totalmensajes']),
      noLeidos: _toInt(json['noleidos']),
      fechaCreacion: json['fechacreacion']?.toString(),
      fechaCierre: json['fecha_cierre']?.toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}

class SoporteMensajeModel {
  final int id;
  final int idSolicitud;
  final String emisor; // 'pasajero', 'conductor', 'soporte'
  final int? idEmisor;
  final String? nombreEmisor;
  final String mensaje;
  final String? adjuntoBase64;
  final bool leido;
  final String? fechaCreacion;

  SoporteMensajeModel({
    required this.id,
    required this.idSolicitud,
    required this.emisor,
    this.idEmisor,
    this.nombreEmisor,
    required this.mensaje,
    this.adjuntoBase64,
    this.leido = false,
    this.fechaCreacion,
  });

  bool get esDeSoporte => emisor == 'soporte';

  factory SoporteMensajeModel.fromJson(Map<String, dynamic> json) {
    return SoporteMensajeModel(
      id: _toInt(json['id']),
      idSolicitud: _toInt(json['idsolicitud']),
      emisor: json['emisor']?.toString() ?? '',
      idEmisor: json['idemisor'] != null ? _toInt(json['idemisor']) : null,
      nombreEmisor: json['nombre_emisor']?.toString(),
      mensaje: json['mensaje']?.toString() ?? '',
      adjuntoBase64: json['adjunto_base64']?.toString(),
      leido: json['leido'] == true || json['leido'] == 1,
      fechaCreacion: json['fechacreacion']?.toString(),
    );
  }

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}