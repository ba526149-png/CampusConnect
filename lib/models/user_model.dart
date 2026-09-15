class UserModel {
  final String idUsuario;
  final String nombre;
  final String correo;
  final String rol;
  final String fechaRegistro;
  final String? fotoUrl;

  UserModel({
    required this.idUsuario,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.fechaRegistro,
    this.fotoUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id_usuario': idUsuario,
      'nombre': nombre,
      'correo': correo,
      'rol': rol,
      'fecha_registro': fechaRegistro,
      'foto_url': fotoUrl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      idUsuario: id,
      nombre: map['nombre'] ?? '',
      correo: map['correo'] ?? '',
      rol: map['rol'] ?? 'estudiante',
      fechaRegistro: map['fecha_registro'] ?? '',
      fotoUrl: map['foto_url'],
    );
  }
}