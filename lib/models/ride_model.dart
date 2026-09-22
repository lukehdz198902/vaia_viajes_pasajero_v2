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
  final double? costoEnCurso;
  final double? costoFinal;
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
  final String? codigoInicio;

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
    this.costoEnCurso,
    this.costoFinal,
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
    this.codigoInicio,
  });

  String get conductorNombre => conductor?.nombreCompleto ?? '--';
  String get costoFormateado => '\$${costoEstimado.toStringAsFixed(2)}';
  String get distanciaFormateada => '${(distanciaMetros / 1000).toStringAsFixed(1)} km';

  factory RideModel.fromJson(Map<String, dynamic> json) {
    ConductorModel? cond;
    if (json['conductor'] != null) {
      cond = ConductorModel.fromJson(json['conductor']);
    } else if (json['c_nombre'] != null || json['conductor_nombre'] != null) {
      // El SP devuelve columnas "conductor_*"; los eventos usan "c_*".
      cond = ConductorModel(
        id: json['idconductor'] ?? 0,
        nombre: json['conductor_nombre'] ?? json['c_nombre'] ?? '',
        appaterno: json['conductor_appaterno'] ?? json['c_appaterno'] ?? '',
        apmaterno: json['conductor_apmaterno'] ?? json['c_apmaterno'] ?? '',
        telefono: json['conductor_telefono'] ?? json['c_tel'] ?? '',
        correo: json['conductor_email'] ?? json['c_email'] ?? '',
        fotoperfil: json['conductor_foto'] ?? json['c_foto'] ?? json['fotoperfil'],
        unidad: json['unidad'] ?? '',
        placas: json['placas'] ?? '',
        colorUnidad: json['colornombre'] ?? json['colorunidad'],
        calificacion: _toDouble(json['conductor_calificacion'] ??
            json['c_calificacionpromedio'] ?? json['calificacionpromedio']),
        totalViajes: json['conductor_totalviajes'] ?? json['c_totalviajes'] ?? json['totalviajes'],
        lat: json['conductor_lat']?.toString(),
        lng: json['conductor_lng']?.toString(),
      );
    }
    return RideModel(
      id: json['id'] ?? json['Id'] ?? json['idservicio'] ?? json['Idservicio'] ?? 0,
      idConductor: json['idconductor'] ?? json['Idconductor'],
      idPasajero: json['idpasajero'] ?? json['Idpasajero'] ?? 0,
      idServicioEstatus: json['idservicioestatus'] ?? json['Idservicioestatus'],
      estatus: json['estatus'] ?? json['Estatus'],
      codigoInicio: json['codigoinicio']?.toString() ?? json['Codigoinicio']?.toString(),
      direccionOrigen: json['direccionorigen'] ?? json['Direccionorigen'] ?? '',
      latOrigen: json['latorigen'] ?? json['Latorigen'] ?? '',
      lngOrigen: json['lngorigen'] ?? json['Lngorigen'] ?? '',
      direccionDestino: json['direcciondestination'] ?? json['Direcciondestination'] ?? '',
      latDestino: json['latdestination'] ?? json['Latdestination'] ?? '',
      lngDestino: json['lngdestination'] ?? json['Lngdestination'] ?? '',
      costoEstimado: _toDouble(json['costoestimado'] ?? json['Costoestimado'] ?? 0),
      costoEnCurso: _toDouble(json['costoencurso'] ?? json['Costoencurso']),
      costoFinal: _toDouble(json['costofinal'] ?? json['Costofinal']),
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'idconductor': idConductor,
      'idpasajero': idPasajero,
      'idservicioestatus': idServicioEstatus,
      'estatus': estatus,
      'direccionorigen': direccionOrigen,
      'latorigen': latOrigen,
      'lngorigen': lngOrigen,
      'direcciondestination': direccionDestino,
      'latdestination': latDestino,
      'lngdestination': lngDestino,
      'costoestimado': costoEstimado,
      'distanciametros': distanciaMetros,
      'durationsegundos': duracionSegundos,
      'tipoviaje': tipoviaje,
      'servicioiniciado': servicioIniciado,
      'unidad': unidad,
      'placas': placas,
      'c_nombre': conductor?.nombre,
      'c_appaterno': conductor?.appaterno,
      'c_tel': conductor?.telefono,
    };
  }

  static double _toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
