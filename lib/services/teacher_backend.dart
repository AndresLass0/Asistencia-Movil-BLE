import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';
import '../models/incident.dart';
import '../models/justification.dart';
import '../models/teacher_snapshot.dart';
import '../models/user_profile.dart';
import 'user_profile_service.dart';

/// Si la cuenta puede operar como docente.
enum TeacherAccess {
  /// Correo verificado y autorizado en `teachers/{correo}`.
  authorized,

  /// Falta verificar el correo (requisito de las reglas).
  emailNotVerified,

  /// El correo no está en la lista de docentes autorizados.
  notAuthorized,
}

/// Resultado de vincular la lista oficial con cuentas de BioAsistencia.
class RosterLink {
  const RosterLink({required this.entries, required this.mismatches});

  final List<RosterEntry> entries;

  /// Códigos cuyo correo registrado no coincide con el de la lista (no se
  /// vinculan, para evitar matricular a otra persona).
  final List<String> mismatches;

  int get linked => entries.where((e) => e.isLinked).length;
}

/// Operaciones de las vistas del docente. La autorización real la hacen
/// las reglas de Firestore (`isTeacher()`), no la interfaz.
abstract class TeacherBackend {
  const TeacherBackend();

  Future<TeacherAccess> checkAccess();
  Future<void> sendVerificationEmail();

  Stream<UserProfile?> watchProfile(String uid);
  Stream<TeacherSnapshot> watch(String uid);

  /// Busca la cuenta de cada código (`codes/{code}`).
  Future<RosterLink> linkRoster(List<RosterEntry> roster);

  /// Crea la asignatura y devuelve su id.
  Future<String> createCourse(Course course);
  Future<void> updateCourse(Course course);
  Future<void> deleteCourse(String courseId);

  /// Abre una sesión con una ventana de registro de [minutes] minutos.
  Future<CourseSession> startSession(Course course, int minutes);
  Future<void> closeSession(String sessionId);

  /// Registra manualmente la asistencia de un estudiante (excepción).
  Future<void> markManualAttendance(CourseSession session, String studentUid);
  Future<void> setAbsenceStatus(
    CourseSession session,
    String studentUid,
    AbsenceStatus status,
  );

  Future<void> signOut();
}

