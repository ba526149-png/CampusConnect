class CommentModel {
  final String id;
  final String userId;
  final String userName;
  final String? userPhoto;
  final String texto;
  final DateTime fechaCreacion;
  final String? parentId; // null para comentario principal, id_comentario para respuesta
  final Map<String, String> reacciones;

  CommentModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhoto,
    required this.texto,
    required this.fechaCreacion,
    this.parentId,
    required this.reacciones,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String id) {
    Map<String, String> parsedReacciones = {};
    if (map['reacciones'] != null) {
      (map['reacciones'] as Map<String, dynamic>).forEach((key, value) {
        parsedReacciones[key] = value.toString();
      });
    }

    return CommentModel(
      id: id,
      userId: map['id_usuario'] ?? '',
      userName: map['nombre_usuario'] ?? 'Usuario Anónimo',
      userPhoto: map['foto_usuario'],
      texto: map['texto'] ?? '',
      fechaCreacion: map['fecha_creacion'] != null
          ? (map['fecha_creacion'] as dynamic).toDate()
          : DateTime.now(),
      parentId: map['parent_id'],
      reacciones: parsedReacciones,
    );
  }
}