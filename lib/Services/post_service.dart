import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';

class PostService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Obtener publicaciones en tiempo real
  Stream<List<PostModel>> getPostsStream() {
    return _db
        .collection('publicaciones')
        .orderBy('fecha_creacion', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PostModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Convertir imagen a Base64
  Future<String> processPostImage(Uint8List imageBytes) async {
    String base64Image = base64Encode(imageBytes);
    return 'data:image/jpeg;base64,$base64Image';
  }

  // Crear nueva publicación
  Future<void> createPost({
    required String userId,
    required String userName,
    String? userPhoto,
    required String contenido,
    String? imagenUrl,
  }) async {
    await _db.collection('publicaciones').add({
      'id_usuario': userId,
      'nombre_usuario': userName,
      'foto_usuario': userPhoto,
      'contenido': contenido,
      'imagen_url': imagenUrl,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'reacciones': {},
    });
  }

  // Editar publicación
  Future<void> updatePost(String postId, String nuevoContenido) async {
    await _db.collection('publicaciones').doc(postId).update({
      'contenido': nuevoContenido,
    });
  }

  // Eliminar publicación
  Future<void> deletePost(String postId) async {
    await _db.collection('publicaciones').doc(postId).delete();
  }

  // Reaccionar o cambiar reacción (Tarea #23 y #24)
  Future<void> toggleReaction(String postId, String userId, String reactionType) async {
    final postRef = _db.collection('publicaciones').doc(postId);
    final doc = await postRef.get();

    if (doc.exists) {
      Map<String, dynamic> reacciones = Map.from(doc.data()?['reacciones'] ?? {});

      if (reacciones[userId] == reactionType) {
        // Si vuelve a presionar la misma reacción, se remueve
        reacciones.remove(userId);
      } else {
        // Asigna o cambia a la nueva reacción
        reacciones[userId] = reactionType;
      }

      await postRef.update({'reacciones': reacciones});
    }
  }

  // --- SECCIÓN COMENTARIOS (Tareas #25, #26, #27, #32) ---

  // Obtener comentarios de una publicación en tiempo real
  Stream<List<CommentModel>> getCommentsStream(String postId) {
    return _db
        .collection('publicaciones')
        .doc(postId)
        .collection('comentarios')
        .orderBy('fecha_creacion', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommentModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  // Crear comentario o respuesta (Tarea #25 y #32)
  Future<void> addComment({
    required String postId,
    required String userId,
    required String userName,
    String? userPhoto,
    required String texto,
    String? parentId,
  }) async {
    await _db
        .collection('publicaciones')
        .doc(postId)
        .collection('comentarios')
        .add({
      'id_usuario': userId,
      'nombre_usuario': userName,
      'foto_usuario': userPhoto,
      'texto': texto,
      'fecha_creacion': FieldValue.serverTimestamp(),
      'parent_id': parentId,
      'reacciones': {},
    });
  }

  // Eliminar comentario propio (Tarea #27)
  Future<void> deleteComment(String postId, String commentId) async {
    await _db
        .collection('publicaciones')
        .doc(postId)
        .collection('comentarios')
        .doc(commentId)
        .delete();
  }

  // Reaccionar a un comentario (Tarea #26)
  Future<void> toggleCommentReaction(
    String postId,
    String commentId,
    String userId,
    String reactionType,
  ) async {
    final commentRef = _db
        .collection('publicaciones')
        .doc(postId)
        .collection('comentarios')
        .doc(commentId);

    final doc = await commentRef.get();
    if (doc.exists) {
      Map<String, dynamic> reacciones = Map.from(doc.data()?['reacciones'] ?? {});

      if (reacciones[userId] == reactionType) {
        reacciones.remove(userId);
      } else {
        reacciones[userId] = reactionType;
      }

      await commentRef.update({'reacciones': reacciones});
    }
  }
}