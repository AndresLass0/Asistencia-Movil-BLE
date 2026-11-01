import 'package:firebase_auth/firebase_auth.dart';

import '../models/academic_snapshot.dart';
import '../models/course.dart';
import '../models/user_profile.dart';
import 'academic_service.dart';
import 'attendance_service.dart';
import 'user_profile_service.dart';

/// Operaciones que necesitan las vistas del estudiante.
///
/// La implementación normal ([FirebaseStudentBackend]) delega en los
/// servicios de Firebase. El modo demostración (solo depuración) usa
/// `DemoStudentBackend`, que trabaja en memoria y no toca Firebase.
abstract class StudentBackend {
  const StudentBackend();

  /// true en el modo demostración: los cambios no se guardan en el servidor.
  bool get isDemo => false;

  Stream<UserProfile?> watchProfile(String uid);
  Stream<AcademicSnapshot> watchAcademic(String uid);
  Future<AttendanceResult> registerAttendance(String uid, Course course);
  Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
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

  @override
  Stream<AcademicSnapshot> watchAcademic(String uid) =>
      AcademicService.watch(uid);

  @override
  Future<AttendanceResult> registerAttendance(String uid, Course course) =>
      AttendanceService.registerForCourse(uid: uid, course: course);

  @override
  Future<void> reportIncident({
    required String uid,
    required String courseId,
    required String message,
    String? sessionId,
  }) => AttendanceService.reportIncident(
    uid: uid,
    courseId: courseId,
    message: message,
    sessionId: sessionId,
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
