class ServicioProgramadoModel {
  final int id;
  final int idPasajero;
  final int? idCompania;
  final String direccionOrigen;
  final String latOrigen;
  final String lngOrigen;
  final String direccionDestino;
  final String latDestino;
  final String lngDestino;
  final String? paradasJson;
  final String fechaProgramada;
  final int anticipacionMinutos;
  final String estado;
  final int? idServicioGenerado;
  final int? idConductorAsignado;
  final String? notas;
  final String? fechaCreacion;

  ServicioProgramadoModel({
    required this.id,
    required this.idPasajero,
    this.idCompania,
    required this.direccionOrigen,
    required this.latOrigen,
    required this.lngOrigen,
    required this.direccionDestino,
    required this.latDestino,
    required this.lngDestino,
    this.paradasJson,
    required this.fechaProgramada,
    this.anticipacionMinutos = 15,
    this.estado = 'Programado',
    this.idServicioGenerado,
    this.idConductorAsignado,
    this.notas,
    this.fechaCreacion,
  });

  bool get estaActivo => estado == 'Programado' || estado == 'EnCola' || estado == 'Asignado' || estado == 'EnCurso';
  bool get yaGeneroServicio => idServicioGenerado != null && idServicioGenerado! > 0;

  factory ServicioProgramadoModel.fromJson(Map<String, dynamic> json) {
    return ServicioProgramadoModel(
      id: _toInt(json['id']),
      idPasajero: _toInt(json['idpasajero']),
      idCompania: json['idcompania'] != null ? _toInt(json['idcompania']) : null,
      direccionOrigen: json['direccionorigen']?.toString() ?? '',
      latOrigen: json['latorigen']?.toString() ?? '',
      lngOrigen: json['lngorigen']?.toString() ?? '',
      direccionDestino: json['direcciondestination']?.toString() ?? '',
      latDestino: json['latdestination']?.toString() ?? '',
      lngDestino: json['lngdestination']?.toString() ?? '',
      paradasJson: json['paradas_json']?.toString(),
      fechaProgramada: json['fechaprogramada']?.toString() ?? '',
      anticipacionMinutos: _toInt(json['anticipacion_minutos'] ?? 15),
      estado: json['estado']?.toString() ?? 'Programado',
      idServicioGenerado: json['idserviciogenerado'] != null ? _toInt(json['idserviciogenerado']) : null,
      idConductorAsignado: json['idconductorasignado'] != null ? _toInt(json['idconductorasignado']) : null,
      notas: json['notas']?.toString(),
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