class PreferenciasViaje {
  bool configurado;
  bool musica;
  bool aireAcondicionado;
  bool ventanasAbajo;
  String alergias;
  String discapacidad;
  bool viajaConMascotas;
  bool discapacidadAuditiva;
  bool discapacidadVisual;
  String notas;

  PreferenciasViaje({
    this.configurado = false,
    this.musica = false,
    this.aireAcondicionado = true,
    this.ventanasAbajo = false,
    this.alergias = '',
    this.discapacidad = '',
    this.viajaConMascotas = false,
    this.discapacidadAuditiva = false,
    this.discapacidadVisual = false,
    this.notas = '',
  });

  factory PreferenciasViaje.fromJson(Map<String, dynamic> json) {
    bool b(dynamic v) => v == true || v == 1 || v?.toString() == '1' || v?.toString().toLowerCase() == 'true';
    return PreferenciasViaje(
      configurado: b(json['configurado']),
      musica: b(json['musica']),
      aireAcondicionado: json['aireacondicionado'] == null ? true : b(json['aireacondicionado']),
      ventanasAbajo: b(json['ventanasabajo']),
      alergias: json['alergias']?.toString() ?? '',
      discapacidad: json['discapacidad']?.toString() ?? '',
      viajaConMascotas: b(json['viajacomascotas']),
      discapacidadAuditiva: b(json['discapacidadauditiva']),
      discapacidadVisual: b(json['discapacidadvisual']),
      notas: json['notas']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap(int idPasajero) => {
        'idPasajero': idPasajero,
        'musica': musica,
        'aireacondicionado': aireAcondicionado,
        'ventanasabajo': ventanasAbajo,
        'alergias': alergias.trim(),
        'discapacidad': discapacidad.trim(),
        'viajacomascotas': viajaConMascotas,
        'discapacidadauditiva': discapacidadAuditiva,
        'discapacidadvisual': discapacidadVisual,
        'notas': notas.trim(),
      };

  List<String> get resumen {
    final items = <String>[
      musica ? 'Con musica' : 'Sin musica',
      aireAcondicionado ? 'Aire acondicionado encendido' : 'Aire acondicionado apagado',
      if (ventanasAbajo) 'Ventanas abajo',
      if (viajaConMascotas) 'Viaja con mascotas',
      if (discapacidadAuditiva) 'Discapacidad auditiva',
      if (discapacidadVisual) 'Discapacidad visual',
    ];
    if (alergias.trim().isNotEmpty) items.add('Alergias: ${alergias.trim()}');
    if (discapacidad.trim().isNotEmpty) items.add('Apoyo: ${discapacidad.trim()}');
    return items;
  }
}
