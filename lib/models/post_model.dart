class PostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String contenido;
  final String? imagenUrl;
  final DateTime fechaCreacion;
  final Map<String, String> reacciones; // Key: userId, Value: tipoReaccion

  PostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.contenido,
    this.imagenUrl,
    required this.fechaCreacion,
    required this.reacciones,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, String> parsedReacciones = {};
    if (map['reacciones'] != null) {
      (map['reacciones'] as Map<String, dynamic>).forEach((key, value) {
        parsedReacciones[key] = value.toString();
      });
    }

    return PostModel(
      id: id,
      userId: map['id_usuario'] ?? '',
      userName: map['nombre_usuario'] ?? 'Usuario Anónimo',
      userPhoto: map['foto_usuario'],
      contenido: map['contenido'] ?? '',
      imagenUrl: map['imagen_url'],
      fechaCreacion: map['fecha_creacion'] != null
          ? (map['fecha_creacion'] as dynamic).toDate()
          : DateTime.now(),
      reacciones: parsedReacciones,
    );
  }
}