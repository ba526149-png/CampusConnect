import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final doc = await _db.collection('usuarios').doc(user.uid).get();
    if (!doc.exists) return null;
    return UserModel.fromMap(doc.data()!, doc.id);
  }

  // --- TAREA #28: Búsqueda de usuarios ---
  // --- TAREA #28: Búsqueda de usuarios ---
  Stream<List<UserModel>> searchUsers(String query) {
    if (query.trim().isEmpty) {
      return Stream.value([]);
    }
    
    return _db
        .collection('usuarios')
        .where('nombre', isGreaterThanOrEqualTo: query)
        .where('nombre', isLessThanOrEqualTo: '$query\uf8ff') // Corregido: \uf8ff en lugar de \zf8ff
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserModel.fromMap(doc.data(), doc.id))
            .where((u) => u.idUsuario != _auth.currentUser?.uid) // Corregido: u.id en lugar de u.uid
            .toList());
  }

  // --- TAREA #29: Seguimiento de usuarios ---
  Stream<bool> isFollowingStream(String targetUserId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value(false);

    return _db
        .collection('usuarios')
        .doc(currentUserId)
        .collection('siguiendo')
        .doc(targetUserId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> toggleFollowUser(String targetUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final followingRef = _db
        .collection('usuarios')
        .doc(currentUserId)
        .collection('siguiendo')
        .doc(targetUserId);

    final followersRef = _db
        .collection('usuarios')
        .doc(targetUserId)
        .collection('seguidores')
        .doc(currentUserId);

    final doc = await followingRef.get();

    if (doc.exists) {
      // Dejar de seguir
      await followingRef.delete();
      await followersRef.delete();
    } else {
      // Seguir
      await followingRef.set({'fecha': FieldValue.serverTimestamp()});
      await followersRef.set({'fecha': FieldValue.serverTimestamp()});
    }
  }
}