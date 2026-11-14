import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_asistencia/screens/forgot_password_screen.dart';
import 'package:proyecto_asistencia/screens/login_screen.dart';
import 'package:proyecto_asistencia/screens/register_screen.dart';

import 'helpers.dart';
import 'test_fonts.dart';

/// Pantallas de autenticación (sin Firebase: solo validaciones previas).
void main() {
  setUpAll(loadRealFonts);

  group('Login', () {
    testWidgets('sin referencias a otra institución y logo real', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      expect(find.text('BioAsistencia'), findsOneWidget);
      expect(find.text('BioAsistencia UN'), findsNothing);
      expect(find.text('img'), findsNothing);
      expect(find.text('Universidad de la Amazonia'), findsOneWidget);
    });

    testWidgets('rechaza correos que no son @udla.edu.co', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'ana@gmail.com');
      await tester.enterText(find.byType(TextField).at(1), 'secreto123');
      await tapText(tester, 'Iniciar sesión');
      expect(
        find.text('Ingresa tu correo @udla.edu.co o tu código institucional.'),
        findsOneWidget,
      );
    });

    testWidgets('pide contraseña cuando el código es válido', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.enterText(find.byType(TextField).at(0), '1020304050');
      await tapText(tester, 'Iniciar sesión');
      expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
    });

    testWidgets('no hay accesos de demostración', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      expect(find.textContaining('Demostración'), findsNothing);
      expect(find.textContaining('DEMO'), findsNothing);
    });
  });

  group('Registro', () {
    testWidgets('la etiqueta del código cambia con el rol', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      expect(find.text('Código de estudiante'), findsOneWidget);
      await tapText(tester, 'Docente');
      expect(find.text('Código o documento docente'), findsOneWidget);
      expect(find.text('Oficial SIA'), findsNothing);
    });

    testWidgets('valida campos antes de llamar a Firebase', (tester) async {
      // Vista alta: el formulario completo cabe sin desplazarse.
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tapText(tester, 'Crear cuenta institucional');
      expect(find.text('Ingresa tu nombre completo.'), findsOneWidget);

      await clearSnackBars(tester);
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ana Pérez');
      await tester.enterText(fields.at(1), 'ana@gmail.com');
      await tapText(tester, 'Crear cuenta institucional');
      expect(
        find.text('Usa tu correo institucional @udla.edu.co.'),
        findsOneWidget,
      );

      await clearSnackBars(tester);
      await tester.enterText(fields.at(1), 'ana@udla.edu.co');
      await tester.enterText(fields.at(2), '12');
      await tapText(tester, 'Crear cuenta institucional');
      expect(
        find.text('El código de estudiante debe tener entre 5 y 15 dígitos.'),
        findsOneWidget,
      );
    });
  });

  testWidgets('Recuperar: título en español y doble factor "Próximamente"', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ForgotPasswordScreen()));
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Password Recovery'), findsNothing);
    expect(find.text('Próximamente'), findsOneWidget);
    final disabled = tester.widget<TextField>(find.byType(TextField).at(1));
    expect(disabled.enabled, isFalse);
  });

  expectNoOverflow('Login', () => const LoginScreen());
  expectNoOverflow('Registro', () => const RegisterScreen());
  expectNoOverflow('Recuperar', () => const ForgotPasswordScreen());
}