/// Implementación con Firebase Auth y Cloud Firestore.
class FirebaseTeacherBackend extends TeacherBackend {
  const FirebaseTeacherBackend();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const _timeout = Duration(seconds: 15);

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  Future<TeacherAccess> checkAccess() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return TeacherAccess.notAuthorized;
    await user.reload().timeout(_timeout);
    final fresh = FirebaseAuth.instance.currentUser!;
    final email = (fresh.email ?? '').toLowerCase();
    final doc = await _db
        .collection('teachers')
        .doc(email)
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    if (!doc.exists || doc.data()?['active'] == false) {
      return TeacherAccess.notAuthorized;
    }
    if (!fresh.emailVerified) return TeacherAccess.emailNotVerified;
    // Refresca el token para que las reglas vean `email_verified`.
    await fresh.getIdToken(true);
    return TeacherAccess.authorized;
  }

  @override
  Future<void> sendVerificationEmail() =>
      FirebaseAuth.instance.currentUser!.sendEmailVerification();

  @override
  Stream<UserProfile?> watchProfile(String uid) =>
      UserProfileService.watch(uid);

  @override
  Stream<TeacherSnapshot> watch(String uid) {
    late StreamController<TeacherSnapshot> controller;
    final subs = <StreamSubscription>[];
    List<Course>? courses;
    List<CourseSession>? sessions;
    List<AttendanceRecord>? attendance;
    List<Justification>? justifications;
    List<Incident>? incidents;
    var fromCache = false;

    void emit() {
      if (courses == null ||
          sessions == null ||
          attendance == null ||
          justifications == null ||
          incidents == null) {
        return;
      }
      controller.add(
        TeacherSnapshot(
          courses: courses!,
          sessions: sessions!,
          attendance: attendance!,
          justifications: justifications!,
          incidents: incidents!,
          isFromCache: fromCache,
        ),
      );
    }

    Query<Map<String, dynamic>> mine(String collection) =>
        _db.collection(collection).where('teacherUid', isEqualTo: uid);

    controller = StreamController<TeacherSnapshot>(
      onListen: () {
        subs
          ..add(
            mine('courses')
                .snapshots(includeMetadataChanges: true)
                .listen((snap) {
                  fromCache = snap.metadata.isFromCache;
                  courses = [
                    for (final d in snap.docs) Course.fromMap(d.id, d.data()),
                  ];
                  emit();
                }, onError: controller.addError),
          )
          ..add(
            mine('sessions').snapshots().listen((snap) {
              sessions = [
                for (final d in snap.docs)
                  CourseSession.fromMap(d.id, d.data()),
              ];
              emit();
            }, onError: controller.addError),
          )
          ..add(
            mine('attendance').snapshots().listen((snap) {
              attendance = [
                for (final d in snap.docs)
                  AttendanceRecord.fromMap(d.id, d.data()),
              ];
              emit();
            }, onError: controller.addError),
          )
          ..add(
            mine('justifications').snapshots().listen((snap) {
              justifications = [
                for (final d in snap.docs) Justification.tryParse(d.data()),
              ].whereType<Justification>().toList();
              emit();
            }, onError: controller.addError),
          )
          ..add(
            mine('incidents').snapshots().listen((snap) {
              incidents = [
                for (final d in snap.docs) Incident.fromMap(d.id, d.data()),
              ];
              emit();
            }, onError: controller.addError),
          );
      },
      onCancel: () async {
        for (final s in subs) {
          await s.cancel();
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<RosterLink> linkRoster(List<RosterEntry> roster) async {
    final mismatches = <String>[];
    final linked = await Future.wait([
      for (final e in roster)
        _db.collection('codes').doc(e.code).get().timeout(_timeout).then((d) {
          final data = d.data();
          if (data == null) return e.withUid(null);
          final email = (data['email'] as String? ?? '').toLowerCase();
          if (e.email.isNotEmpty && email != e.email.toLowerCase()) {
            mismatches.add(e.code);
            return e.withUid(null);
          }
          return RosterEntry(
            code: e.code,
            name: e.name,
            email: e.email.isEmpty ? email : e.email,
            uid: data['uid'] as String?,
          );
        }),
    ]);
    return RosterLink(entries: linked, mismatches: mismatches);
  }

  Map<String, Object?> _courseData(Course course) {
    final students = {
      for (final r in course.roster)
        if (r.isLinked) r.uid!,
    }.toList();
    return course.copyWith(students: students).toMap()..['teacherUid'] = _uid;
  }

  @override
  Future<String> createCourse(Course course) async {
    final ref = _db.collection('courses').doc();
    await ref
        .set({
          ..._courseData(course),
          'createdAt': FieldValue.serverTimestamp(),
        })
        .timeout(_timeout);
    return ref.id;
  }

  @override
  Future<void> updateCourse(Course course) => _db
      .collection('courses')
      .doc(course.id)
      .update(_courseData(course))
      .timeout(_timeout);

  @override
  Future<void> deleteCourse(String courseId) =>
      _db.collection('courses').doc(courseId).delete().timeout(_timeout);

  @override
  Future<CourseSession> startSession(Course course, int minutes) async {
    final ref = _db.collection('sessions').doc();
    final endsAt = DateTime.now().add(Duration(minutes: minutes));
    await ref
        .set({
          'courseId': course.id,
          'teacherUid': _uid,
          'status': 'open',
          'startsAt': FieldValue.serverTimestamp(),
          'endsAt': Timestamp.fromDate(endsAt),
        })
        .timeout(_timeout);
    final saved = await ref
        .get(const GetOptions(source: Source.server))
        .timeout(_timeout);
    return CourseSession.fromMap(saved.id, saved.data()!);
  }

  @override
  Future<void> closeSession(String sessionId) => _db
      .collection('sessions')
      .doc(sessionId)
      .update({'status': 'closed', 'closedAt': FieldValue.serverTimestamp()})
      .timeout(_timeout);

  @override
  Future<void> markManualAttendance(CourseSession session, String studentUid) =>
      _db
          .collection('attendance')
          .doc(AttendanceRecord.docId(session.id, studentUid))
          .set({
            'studentUid': studentUid,
            'courseId': session.courseId,
            'sessionId': session.id,
            'teacherUid': _uid,
            'method': AttendanceMethod.manual.id,
            'registeredAt': FieldValue.serverTimestamp(),
          })
          .timeout(_timeout);

  @override
  Future<void> setAbsenceStatus(
    CourseSession session,
    String studentUid,
    AbsenceStatus status,
  ) => _db
      .collection('justifications')
      .doc(Justification.docId(session.id, studentUid))
      .set({
        'sessionId': session.id,
        'courseId': session.courseId,
        'studentUid': studentUid,
        'teacherUid': _uid,
        'status': status.id,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      .timeout(_timeout);

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
