import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/attendance_record.dart';
import '../models/course.dart';
import '../models/course_session.dart';
import '../models/enrollment.dart';
import '../models/incident.dart';
import '../models/justification.dart';
import '../models/roster_plan.dart';
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

/// Operaciones de las vistas del docente. La autorización real la hacen
/// las reglas de Firestore (`isTeacher()`), no la interfaz.
abstract class TeacherBackend {
  const TeacherBackend();

  Future<TeacherAccess> checkAccess();
  Future<void> sendVerificationEmail();

  Stream<UserProfile?> watchProfile(String uid);
  Stream<TeacherSnapshot> watch(String uid);

  /// Crea la asignatura con su lista inicial ([roster]: matrículas nuevas,
  /// activas o invitadas) en una sola operación. Devuelve su id.
  Future<String> createCourse(
    Course course, {
    List<Enrollment> roster = const [],
  });
  Future<void> updateCourse(Course course);

  /// Aplica los cambios de la lista (importación, invitaciones, quitar).
  Future<void> applyRosterChanges(
    Course course,
    List<EnrollmentChange> changes,
  );

  /// Elimina la asignatura y sus matrículas (las asistencias se conservan).
  Future<void> deleteCourse(Course course, List<Enrollment> enrollments);

  /// El docente vio el aviso de rechazo o cancelación.
  Future<void> markAlertSeen(Enrollment enrollment);

  /// Abre una sesión con una ventana de registro de [minutes] minutos.
  Future<CourseSession> startSession(Course course, int minutes);
  Future<void> closeSession(String sessionId);

  /// Registra manualmente la asistencia de un estudiante (excepción).
  Future<void> markManualAttendance(CourseSession session, String email);
  Future<void> setAbsenceStatus(
    CourseSession session,
    String email,
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
    List<Enrollment>? enrollments;
    List<Justification>? justifications;
    List<Incident>? incidents;
    var fromCache = false;

    void emit() {
      if (courses == null ||
          sessions == null ||
          attendance == null ||
          enrollments == null ||
          justifications == null ||
          incidents == null) {
        return;
      }
      controller.add(
        TeacherSnapshot(
          courses: courses!,
          sessions: sessions!,
          attendance: attendance!,
          enrollments: enrollments!,
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
            mine('enrollments').snapshots().listen((snap) {
              enrollments = [
                for (final d in snap.docs) Enrollment.tryParse(d.data()),
              ].whereType<Enrollment>().toList();
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

  Map<String, Object?> _courseData(Course course) =>
      course.toMap()..['teacherUid'] = _uid;

  /// Escribe un cambio de la lista en [batch]. `statusAt` y `createdAt` los
  /// pone el servidor (lo exigen las reglas).
  void _write(WriteBatch batch, EnrollmentChange change) {
    final e = change.target;
    final ref = _db.collection('enrollments').doc(e.id);
    final data = <String, Object?>{
      'code': e.code,
      'name': e.name,
      'program': e.program,
      'source': e.source.id,
      'teacherSeen': true,
      if (change.statusChanged) ...{
        'status': e.status.id,
        'statusAt': FieldValue.serverTimestamp(),
      },
    };
    if (change.isNew) {
      batch.set(ref, {
        ...data,
        'courseId': e.courseId,
        'teacherUid': _uid,
        'email': e.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(ref, data);
    }
  }

  /// Firestore acepta hasta 500 escrituras por lote.
  static const _batchLimit = 450;

  Future<void> _commit(
    List<EnrollmentChange> changes, {
    void Function(WriteBatch first)? before,
  }) async {
    var i = 0;
    do {
      final batch = _db.batch();
      if (i == 0) before?.call(batch);
      for (final c in changes.skip(i).take(_batchLimit)) {
        _write(batch, c);
      }
      await batch.commit().timeout(_timeout);
      i += _batchLimit;
    } while (i < changes.length);
  }

  @override
  Future<String> createCourse(
    Course course, {
    List<Enrollment> roster = const [],
  }) async {
    final ref = _db.collection('courses').doc();
    final changes = RosterPlan.diff(const [], [
      for (final e in roster) e.withCourseId(ref.id),
    ]);
    // La asignatura va en el primer lote: las reglas de las matrículas la
    // consultan con getAfter().
    await _commit(
      changes,
      before: (batch) => batch.set(ref, {
        ..._courseData(course),
        'createdAt': FieldValue.serverTimestamp(),
      }),
    );
    return ref.id;
  }

  @override
  Future<void> updateCourse(Course course) => _db
      .collection('courses')
      .doc(course.id)
      .update(_courseData(course))
      .timeout(_timeout);

  @override
  Future<void> applyRosterChanges(
    Course course,
    List<EnrollmentChange> changes,
  ) async {
    if (changes.isEmpty) return;
    await _commit(changes);
  }

  @override
  Future<void> deleteCourse(Course course, List<Enrollment> enrollments) async {
    final refs = [
      for (final e in enrollments) _db.collection('enrollments').doc(e.id),
    ];
    for (var i = 0; i < refs.length; i += _batchLimit) {
      final batch = _db.batch();
      for (final r in refs.skip(i).take(_batchLimit)) {
        batch.delete(r);
      }
      await batch.commit().timeout(_timeout);
    }
    await _db.collection('courses').doc(course.id).delete().timeout(_timeout);
  }

  @override
  Future<void> markAlertSeen(Enrollment enrollment) => _db
      .collection('enrollments')
      .doc(enrollment.id)
      .update({'teacherSeen': true})
      .timeout(_timeout);

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
  Future<void> markManualAttendance(CourseSession session, String email) => _db
      .collection('attendance')
      .doc(AttendanceRecord.docId(session.id, email))
      .set({
        'email': email.toLowerCase(),
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
    String email,
    AbsenceStatus status,
  ) => _db
      .collection('justifications')
      .doc(Justification.docId(session.id, email))
      .set({
        'sessionId': session.id,
        'courseId': session.courseId,
        'email': email.toLowerCase(),
        'teacherUid': _uid,
        'status': status.id,
        'updatedAt': FieldValue.serverTimestamp(),
      })
      .timeout(_timeout);

  @override
  Future<void> signOut() => FirebaseAuth.instance.signOut();
}
