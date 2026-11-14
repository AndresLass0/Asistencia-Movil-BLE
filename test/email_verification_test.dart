import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/screens/email_verification_gate.dart';
import 'package:proyecto_asistencia/services/email_verification.dart';

import 'helpers.dart';
import 'test_fonts.dart';

class _FakeVerifier extends EmailVerifier {
  bool verifiedOnServer = false;
  int resent = 0;
  int signedOut = 0;

  @override
  Future<bool> refresh() async => verifiedOnServer;

  @override
  Future<void> resend() async => resent++;

  @override
  Future<void> signOut() async => signedOut++;
}

Widget _gate(_FakeVerifier v, {bool verified = false}) => EmailVerificationGate(
  email: 'ana@udla.edu.co',
  verified: verified,
  verifier: v,
  child: const Text('VISTA PRINCIPAL'),
);

void main() {
  setUpAll(loadRealFonts);

  group('Verificación del correo', () {
    testWidgets('con el correo verificado muestra la vista', (tester) async {
      await tester.pumpWidget(wrap(_gate(_FakeVerifier(), verified: true)));
      expect(find.text('VISTA PRINCIPAL'), findsOneWidget);
      expect(find.text('Verifica tu correo'), findsNothing);
    });

    testWidgets('sin verificar bloquea el acceso', (tester) async {
      await tester.pumpWidget(wrap(_gate(_FakeVerifier())));
      expect(find.text('Verifica tu correo'), findsOneWidget);
      expect(find.textContaining('ana@udla.edu.co'), findsOneWidget);
      expect(find.text('VISTA PRINCIPAL'), findsNothing);
    });

    testWidgets('"Ya lo verifiqué" sin verificar avisa y no entra', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(_gate(_FakeVerifier())));
      await tester.tap(find.text('Ya lo verifiqué'));
      await tester.pump();
      expect(find.textContaining('aún no aparece como verificado'), findsOne);
      expect(find.text('VISTA PRINCIPAL'), findsNothing);
    });

    testWidgets('"Ya lo verifiqué" tras verificar entra a la vista', (
      tester,
    ) async {
      final v = _FakeVerifier();
      await tester.pumpWidget(wrap(_gate(v)));
      v.verifiedOnServer = true;
      await tester.tap(find.text('Ya lo verifiqué'));
      await tester.pump();
      expect(find.text('VISTA PRINCIPAL'), findsOneWidget);
    });

    testWidgets('reenviar y cerrar sesión', (tester) async {
      final v = _FakeVerifier();
      await tester.pumpWidget(wrap(_gate(v)));
      await tester.tap(find.text('Reenviar correo'));
      await tester.pump();
      expect(v.resent, 1);
      expect(find.textContaining('nuevo correo de verificación'), findsOne);
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pump();
      expect(v.signedOut, 1);
    });

    testWidgets('sin desbordamientos (320 dp, 130 %)', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(_gate(_FakeVerifier()), textScale: 1.3));
      expect(tester.takeException(), isNull);
    });
  });
}
