class UserModel {
  final int id;
  final int? idCompania;
  final String nombre;
  final String appaterno;
  final String apmaterno;
  final String correo;
  final String codigopaistel;
  final String telefono;
  final String account;
  final String? fotoperfil;
  final String? googlekeyso;
  final bool bloqueado;
  final bool conectado;
  final String? metodopagopreferido;
  final String? idiomapreferido;
  final String? fechanacimiento;
  final String? genero;
  final String? uuidsesion;
  final String? mensaje;
  final bool eslogueadocongoogle;

  UserModel({
    required this.id,
    this.idCompania,
    required this.nombre,
    required this.appaterno,
    required this.apmaterno,
    required this.correo,
    this.codigopaistel = '+52',
    required this.telefono,
    required this.account,
    this.fotoperfil,
    this.googlekeyso,
    this.bloqueado = false,
    this.conectado = false,
    this.metodopagopreferido,
    this.idiomapreferido,
    this.fechanacimiento,
    this.genero,
    this.uuidsesion,
    this.mensaje,
    this.eslogueadocongoogle = false,
  });

  String get nombreCompleto => '$nombre $appaterno $apmaterno'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['Id'] ?? 0,
      idCompania: json['idcompania'] ?? json['Idcompania'],
      nombre: json['nombre'] ?? json['Nombre'] ?? '',
      appaterno: json['appaterno'] ?? json['Appaterno'] ?? '',
      apmaterno: json['apmaterno'] ?? json['Apmaterno'] ?? '',
      correo: json['correo'] ?? json['Correo'] ?? '',
      codigopaistel: json['codigopaistel'] ?? json['Codigopaistel'] ?? '+52',
      telefono: json['telefono'] ?? json['Telefono'] ?? '',
      account: json['account'] ?? json['Account'] ?? '',
      fotoperfil: json['fotoperfil'] ?? json['Fotoperfil'],
      googlekeyso: json['googlekeyso'] ?? json['Googlekeyso'],
      bloqueado: json['bloqueado'] == true || json['Bloqueado'] == true,
      conectado: json['conectado'] == true || json['Conectado'] == true,
      metodopagopreferido: json['metodopago'] ?? json['Metodopago'],
      idiomapreferido: json['idioma'] ?? json['Idioma'],
      fechanacimiento: json['fechanacimiento'] ?? json['Fechanacimiento'],
      genero: json['genero'] ?? json['Genero'],
      uuidsesion: json['uuidsesion'] ?? json['Uuidsesion'],
      mensaje: json['mensaje'] ?? json['Mensaje'],
      eslogueadocongoogle: json['eslogueadocongoogle'] == true || json['Eslogueadocongoogle'] == true,
    );
  }
}
