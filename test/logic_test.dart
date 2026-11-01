import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/core/auth_messages.dart';
import 'package:proyecto_asistencia/core/date_format.dart';
import 'package:proyecto_asistencia/core/validators.dart';
import 'package:proyecto_asistencia/models/attendance_record.dart';
import 'package:proyecto_asistencia/models/user_profile.dart';

void main() {
  group('validators', () {
    test('isInstitutionalEmail solo acepta @udla.edu.co', () {
      expect(isInstitutionalEmail('jcperez@udla.edu.co'), isTrue);
      expect(isInstitutionalEmail('  JCPerez@UDLA.edu.co '), isTrue);
      expect(isInstitutionalEmail('jcperez@gmail.com'), isFalse);
      expect(isInstitutionalEmail('jcperez@udla.edu.co.fake.com'), isFalse);
      expect(isInstitutionalEmail('@udla.edu.co'), isFalse);
    });

    test('isValidEmail valida formato general', () {
      expect(isValidEmail('a@b.co'), isTrue);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail('sin-arroba'), isFalse);
    });

    test('isValidCode: 5 a 15 dígitos', () {
      expect(isValidCode('12345'), isTrue);
      expect(isValidCode('123456789012345'), isTrue);
      expect(isValidCode('1234'), isFalse);
      expect(isValidCode('1234567890123456'), isFalse);
      expect(isValidCode('12a45'), isFalse);
    });

    test('classifyLoginIdentifier distingue correo, código e inválido', () {
      expect(
        classifyLoginIdentifier('ana@udla.edu.co'),
        LoginIdentifierType.email,
      );
      expect(classifyLoginIdentifier('1020304050'), LoginIdentifierType.code);
      expect(
        classifyLoginIdentifier('ana@gmail.com'),
        LoginIdentifierType.invalid,
      );
      expect(classifyLoginIdentifier('ana'), LoginIdentifierType.invalid);
      expect(classifyLoginIdentifier(''), LoginIdentifierType.invalid);
    });
  });

  group('modelos', () {
    test('AttendanceRecord.code y docId', () {
      final r = AttendanceRecord(
        id: AttendanceRecord.docId('s1', 'u1'),
        studentUid: 'u1',
        courseId: 'c1',
        sessionId: 's1',
        registeredAt: DateTime(2026, 11, 1, 18, 3, 42),
      );
      expect(r.code, 'AS-261101-180342');
      expect(r.id, 's1_u1');
    });

    test('UserProfile ida y vuelta por mapa', () {
      const p = UserProfile(
        name: 'Ana',
        email: 'ana@udla.edu.co',
        role: UserRole.teacher,
        code: '1020304050',
        faculty: 'Facultad de Ingeniería',
        bleEnabled: true,
      );
      final back = UserProfile.fromMap(p.toMap());
      expect(back.role, UserRole.teacher);
      expect(back.code, '1020304050');
      expect(p.toMap()['role'], 'teacher');
    });

    test('UserProfile lee campos opcionales y preferencias', () {
      final p = UserProfile.fromMap({
        'name': 'Ana',
        'role': 'student',
        'semester': 7,
        'program': 'Ingeniería de Sistemas',
        'settings': {'liveSessionAlerts': false},
      });
      expect(p.semester, 7);
      expect(p.program, 'Ingeniería de Sistemas');
      expect(p.settings.liveSessionAlerts, isFalse);
      expect(p.settings.riskAlerts, isTrue);
      expect(UserProfile.fromMap({}).semester, isNull);
    });

    test('UserRole.fromId usa estudiante por defecto', () {
      expect(UserRole.fromId('teacher'), UserRole.teacher);
      expect(UserRole.fromId('student'), UserRole.student);
      expect(UserRole.fromId(null), UserRole.student);
    });
  });

  group('mensajes de autenticación', () {
    test('credenciales inválidas usan mensaje genérico correo/código', () {
      for (final code in [
        'invalid-credential',
        'wrong-password',
        'user-not-found',
      ]) {
        expect(
          authErrorMessage(FirebaseAuthException(code: code)),
          kInvalidCredentialsMessage,
        );
      }
    });

    test('código desconocido se incluye en el mensaje', () {
      expect(
        authErrorMessage(FirebaseAuthException(code: 'raro')),
        contains('raro'),
      );
    });
  });

  group('date_format', () {
    final d = DateTime(2026, 10, 21, 18, 3, 42); // miércoles
    test('longDate', () {
      expect(longDate(d), 'Miércoles, 21 de octubre de 2026');
    });
    test('shortDate', () => expect(shortDate(d), '21 oct 2026'));
    test('time12h', () {
      expect(time12h(d), '6:03 PM');
      expect(time12h(d, seconds: true), '6:03:42 PM');
      expect(time12h(DateTime(2026, 1, 1, 0, 5)), '12:05 AM');
    });
  });
}
