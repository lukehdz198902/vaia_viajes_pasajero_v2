import 'conductor_model.dart';

class RideModel {
  final int id;
  final int? idConductor;
  final int idPasajero;
  final int? idServicioEstatus;
  final String? estatus;
  final String? estatusDescripcion;
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
  final String? tipoPago;
  final String? motivocancelacion;
  final String? canceladopor;
  final String? fechacancelacion;
  final String? fechaServicioIniciado;
  final String? fechaLlegoOrigen;
  final String? fechaLlegoDestino;
  final String? fechaCreacion;
  final bool servicioIniciado;
  final bool llegoOrigen;
  final bool llegoDestino;
  final int? calificacion;
  final int? calificacionPasajero;
  final ConductorModel? conductor;
  final String? unidad;
  final String? placas;
  final String? modelo;
  final String? colorNombre;
  final String? colorHex;
  final int? numeroAsientos;
  final String? marca;
  final String? submarca;
  final int? totalRegistros;
  final String? codigoInicio;
  final Map<String, dynamic> raw;

  RideModel({
    required this.id,
    this.idConductor,
    required this.idPasajero,
    this.idServicioEstatus,
    this.estatus,
    this.estatusDescripcion,
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
    this.tipoPago,
    this.motivocancelacion,
    this.canceladopor,
    this.fechacancelacion,
    this.fechaServicioIniciado,
    this.fechaLlegoOrigen,
    this.fechaLlegoDestino,
    this.fechaCreacion,
    this.servicioIniciado = false,
    this.llegoOrigen = false,
    this.llegoDestino = false,
    this.calificacion,
    this.calificacionPasajero,
    this.conductor,
    this.unidad,
    this.placas,
    this.modelo,
    this.colorNombre,
    this.colorHex,
    this.numeroAsientos,
    this.marca,
    this.submarca,
    this.totalRegistros,
    this.codigoInicio,
    this.raw = const {},
  });

  String get conductorNombre => conductor?.nombreCompleto ?? '--';
  String get costoFormateado => '\$${costoEstimado.toStringAsFixed(2)}';
  String get distanciaFormateada => '${(distanciaMetros / 1000).toStringAsFixed(1)} km';

  /// Estatus normalizado (sin espacios extra) para comparaciones.
  String get estatusNorm => (estatus ?? '').trim().toLowerCase();

  bool get cancelado => estatusNorm.contains('cancel');
  bool get esSolicitado => estatusNorm == 'solicitado';
  bool get esEnCamino => estatusNorm == 'en camino';
  bool get esLlegoOrigen => estatusNorm == 'llego al origen';
  bool get esEnViaje => estatusNorm == 'en viaje' || estatusNorm == 'casi llegando' || estatusNorm == 'llego al destino';
  bool get esFinalizado => estatusNorm == 'finalizado' || estatusNorm == 'pagado';
  bool get esActivo => !cancelado && !esFinalizado;

  /// Paso del proceso (0..4) para la linea de tiempo animada.
  int get pasoActual {
    if (cancelado) return -1;
    if (esSolicitado) return 0;
    if (esEnCamino) return 1;
    if (esLlegoOrigen) return 2;
    if (esEnViaje) return 3;
    if (esFinalizado) return 4;
    return 0;
  }

  /// Monto vigente a mostrar: final > en curso > estimado.
  double get montoActual => (costoFinal ?? 0) > 0
      ? costoFinal!
      : (costoEnCurso ?? 0) > 0
          ? costoEnCurso!
          : costoEstimado;

