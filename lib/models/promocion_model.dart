class PromocionModel {
  final int id;
  final String? titulo;
  final String? descripcion;
  final String? imgBase64;
  final String? codigo;
  final String? url;
  final String? inicioVigencia;
  final String? finVigencia;
  final bool activo;

  PromocionModel({
    required this.id,
    this.titulo,
    this.descripcion,
    this.imgBase64,
    this.codigo,
    this.url,
    this.inicioVigencia,
    this.finVigencia,
    this.activo = true,
  });

  factory PromocionModel.fromJson(Map<String, dynamic> json) {
    return PromocionModel(
      id: json['id'] ?? json['Id'] ?? 0,
      titulo: json['titulopublicidad'] ?? json['Titulopublicidad'],
      descripcion: json['asuntocorreo'] ?? json['Asuntocorreo'],
      imgBase64: json['imgbase64'] ?? json['Imgbase64'],
      codigo: json['codigopromocional']?.toString() ?? json['Codigopromocional']?.toString(),
      url: json['urlpromocion']?.toString() ?? json['Urlpromocion']?.toString() ?? json['url']?.toString(),
      inicioVigencia: json['iniciovigenciapromocion'] ?? json['Iniciovigenciapromocion'],
      finVigencia: json['finvigenciapromocion'] ?? json['Finvigenciapromocion'],
      activo: json['activo'] != false,
    );
  }
}
