import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../core/constants.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Registro de usuario con correo institucional
  Future<UserCredential?> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!AppConstants.isValidInstitutionalEmail(email)) {
      throw Exception('Solo se permiten correos institucionales (@uaeh.edu.mx)');
    }

    UserCredential result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    // Guardar información extendida del usuario en Firestore
    if (result.user != null) {
      UserModel newUser = UserModel(
        idUsuario: result.user!.uid,
        nombre: name.trim(),
        correo: email.trim(),
        rol: 'estudiante',
        fechaRegistro: DateTime.now().toIso8601String(),
      );

      await _db.collection('usuarios').doc(result.user!.uid).set(newUser.toMap());
    }

    return result;
  }

  // Inicio de sesión
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Cierre de sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}