  factory RideModel.fromJson(Map<String, dynamic> json) {
    ConductorModel? cond;
    if (json['conductor'] != null) {
      cond = ConductorModel.fromJson(Map<String, dynamic>.from(json['conductor'] as Map));
    } else if (json['c_nombre'] != null || json['conductor_nombre'] != null) {
      // El snapshot y los SP devuelven columnas "conductor_*"; los eventos "c_*".
      cond = ConductorModel(
        id: _toInt(json['idconductor']),
        nombre: (json['conductor_nombre'] ?? json['c_nombre'] ?? '').toString(),
        appaterno: (json['conductor_appaterno'] ?? json['c_appaterno'] ?? '').toString(),
        apmaterno: (json['conductor_apmaterno'] ?? json['c_apmaterno'] ?? '').toString(),
        telefono: (json['conductor_telefono'] ?? json['c_tel'])?.toString(),
        correo: (json['conductor_email'] ?? json['c_email'])?.toString(),
        fotoperfil: (json['conductor_foto'] ?? json['c_foto'] ?? json['fotoperfil'])?.toString(),
        unidad: (json['unidad'])?.toString(),
        placas: (json['placas'])?.toString(),
        colorUnidad: (json['colorhex'] ?? json['colornombre'] ?? json['colorunidad'])?.toString(),
        marca: (json['nombremarca'])?.toString(),
        submarca: (json['nombresubmarca'])?.toString(),
        modelo: (json['modelo'])?.toString(),
        numeroAsientos: _toIntOrNull(json['numeroasientos']),
        calificacion: _toDoubleOrNull(json['conductor_calificacion'] ??
            json['c_calificacionpromedio'] ?? json['calificacionpromedio']),
        totalViajes: _toIntOrNull(json['conductor_totalviajes'] ?? json['c_totalviajes'] ?? json['totalviajes']),
        lat: (json['conductor_lat'])?.toString(),
        lng: (json['conductor_lng'])?.toString(),
      );
    }

    return RideModel(
      id: _toInt(json['id'] ?? json['Id'] ?? json['idservicio'] ?? json['Idservicio']),
      idConductor: _toIntOrNull(json['idconductor'] ?? json['Idconductor']),
      idPasajero: _toInt(json['idpasajero'] ?? json['Idpasajero']),
      idServicioEstatus: _toIntOrNull(json['idservicioestatus'] ?? json['Idservicioestatus']),
      estatus: (json['estatus'] ?? json['Estatus'])?.toString(),
      estatusDescripcion: (json['estatusdescription'] ?? json['Estatusdescription'])?.toString(),
      codigoInicio: (json['codigoinicio'] ?? json['Codigoinicio'])?.toString(),
      direccionOrigen: (json['direccionorigen'] ?? json['Direccionorigen'] ?? '').toString(),
      latOrigen: (json['latorigen'] ?? json['Latorigen'] ?? '').toString(),
      lngOrigen: (json['lngorigen'] ?? json['Lngorigen'] ?? '').toString(),
      direccionDestino: (json['direcciondestination'] ?? json['Direcciondestination'] ?? '').toString(),
      latDestino: (json['latdestination'] ?? json['Latdestination'] ?? '').toString(),
      lngDestino: (json['lngdestination'] ?? json['Lngdestination'] ?? '').toString(),
      costoEstimado: _toDouble(json['costoestimado'] ?? json['Costoestimado']),
      costoEnCurso: _toDoubleOrNull(json['costoencurso'] ?? json['Costoencurso']),
      costoFinal: _toDoubleOrNull(json['costofinal'] ?? json['Costofinal']),
      gananciaConductor: _toDoubleOrNull(json['gananciaconductor'] ?? json['Gananciaconductor']),
      comisionAplicada: _toDoubleOrNull(json['comisionaplicada'] ?? json['Comisionaplicada']),
      distanciaMetros: _toInt(json['distanciametros'] ?? json['Distanciametros']),
      duracionSegundos: _toIntOrNull(json['durationsegundos'] ?? json['Durationsegundos'] ?? json['duracionsegundos']),
      montoDescuento: _toDoubleOrNull(json['montodescuento'] ?? json['Montodescuento']),
      tipoviaje: (json['tipoviaje'] ?? json['Tipoviaje'])?.toString(),
      tipoPago: (json['tipopago'] ?? json['Tipopago'])?.toString(),
      motivocancelacion: (json['motivocancelacion'] ?? json['Motivocancelacion'])?.toString(),
      canceladopor: (json['canceladopor'] ?? json['Canceladopor'])?.toString(),
      fechacancelacion: (json['fechacancelacion'] ?? json['Fechacancelacion'])?.toString(),
      fechaServicioIniciado: (json['fechaservicioiniciado'] ?? json['Fechaservicioiniciado'])?.toString(),
      fechaLlegoOrigen: (json['fechallegoalorigen'] ?? json['Fechallegoalorigen'])?.toString(),
      fechaLlegoDestino: (json['fechallegoasudestino'] ?? json['Fechallegoasudestino'])?.toString(),
      fechaCreacion: (json['fechacreacion'] ?? json['Fechacreacion'])?.toString(),
      servicioIniciado: json['servicioiniciado'] == true || json['Servicioiniciado'] == true,
      llegoOrigen: json['llegoalorigen'] == true || json['Llegoalorigen'] == true,
      llegoDestino: json['llegoasudestino'] == true || json['Llegoasudestino'] == true,
      calificacion: _toIntOrNull(json['calificacion'] ?? json['Calificacion']),
      calificacionPasajero: _toIntOrNull(json['calificacionpasajero'] ?? json['Calificacionpasajero']),
      conductor: cond,
      unidad: (json['unidad'] ?? json['Unidad'])?.toString(),
      placas: (json['placas'] ?? json['Placas'])?.toString(),
      modelo: (json['modelo'])?.toString(),
      colorNombre: (json['colornombre'])?.toString(),
      colorHex: (json['colorhex'])?.toString(),
      numeroAsientos: _toIntOrNull(json['numeroasientos']),
      marca: (json['nombremarca'])?.toString(),
      submarca: (json['nombresubmarca'])?.toString(),
      totalRegistros: _toIntOrNull(json['totalregistros'] ?? json['Totalregistros']),
      raw: Map<String, dynamic>.from(json),
    );
  }

  /// Devuelve una copia con los campos indicados sobreescritos.
  RideModel copyWith(Map<String, dynamic> cambios) => RideModel.fromJson({...raw, ...cambios});

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);

  static int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double _toDouble(dynamic v) => _toDoubleOrNull(v) ?? 0;

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }
}
