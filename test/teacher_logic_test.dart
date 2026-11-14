import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';
import 'package:proyecto_asistencia/models/enrollment.dart';
import 'package:proyecto_asistencia/models/justification.dart';
import 'package:proyecto_asistencia/models/roster_plan.dart';
import 'package:proyecto_asistencia/models/teacher_snapshot.dart';
import 'package:proyecto_asistencia/services/spreadsheet.dart';

final now = DateTime(2026, 11, 2, 18, 30);

String mail(int i) => 'e$i@udla.edu.co';

Enrollment student(
  int i, {
  EnrollmentStatus status = EnrollmentStatus.active,
  DateTime? statusAt,
  EnrollmentSource source = EnrollmentSource.import,
  bool teacherSeen = true,
}) => Enrollment(
  courseId: 'c1',
  email: mail(i),
  code: '1000$i',
  name: 'Estudiante $i',
  status: status,
  source: source,
  teacherUid: 't1',
  statusAt: statusAt ?? DateTime(2026, 1, 1),
  teacherSeen: teacherSeen,
);

AttendanceRecord rec(String session, int i, {int minute = 2}) =>
    AttendanceRecord(
      id: AttendanceRecord.docId(session, mail(i)),
      email: mail(i),
      courseId: 'c1',
      sessionId: session,
      registeredAt: DateTime(2026, 10, 26, 18, minute),
      teacherUid: 't1',
    );

CourseSession session(
  String id,
  DateTime start, {
  bool open = false,
  DateTime? endsAt,
}) => CourseSession(
  id: id,
  courseId: 'c1',
  isOpen: open,
  startsAt: start,
  endsAt: endsAt ?? (open ? null : start.add(const Duration(minutes: 15))),
  teacherUid: 't1',
);

final course = Course(
  id: 'c1',
  name: 'Programación',
  period: '2026-2',
  teacherUid: 't1',
  maxAbsences: 2,
);

final sessions = [
  session('s1', DateTime(2026, 10, 19, 18)),
  session('s2', DateTime(2026, 10, 26, 18)),
  // Abierta y dentro de la ventana: no cuenta como realizada.
  session(
    's3',
    DateTime(2026, 11, 2, 18, 25),
    open: true,
    endsAt: DateTime(2026, 11, 2, 18, 40),
  ),
];

TeacherSnapshot snapshot({List<Enrollment>? enrollments}) => TeacherSnapshot(
  clock: () => now,
  courses: [course],
  sessions: sessions,
  enrollments:
      enrollments ??
      [
        student(1),
        student(2),
        student(3),
        student(
          4,
          status: EnrollmentStatus.invited,
          source: EnrollmentSource.manual,
        ),
      ],
  attendance: [rec('s1', 1), rec('s1', 2), rec('s2', 1), rec('s3', 2)],
  justifications: [
    Justification(
      sessionId: 's2',
      courseId: 'c1',
      email: mail(2),
      status: AbsenceStatus.justified,
    ),
  ],
);

