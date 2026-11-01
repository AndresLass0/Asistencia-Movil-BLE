import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';

/// Acceso a los perfiles académicos en Cloud Firestore.
///
/// Estructura (ver `firestore.rules` en la raíz del proyecto):
/// - `users/{uid}`: perfil del usuario ([UserProfile]).
/// - `codes/{codigo}`: `{email, uid}`. Índice para iniciar sesión con el
///   código y garantizar que cada código se registre una sola vez.
class UserProfileService {
  UserProfileService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  static CollectionReference<Map<String, dynamic>> get _codes =>
      _db.collection('codes');

  /// Correo asociado a un código, o null si el código no está registrado.
  static Future<String?> emailForCode(String code) async {
    final doc = await _codes.doc(code.trim()).get();
    return doc.data()?['email'] as String?;
  }

  /// true si el código ya pertenece a otra cuenta.
  static Future<bool> isCodeTaken(String code) async =>
      (await _codes.doc(code.trim()).get()).exists;

  /// Guarda el perfil y reserva el código en una sola operación atómica.
  /// Falla (permission-denied) si el código ya estaba reservado.
  static Future<void> createProfile(String uid, UserProfile profile) {
    final batch = _db.batch()
      ..set(_users.doc(uid), {
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_codes.doc(profile.code), {'email': profile.email, 'uid': uid});
    return batch.commit();
  }

  /// Actualiza los datos académicos que completa el propio usuario.
  /// [semester] null borra el valor.
  static Future<void> updateAcademicInfo(
    String uid, {
    required String program,
    required int? semester,
    required String campus,
  }) => _users.doc(uid).update({
    'program': program.trim(),
    'semester': semester ?? FieldValue.delete(),
    'campus': campus.trim(),
  });

  static Future<void> updateSettings(String uid, UserSettings settings) =>
      _users.doc(uid).update({'settings': settings.toMap()});

  static Future<void> updateBleEnabled(String uid, bool enabled) =>
      _users.doc(uid).update({'bleEnabled': enabled});

  /// Perfil del usuario en tiempo real (null si no existe el documento,
  /// p. ej. cuentas creadas antes de guardar perfiles).
  static Stream<UserProfile?> watch(String uid) => _users
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? UserProfile.fromMap(s.data()!) : null);
}
