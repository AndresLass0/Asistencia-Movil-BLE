import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/course.dart';
import 'package:proyecto_asistencia/models/course_session.dart';
import 'package:proyecto_asistencia/models/justification.dart';
import 'package:proyecto_asistencia/models/teacher_snapshot.dart';
import 'package:proyecto_asistencia/services/spreadsheet.dart';

final now = DateTime(2026, 11, 2, 18, 30);

RosterEntry student(int i, {bool linked = true}) => RosterEntry(
  code: '1000$i',
  name: 'Estudiante $i',
  uid: linked ? 'u$i' : null,
);

AttendanceRecord rec(String session, String uid, {int minute = 2}) =>
    AttendanceRecord(
      id: AttendanceRecord.docId(session, uid),
      studentUid: uid,
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
  endsAt: endsAt,
  teacherUid: 't1',
);

final course = Course(
  id: 'c1',
  name: 'Programación',
  period: '2026-2',
  teacherUid: 't1',
  maxAbsences: 2,
  roster: [student(1), student(2), student(3), student(4, linked: false)],
  students: const ['u1', 'u2', 'u3', 'u9'], // u9: añadido desde la consola
);

TeacherSnapshot snapshot() => TeacherSnapshot(
  clock: () => now,
  courses: [course],
  sessions: [
    session('s1', DateTime(2026, 10, 19, 18)),
    session('s2', DateTime(2026, 10, 26, 18)),
    // Abierta y dentro de la ventana: no cuenta como realizada.
    session(
      's3',
      DateTime(2026, 11, 2, 18, 25),
      open: true,
      endsAt: DateTime(2026, 11, 2, 18, 40),
    ),
  ],
  attendance: [
    rec('s1', 'u1'),
    rec('s1', 'u2'),
    rec('s2', 'u1'),
    rec('s3', 'u2'),
  ],
  justifications: const [
    Justification(
      sessionId: 's2',
      courseId: 'c1',
      studentUid: 'u2',
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
    test('ida y vuelta con lista, matriculados y reglas', () {
      final back = Course.fromMap('c1', course.toMap());
      expect(back.roster, hasLength(4));
      expect(back.roster.first.uid, 'u1');
      expect(back.roster.last.isLinked, isFalse);
      expect(back.students, ['u1', 'u2', 'u3', 'u9']);
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
        const RosterEntry(code: '1', name: 'juan  pérez gómez').initials,
        'JP',
      );
      expect(const RosterEntry(code: '1', name: '').initials, '?');
    });
  });

  group('TeacherSnapshot', () {
    test('planilla de sesión: lista, matriculados extra y ausentes', () {
      final data = snapshot();
      final r = data.reportFor(data.sessionById('s2')!);
      // 4 de la lista + u9 (matriculado sin datos en la lista)
      expect(r.total, 5);
      expect(r.present, 1);
      expect(r.absent, 4);
      expect(r.justified, 1);
      expect(r.percent, 20);
      final unlinked = r.absentRows.firstWhere((x) => !x.linked);
      expect(unlinked.student.name, 'Estudiante 4');
    });

    test('solo cuentan las sesiones realizadas', () {
      final data = snapshot();
      expect(data.heldSessions().map((s) => s.id), ['s2', 's1']);
      expect(data.activeSessionFor('c1')!.id, 's3');
      final report = data.reportForCourse(course);
      expect(report.heldSessions, hasLength(2));
      expect(report.present, 3); // s1: u1,u2 · s2: u1
      expect(report.possible, 10);
      expect(report.percent, 30);
    });

    test('riesgo con el mismo criterio que el estudiante', () {
      final report = snapshot().reportForCourse(course);
      final byUid = {for (final s in report.standings) s.student.uid: s};
      expect(byUid['u1']!.absences, 0);
      expect(byUid['u2']!.absences, 1); // remaining 1 => riesgo
      expect(byUid['u3']!.absences, 2); // remaining 0 => riesgo
      expect(report.atRisk.map((s) => s.student.uid), ['u3', 'u9', 'u2']);
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
      expect(sum.students, 4);
      expect(sum.heldSessions, 2);
      expect(sum.percent, 30);
      final months = data.monthly(null);
      expect(months.single.month, 10);
      expect(months.single.percent, 30);
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
        ['Luis', '', '12a45'],
        ['', '', ''],
        ['Sin correo udla', 'x@gmail.com', '67890'],
        ['Ana repetida', '', '12345'],
        ['Marta', '', '54321'],
      ]);
      expect(result.entries.map((e) => e.code), ['12345', '54321']);
      expect(result.entries.first.email, 'ana@udla.edu.co');
      expect(result.issues, hasLength(3));
      expect(result.issues.first, contains('Fila 3'));
    });

    test('lista sin encabezados: código, nombre, correo', () {
      final result = parseRoster([
        ['12345', 'Ana'],
        ['67890', 'Luis', 'luis@udla.edu.co'],
      ]);
      expect(result.entries, hasLength(2));
      expect(result.issues, isEmpty);
    });
  });
}

Uint8List bytesOf(String s) => Uint8List.fromList(utf8.encode(s));
