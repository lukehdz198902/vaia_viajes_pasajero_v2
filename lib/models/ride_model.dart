import 'conductor_model.dart';

class RideModel {
  final int id;
  final int? idConductor;
  final int idPasajero;
  final int? idServicioEstatus;
  final String? estatus;
  final String direccionOrigen;
  final String latOrigen;
  final String lngOrigen;
  final String direccionDestino;
  final String latDestino;
  final String lngDestino;
  final double costoEstimado;
  final double? gananciaConductor;
  final double? comisionAplicada;
  final int distanciaMetros;
  final int? duracionSegundos;
  final double? montoDescuento;
  final String? tipoviaje;
  final String? motivocancelacion;
  final String? canceladopor;
  final String? fechacancelacion;
  final String? fechaServicioIniciado;
  final String? fechaLlegoDestino;
  final String? fechaCreacion;
  final bool? servicioIniciado;
  final bool? llegoDestino;
  final int? calificacion;
  final int? calificacionPasajero;
  final ConductorModel? conductor;
  final String? unidad;
  final String? placas;
  final int? totalRegistros;

  RideModel({
    required this.id,
    this.idConductor,
    required this.idPasajero,
    this.idServicioEstatus,
    this.estatus,
    required this.direccionOrigen,
    required this.latOrigen,
    required this.lngOrigen,
    required this.direccionDestino,
    required this.latDestino,
    required this.lngDestino,
    required this.costoEstimado,
    this.gananciaConductor,
    this.comisionAplicada,
    required this.distanciaMetros,
    this.duracionSegundos,
    this.montoDescuento,
    this.tipoviaje,
    this.motivocancelacion,
    this.canceladopor,
    this.fechacancelacion,
    this.fechaServicioIniciado,
    this.fechaLlegoDestino,
    this.fechaCreacion,
    this.servicioIniciado,
    this.llegoDestino,
    this.calificacion,
    this.calificacionPasajero,
    this.conductor,
    this.unidad,
    this.placas,
    this.totalRegistros,
  });

  String get conductorNombre => conductor?.nombreCompleto ?? '--';
  String get costoFormateado => '\$${costoEstimado.toStringAsFixed(2)}';
  String get distanciaFormateada => '${(distanciaMetros / 1000).toStringAsFixed(1)} km';

  factory RideModel.fromJson(Map<String, dynamic> json) {
    ConductorModel? cond;
    if (json['conductor'] != null) {
      cond = ConductorModel.fromJson(json['conductor']);
    } else if (json['c_nombre'] != null) {
      cond = ConductorModel(
        id: json['idconductor'] ?? 0,
        nombre: json['c_nombre'] ?? '',
        appaterno: json['c_appaterno'] ?? '',
        apmaterno: json['c_apmaterno'] ?? '',
        telefono: json['c_tel'] ?? '',
        correo: json['c_email'] ?? '',
        unidad: json['unidad'] ?? '',
        placas: json['placas'] ?? '',
        calificacion: json['c_calificacionpromedio'],
      );
    }
    return RideModel(
      id: json['id'] ?? json['Id'] ?? json['idservicio'] ?? json['Idservicio'] ?? 0,
      idConductor: json['idconductor'] ?? json['Idconductor'],
      idPasajero: json['idpasajero'] ?? json['Idpasajero'] ?? 0,
      idServicioEstatus: json['idservicioestatus'] ?? json['Idservicioestatus'],
      estatus: json['estatus'] ?? json['Estatus'],
      direccionOrigen: json['direccionorigen'] ?? json['Direccionorigen'] ?? '',
      latOrigen: json['latorigen'] ?? json['Latorigen'] ?? '',
      lngOrigen: json['lngorigen'] ?? json['Lngorigen'] ?? '',
      direccionDestino: json['direcciondestination'] ?? json['Direcciondestination'] ?? '',
      latDestino: json['latdestination'] ?? json['Latdestination'] ?? '',
      lngDestino: json['lngdestination'] ?? json['Lngdestination'] ?? '',
      costoEstimado: _toDouble(json['costoestimado'] ?? json['Costoestimado'] ?? 0),
      gananciaConductor: _toDouble(json['gananciaconductor'] ?? json['Gananciaconductor']),
      comisionAplicada: _toDouble(json['comisionaplicada'] ?? json['Comisionaplicada']),
      distanciaMetros: json['distanciametros'] ?? json['Distanciametros'] ?? 0,
      duracionSegundos: json['durationsegundos'] ?? json['Durationsegundos'] ?? json['duracionsegundos'],
      montoDescuento: _toDouble(json['montodescuento'] ?? json['Montodescuento']),
      tipoviaje: json['tipoviaje'] ?? json['Tipoviaje'],
      motivocancelacion: json['motivocancelacion'] ?? json['Motivocancelacion'],
      canceladopor: json['canceladopor'] ?? json['Canceladopor'],
      fechacancelacion: json['fechacancelacion'] ?? json['Fechacancelacion'],
      fechaServicioIniciado: json['fechaservicioiniciado'] ?? json['Fechaservicioiniciado'],
      fechaLlegoDestino: json['fechallegoasudestino'] ?? json['Fechallegoasudestino'],
      fechaCreacion: json['fechacreacion'] ?? json['Fechacreacion'],
      servicioIniciado: json['servicioiniciado'] == true || json['Servicioiniciado'] == true,
      llegoDestino: json['llegoasudestino'] == true || json['Llegoasudestino'] == true,
      calificacion: json['calificacion'] ?? json['Calificacion'],
      calificacionPasajero: json['calificacionpasajero'] ?? json['Calificacionpasajero'],
      conductor: cond,
      unidad: json['unidad'] ?? json['Unidad'],
      placas: json['placas'] ?? json['Placas'],
      totalRegistros: json['totalregistros'] ?? json['Totalregistros'],
    );
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
