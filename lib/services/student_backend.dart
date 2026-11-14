import 'package:firebase_auth/firebase_auth.dart';

import '../models/academic_snapshot.dart';
import '../models/course.dart';
import '../models/enrollment.dart';
import '../models/user_profile.dart';
import 'academic_service.dart';
import 'attendance_service.dart';
import 'user_profile_service.dart';

/// Operaciones que necesitan las vistas del estudiante.
///
/// La implementación normal ([FirebaseStudentBackend]) delega en los
/// servicios de Firebase. Las pruebas automáticas usan
/// `FakeStudentBackend` (en `test/fakes/`), que trabaja en memoria.
abstract class StudentBackend {
  const StudentBackend();

  Stream<UserProfile?> watchProfile(String uid);

  /// Datos académicos del estudiante con ese correo institucional.
  Stream<AcademicSnapshot> watchAcademic(String email);
  Future<AttendanceResult> registerAttendance(String uid, Course course);

  /// Aceptar o rechazar una invitación, o cancelar la asignatura.
  Future<void> setEnrollmentStatus(
    Enrollment enrollment,
    EnrollmentStatus status,
  );
  Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
    String teacherUid = '',
  });
  Future<void> updateAcademicInfo(
    String uid, {
    required String program,
    required int? semester,
    required String campus,
  });
  Future<void> updateSettings(String uid, UserSettings settings);
  Future<void> updateBleEnabled(String uid, bool enabled);
  Future<void> signOut();
}

/// Backend real: Firebase Auth y Cloud Firestore.
class FirebaseStudentBackend extends StudentBackend {
  const FirebaseStudentBackend();

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      UserProfileService.watch(uid);

  /// Correo de la sesión actual: es el que comprueban las reglas.
  static String get _email =>
      (FirebaseAuth.instance.currentUser?.email ?? '').toLowerCase();

  @override
  Stream<AcademicSnapshot> watchAcademic(String email) =>
      AcademicService.watch(email);

  @override
  Future<AttendanceResult> registerAttendance(String uid, Course course) =>
      AttendanceService.registerForCourse(
        uid: uid,
        email: _email,
        course: course,
      );

  @override
  Future<void> setEnrollmentStatus(
    Enrollment enrollment,
    EnrollmentStatus status,
  ) => AcademicService.setMyStatus(enrollment, status);

  @override
  Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
    String teacherUid = '',
  }) => AttendanceService.reportIncident(
    uid: uid,
    email: _email,
    courseId: courseId,
    message: message,
    sessionId: sessionId,
    teacherUid: teacherUid,
  );

  @override
  Future<void> updateAcademicInfo(
    String uid, {
    required String program,
    required int? semester,
    required String campus,
  }) => UserProfileService.updateAcademicInfo(
    uid,
    program: program,
    semester: semester,
    campus: campus,
  );

  @override
  Future<void> updateSettings(String uid, UserSettings settings) =>
      UserProfileService.updateSettings(uid, settings);

  @override
  Future<void> updateBleEnabled(String uid, bool enabled) =>
      UserProfileService.updateBleEnabled(uid, enabled);

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
