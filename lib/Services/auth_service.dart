import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Obtener datos del usuario actual
  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('usuarios').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  // Convierte los bytes a texto Base64 para guardarlo en Firestore
  Future<String> uploadProfileImage(Uint8List imageBytes) async {
    String base64Image = base64Encode(imageBytes);
    return 'data:image/jpeg;base64,$base64Image';
  }

  // Actualizar o crear perfil de usuario de forma segura con merge: true
  Future<void> updateProfile({required String nombre, String? fotoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> data = {
      'id_usuario': user.uid,
      'nombre': nombre,
      'correo': user.email ?? '',
    };
    
    if (fotoUrl != null) {
      data['foto_url'] = fotoUrl;
    }

    await _db
        .collection('usuarios')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  // Marcar perfil como configurado de forma segura
  Future<void> marcarPerfilComoConfigurado() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('usuarios')
        .doc(user.uid)
        .set({'perfil_configurado': true}, SetOptions(merge: true));
  }
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registrar usuario con envío de correo de verificación
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String nombre,
  }) async {
    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    User? user = result.user;

    if (user != null) {
      await user.sendEmailVerification();

      await _db.collection('usuarios').doc(user.uid).set({
        'id_usuario': user.uid,
        'nombre': nombre,
        'correo': email,
        'rol': 'estudiante',
        'fecha_registro': DateTime.now().toIso8601String(),
        'foto_url': null,
        'perfil_configurado': false,
      }, SetOptions(merge: true));
    }

    return result;
  }

  Future<UserModel?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _db.collection('usuarios').doc(user.uid).get();
    if (doc.exists && doc.data() != null) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  Future<String> uploadProfileImage(Uint8List imageBytes) async {
    String base64Image = base64Encode(imageBytes);
    return 'data:image/jpeg;base64,$base64Image';
  }

  Future<void> updateProfile({required String nombre, String? fotoUrl}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    Map<String, dynamic> data = {
      'id_usuario': user.uid,
      'nombre': nombre,
      'correo': user.email ?? '',
    };
    
    if (fotoUrl != null) {
      data['foto_url'] = fotoUrl;
    }

    await _db
        .collection('usuarios')
        .doc(user.uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> marcarPerfilComoConfigurado() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _db
        .collection('usuarios')
        .doc(user.uid)
        .set({'perfil_configurado': true}, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}