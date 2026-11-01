# BioAsistencia — Universidad de la Amazonia (UDLA)

Aplicación Flutter para registrar la asistencia a clase. Estado actual: autenticación, perfiles, asignaturas, sesiones y asistencias reales en Firebase; la asistencia se valida con la sesión abierta por el docente (la verificación por proximidad BLE aún no está implementada). Ver [`docs/ESTADO_DEL_PROYECTO.md`](docs/ESTADO_DEL_PROYECTO.md).

## Requisitos

- Flutter 3.47 / Dart 3.13 (o compatible con `sdk: ^3.13.2`).
- Proyecto Firebase `asistencia-movil-2026` (ya configurado en `lib/firebase_options.dart` y `android/app/google-services.json`).

## Configuración de Firebase (una sola vez, en la consola)

1. **Authentication** → habilitar el proveedor *Correo electrónico/contraseña*.
2. **Firestore Database** → crear la base de datos.
3. **Firestore → Reglas** → pegar el contenido de [`firestore.rules`](firestore.rules) y publicar
   (o `firebase deploy --only firestore:rules` con la CLI de Firebase).

Sin los pasos 2 y 3, el registro falla con *permiso denegado* (la cuenta creada se revierte automáticamente) y el inicio de sesión con código no funciona; el inicio con correo sí.

4. Carga asignaturas y sesiones de prueba siguiendo [`docs/MODELO_DE_DATOS.md`](docs/MODELO_DE_DATOS.md). La app no las crea: sin datos, las pantallas del estudiante muestran estados vacíos.

## Ejecutar y validar

```bash
flutter pub get
flutter run            # Android, iOS o web (Linux/macOS no tienen configuración de Firebase)
flutter analyze
flutter test
```

## Documentación

- [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md): estructura, estado, navegación, servicios.
- [`docs/MODELO_DE_DATOS.md`](docs/MODELO_DE_DATOS.md): colecciones de Firestore, cálculos y datos de prueba.
- [`docs/PANTALLAS_Y_FLUJOS.md`](docs/PANTALLAS_Y_FLUJOS.md): inventario de pantallas y flujos.
- [`docs/AUDITORIA_DE_CONSISTENCIA.md`](docs/AUDITORIA_DE_CONSISTENCIA.md): hallazgos y su estado.
- [`docs/PLAN_DE_CORRECCIONES.md`](docs/PLAN_DE_CORRECCIONES.md): plan y avance.
- [`docs/ESTADO_DEL_PROYECTO.md`](docs/ESTADO_DEL_PROYECTO.md): resumen ejecutivo.