void main() {
  group('CourseSession', () {
    test('se cierra sola al terminar la ventana de registro', () {
      final s = session(
        's',
        DateTime(2026, 11, 2, 18),
        open: true,
        endsAt: DateTime(2026, 11, 2, 18, 15),
      );
      expect(s.isOpenAt(DateTime(2026, 11, 2, 18, 10)), isTrue);
      expect(s.isOpenAt(DateTime(2026, 11, 2, 18, 15)), isFalse);
      expect(s.isExpiredAt(DateTime(2026, 11, 2, 18, 20)), isTrue);
      expect(s.statusOpen, isTrue); // falta que el docente la finalice
    });

    test('sin endsAt sigue abierta hasta que se finalice', () {
      final s = session('s', DateTime(2026, 11, 2, 18), open: true);
      expect(s.isOpenAt(DateTime(2030)), isTrue);
    });
  });

  group('Course', () {
    test('ida y vuelta sin la lista (va en enrollments)', () {
      final map = course.toMap();
      expect(map.containsKey('roster'), isFalse);
      expect(map.containsKey('students'), isFalse);
      final back = Course.fromMap('c1', map);
      expect(back.maxAbsences, 2);
      expect(back.teacherUid, 't1');
      expect(back.registrationMinutes, Course.defaultRegistrationMinutes);
    });

    test('franja horaria con formato de Firestore', () {
      const s = ClassSchedule(weekday: 2, startMinutes: 425, endMinutes: 545);
      expect(s.toMap(), {'day': 2, 'start': '07:05', 'end': '09:05'});
      expect(ClassSchedule.tryParse(s.toMap())!.startMinutes, 425);
    });

    test('iniciales del estudiante', () {
      expect(
        const RosterEntry(
          code: '1',
          name: 'juan  pérez gómez',
          email: 'j@udla.edu.co',
        ).initials,
        'JP',
      );
      expect(student(1).copyWith(name: '').initials, '?');
    });
  });

  group('Enrollment', () {
    test('id por asignatura y correo en minúsculas', () {
      expect(Enrollment.docId('c1', 'Ana@UDLA.edu.co'), 'c1_ana@udla.edu.co');
    });

    test('a qué sesiones debía asistir según su estado', () {
      final s1 = sessions[0], s2 = sessions[1];
      final lateJoin = student(1, statusAt: DateTime(2026, 10, 22));
      expect(lateJoin.expectedAt(s1), isFalse); // aún no estaba
      expect(lateJoin.expectedAt(s2), isTrue);
      final withdrew = student(
        2,
        status: EnrollmentStatus.withdrawn,
        statusAt: DateTime(2026, 10, 22),
      );
      expect(withdrew.expectedAt(s1), isTrue); // antes de cancelar
      expect(withdrew.expectedAt(s2), isFalse);
      final invited = student(3, status: EnrollmentStatus.invited);
      expect(invited.expectedAt(s1), isFalse);
    });

    test('lee el documento de Firestore', () {
      final e = Enrollment.tryParse({
        'courseId': 'c1',
        'email': 'ANA@udla.edu.co',
        'code': '12345',
        'name': ' Ana ',
        'status': 'invited',
        'source': 'manual',
        'teacherSeen': false,
      })!;
      expect(e.email, 'ana@udla.edu.co');
      expect(e.name, 'Ana');
      expect(e.status, EnrollmentStatus.invited);
      expect(e.source, EnrollmentSource.manual);
      expect(e.teacherSeen, isFalse);
      expect(Enrollment.tryParse({'courseId': 'c1', 'status': 'x'}), isNull);
    });
  });

  group('TeacherSnapshot', () {
    test('planilla de sesión: matriculados, sin invitaciones', () {
      final data = snapshot();
      final r = data.reportFor(data.sessionById('s2')!);
      expect(r.total, 3); // la invitación pendiente no cuenta
      expect(r.present, 1);
      expect(r.absent, 2);
      expect(r.justified, 1);
      expect(r.percent, 33);
    });

    test('solo cuentan las sesiones realizadas', () {
      final data = snapshot();
      expect(data.heldSessions().map((s) => s.id), ['s2', 's1']);
      expect(data.activeSessionFor('c1')!.id, 's3');
      final report = data.reportForCourse(course);
      expect(report.heldSessions, hasLength(2));
      expect(report.present, 3); // s1: e1,e2 · s2: e1
      expect(report.possible, 6);
      expect(report.percent, 50);
      expect(report.enrolled, 3);
    });

    test('riesgo con el mismo criterio que el estudiante', () {
      final report = snapshot().reportForCourse(course);
      final byEmail = {for (final s in report.standings) s.student.email: s};
      expect(byEmail[mail(1)]!.absences, 0);
      expect(byEmail[mail(2)]!.absences, 1); // remaining 1 => riesgo
      expect(byEmail[mail(3)]!.absences, 2); // remaining 0 => riesgo
      expect(report.atRisk.map((s) => s.student.email), [mail(3), mail(2)]);
    });

    test('matriculado tarde y cancelación: solo cuentan sus sesiones', () {
      final data = snapshot(
        enrollments: [
          student(1),
          // Llegó después de s1.
          student(3, statusAt: DateTime(2026, 10, 22)),
          // Canceló después de s1.
          student(
            2,
            status: EnrollmentStatus.withdrawn,
            statusAt: DateTime(2026, 10, 22),
            teacherSeen: false,
          ),
        ],
      );
      final s1 = data.reportFor(data.sessionById('s1')!);
      expect(s1.rows.map((r) => r.student.email), [mail(1), mail(2)]);
      final s2 = data.reportFor(data.sessionById('s2')!);
      expect(s2.rows.map((r) => r.student.email), [mail(1), mail(3)]);
      final late = data
          .reportForCourse(course)
          .standings
          .firstWhere((s) => s.student.email == mail(3));
      expect(late.absences, 1); // solo s2
      // Aviso pendiente para el docente.
      expect(data.alerts.single.email, mail(2));
      expect(data.enrolledCount('c1'), 2);
    });

    test('asistencia de alguien que ya no está en la lista', () {
      final data = snapshot(enrollments: [student(1)]);
      final r = data.reportFor(data.sessionById('s1')!);
      final extra = r.rows.firstWhere((x) => x.student.email == mail(2));
      expect(extra.present, isTrue);
      expect(extra.enrolled, isFalse);
      expect(extra.student.name, 'Estudiante fuera de la lista');
    });

    test('sin faltas permitidas no hay riesgo', () {
      final data = TeacherSnapshot(
        clock: () => now,
        courses: [
          course.copyWith(),
          Course(id: 'c2', name: 'X', period: '1'),
        ],
        sessions: const [],
        attendance: const [],
      );
      final r = data.reportForCourse(data.courseById('c2')!);
      expect(r.atRisk, isEmpty);
      expect(r.percent, isNull);
    });

    test('resumen y asistencia mensual', () {
      final data = snapshot();
      final sum = data.summary('2026-2');
      expect(sum.courses, 1);
      expect(sum.students, 3);
      expect(sum.heldSessions, 2);
      expect(sum.percent, 50);
      final months = data.monthly(null);
      expect(months.single.month, 10);
      expect(months.single.percent, 50);
    });
  });

  group('RosterPlan', () {
    RosterEntry row(int i, {String? name}) => RosterEntry(
      code: '1000$i',
      name: name ?? 'Estudiante $i',
      email: mail(i),
    );

    test('importar reemplaza la lista oficial', () {
      final plan = RosterPlan.forImport(
        courseId: 'c1',
        current: [
          student(1), // sigue igual
          student(2), // cambia el nombre
          student(3), // no viene: sale
          student(
            4,
            status: EnrollmentStatus.invited,
            source: EnrollmentSource.manual,
          ), // viene en el archivo: queda activo
          student(
            5,
            status: EnrollmentStatus.active,
            source: EnrollmentSource.manual,
          ), // agregado a mano y no viene: también sale
          student(6, status: EnrollmentStatus.withdrawn), // canceló y viene
          student(7, status: EnrollmentStatus.removed), // vuelve
        ],
        imported: [
          row(1),
          row(2, name: 'Estudiante Dos'),
          row(4),
          row(6),
          row(7),
          row(8), // nuevo
          row(8), // repetido
        ],
      );
      expect(plan.countOf(RosterChangeKind.unchanged), 1);
      expect(plan.countOf(RosterChangeKind.updated), 1);
      expect(plan.countOf(RosterChangeKind.removed), 2);
      expect(plan.countOf(RosterChangeKind.reactivated), 2);
      expect(plan.countOf(RosterChangeKind.keptChoice), 1);
      expect(plan.countOf(RosterChangeKind.added), 1);
      expect(plan.leaving.map((e) => e.email), [mail(3), mail(5)]);
      expect(plan.keptChoice.single.email, mail(6));
      final byEmail = {for (final c in plan.changes) c.target.email: c};
      expect(byEmail[mail(3)]!.target.status, EnrollmentStatus.removed);
      expect(byEmail[mail(4)]!.target.status, EnrollmentStatus.active);
      expect(byEmail[mail(8)]!.isNew, isTrue);
      expect(byEmail.containsKey(mail(6)), isFalse); // se respeta
      expect(byEmail.containsKey(mail(1)), isFalse); // sin cambios
    });

    test('importar dos veces el mismo archivo no cambia nada', () {
      final file = [row(1), row(2)];
      final first = RosterPlan.forImport(
        courseId: 'c1',
        current: const [],
        imported: file,
      );
      final after = [for (final c in first.changes) c.target];
      final second = RosterPlan.forImport(
        courseId: 'c1',
        current: after,
        imported: file,
      );
      expect(second.hasChanges, isFalse);
      expect(second.countOf(RosterChangeKind.unchanged), 2);
    });

    test('invitar a mano', () {
      String? error;
      final dup = RosterPlan.invite(
        courseId: 'c1',
        current: [student(1)],
        entry: row(1),
        error: (m) => error = m,
      );
      expect(dup, isNull);
      expect(error, contains('ya está matriculado'));

      final again = RosterPlan.invite(
        courseId: 'c1',
        current: [student(2, status: EnrollmentStatus.declined)],
        entry: row(2),
      )!;
      expect(again.isNew, isFalse);
      expect(again.target.status, EnrollmentStatus.invited);
      expect(again.target.source, EnrollmentSource.manual);

      final fresh = RosterPlan.invite(
        courseId: 'c1',
        current: const [],
        entry: row(3),
      )!;
      expect(fresh.isNew, isTrue);
    });

    test('diferencias: solo lo que cambió', () {
      final before = [student(1), student(2)];
      final after = [
        student(1),
        student(2).copyWith(status: EnrollmentStatus.removed),
        student(3),
        // Nuevo que termina fuera de la lista: no se escribe.
        student(4, status: EnrollmentStatus.removed),
      ];
      final diff = RosterPlan.diff(before, after);
      expect(diff.map((c) => c.target.email), [mail(2), mail(3)]);
      expect(diff.first.statusChanged, isTrue);
      expect(diff.last.isNew, isTrue);
    });
  });

  group('Spreadsheet', () {
    test('xlsx generado se vuelve a leer igual', () {
      final bytes = Spreadsheet.buildXlsx('Lista', [
        ['Código', 'Nombre', 'Correo'],
        ['1019283741', 'Ana Pérez & Hijos', 'ana@udla.edu.co'],
        [12345, 'Luis <Gómez>', null],
      ]);
      final rows = Spreadsheet.readRows(bytes, 'lista.xlsx');
      expect(rows[0], ['Código', 'Nombre', 'Correo']);
      expect(rows[1], ['1019283741', 'Ana Pérez & Hijos', 'ana@udla.edu.co']);
      expect(rows[2], ['12345', 'Luis <Gómez>']);
    });

    test('csv con punto y coma y comillas', () {
      final rows = Spreadsheet.readRows(
        bytesOf('﻿codigo;nombre\n12345;"Pérez; Ana"\n\n'),
        'l.csv',
      );
      expect(rows, [
        ['codigo', 'nombre'],
        ['12345', 'Pérez; Ana'],
      ]);
    });

    test('formato no admitido', () {
      expect(
        () => Spreadsheet.readRows(bytesOf('x'), 'lista.pdf'),
        throwsFormatException,
      );
    });

    test('lista: encabezados en otro orden, errores y duplicados', () {
      final result = parseRoster([
        ['Nombre', 'Correo', 'Código'],
        ['Ana Pérez', 'ana@udla.edu.co', '12345'],
        ['Luis', 'luis@udla.edu.co', '12a45'],
        ['', '', ''],
        ['Sin correo udla', 'x@gmail.com', '67890'],
        ['Ana repetida', 'otra@udla.edu.co', '12345'],
        ['Marta', 'marta@udla.edu.co', '54321'],
        ['Sin correo', '', '99999'],
        ['Correo repetido', 'marta@udla.edu.co', '11111'],
      ]);
      expect(result.entries.map((e) => e.code), ['12345', '54321']);
      expect(result.entries.first.email, 'ana@udla.edu.co');
      expect(result.issues, hasLength(5));
      expect(result.issues.first, contains('Fila 3'));
      expect(result.issues, contains(contains('falta el correo')));
      expect(result.issues, contains(contains('correo repetido')));
    });

    test('lista con los encabezados de la UDLA', () {
      final result = parseRoster([
        [
          'PROGRAMA',
          'CODIGOESTUDIANTE',
          'FECHAMATRICULA',
          'MAIL_INST',
          'DOCUMENTO',
          'NOMBRECOMPLETO',
          'PENG_IDENTITARIO',
          'TELEFONO',
          'EPS',
        ],
        [
          'INGENIERIA DE SISTEMAS',
          '4245000001',
          '46000',
          'Ana.Perez@udla.edu.co',
          '1000000001',
          'Ana Pérez',
          '',
          '3200000000',
          'Otro',
        ],
      ]);
      expect(result.issues, isEmpty);
      final e = result.entries.single;
      expect(e.code, '4245000001');
      expect(e.name, 'Ana Pérez');
      expect(e.email, 'ana.perez@udla.edu.co');
      expect(e.program, 'INGENIERIA DE SISTEMAS');
    });

    test('lista sin encabezados: código, nombre, correo', () {
      final result = parseRoster([
        ['12345', 'Ana', 'ana@udla.edu.co'],
        ['67890', 'Luis', 'luis@udla.edu.co'],
      ]);
      expect(result.entries, hasLength(2));
      expect(result.issues, isEmpty);
    });
  });
}

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));
