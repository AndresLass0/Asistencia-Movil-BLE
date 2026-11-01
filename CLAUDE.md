# CLAUDE.md — BioAsistencia (UDLA)

App Flutter de registro de asistencia a clase por proximidad (BLE) para la **Universidad de la Amazonia (UDLA)**, Florencia, Colombia. Responde en español.

Documentación detallada en `docs/` (arquitectura, pantallas, auditoría con estado por hallazgo, plan y estado). Consúltala antes de cambios grandes y **actualízala cuando cambie el comportamiento**.

## Qué es real y qué es simulado

- **Real:** Firebase Auth y Cloud Firestore: `users`, `codes`, `courses`, `sessions`, `attendance` e `incidents`. Esquema en `docs/MODELO_DE_DATOS.md`.
- La asistencia se valida con la **sesión abierta por el docente** (`sessions.status == 'open'`), comprobada en el servidor y en las reglas. **BLE no está implementado**: no lo presentes como activo.
- La app no crea asignaturas ni sesiones: se cargan desde la consola o una futura vista docente. Sin datos, las pantallas muestran estados vacíos; nunca rellenes con datos inventados.
- No presentes nada como "oficial", "sincronizado con el sistema académico", firmado o biométrico.

## Arquitectura

Organización por tipo, sin gestor de estado externo (`setState` + `StreamBuilder`).

- `lib/main.dart`: inicia Firebase dentro de `try/catch`; si falla muestra `StartupErrorApp`.
- `lib/core/`: `app_colors`, `app_theme`, `app_routes`, `validators`, `auth_messages`, `ui_messages`, `date_format`.
- `lib/models/`: `Course`/`ClassSchedule`, `CourseSession`, `AttendanceRecord`, `UserProfile`, y `AcademicSnapshot` (todos los cálculos: porcentajes, clases de hoy, siguiente clase, pendientes; es lógica pura y probada).
- `lib/services/`: `UserProfileService` (perfil y códigos), `AcademicService` (flujo combinado de asignaturas, sesiones y asistencias), `AttendanceService` (registro e incidencias) y `ReportService` (PDF con `pdf` y `printing`; usa la fuente `assets/fonts/Roboto`).
- `StudentBackend` (`services/student_backend.dart`) agrupa lo que usan las vistas del estudiante. `FirebaseStudentBackend` (por defecto) delega en los servicios; `DemoStudentBackend` (`demo_backend.dart`) es solo para el modo demostración. Pasa el `backend` recibido de `HomeScreen` a las pantallas que empujes; no llames a los servicios de Firebase directamente desde las vistas.
- `HomeScreen` mantiene las suscripciones y pasa un `AcademicState` (carga, datos o error) a las pestañas. No abras suscripciones nuevas en las pestañas.
- `firestore.rules`: reglas de Firestore. **No se despliegan desde aquí**: el equipo las publica en la consola.

## Navegación (no romper)

- `AuthGate` (`userChanges()`) es el **único** que alterna Login ↔ Home. No uses `pushNamedAndRemoveUntil` para entrar o salir de la sesión: tras crear la cuenta o cerrar sesión basta con `popUntil(route.isFirst)`.
- Las rutas con nombre son solo `/register` y `/forgot-password`. Login y Home **no** son rutas.
- `HomeScreen` usa 5 pestañas por índice: 0 Inicio, 1 Mis Clases, 2 Asistencia (botón central, `AppBottomNav.attendanceIndex`), 3 Historial (progreso) y 4 Perfil. No usa `IndexedStack`.
- La asignatura objetivo de Asistencia se fija al entrar en la pestaña (`_resolveAttendance`). Así las actualizaciones de datos no reinician la búsqueda; no la vuelvas reactiva.
- Las pantallas de resultado de asistencia devuelven un `AttendanceAction` con `Navigator.pop` (`history` → pestaña 3).
- El detalle de asignatura (`CourseDetailScreen`) se abre con `push` y escucha el `ValueNotifier<AcademicState>` de HomeScreen.

## Reglas de negocio confirmadas

- Se inicia sesión con correo `@udla.edu.co` **o** con el código (5–15 dígitos). Usa `classifyLoginIdentifier`.
- El registro exige correo `@udla.edu.co` y un código único. Estudiante: código estudiantil; docente: código o documento.
- El campo de doble factor de Recuperar contraseña se conserva deshabilitado ("Próximamente").
- Los accesos demo del Login solo se muestran en modo debug (`kDebugMode`). "Entrar como Estudiante" activa `DemoMode`: `AuthGate` muestra `HomeScreen` con `DemoStudentBackend` (datos de ejemplo en memoria, sin Firebase, con aviso visible; "Cerrar sesión" vuelve al Login). "Entrar como Docente" solo avisa: no hay vista docente.
- La regla del 80 % de asistencia **no** está confirmada: no la muestres.
- El margen de faltas y la alerta de riesgo solo existen si la asignatura define `maxAbsences`. No hay una regla global.
- Programa, semestre y sede los registra el propio usuario (campos opcionales). Si faltan, se muestra "Sin registrar"; nunca un valor inventado.
- Cualquier otra regla (vista docente, BLE real, facultades, reglamento, quién abre y cierra sesiones) está **pendiente**: pregunta antes de implementarla. Ver `docs/ESTADO_DEL_PROYECTO.md`.

## Reglas permanentes

1. **Identidad institucional:** la institución es la Universidad de la Amazonia (sin tilde), abreviada UDLA, con dominio `udla.edu.co`. Nunca introduzcas referencias a UNAL, "Universidad Nacional", "UN", "SIA" ni a otras instituciones. No inventes datos institucionales (facultades, sedes, sistemas, reglamentos, logos). Si falta un dato, pregunta.
2. **Flujos funcionales:** no alteres los flujos de login, registro, recuperación, asistencia o cierre de sesión sin una justificación explícita. No elimines botones u opciones solo para igualar pantallas: primero verifica si la diferencia tiene una razón funcional.
3. **Componentes compartidos** (`lib/widgets/`: `AppTopBar`, `AppTextField`, `PrimaryButton`, `SecondaryButton`, `AppCard`, `StatusChip`, `StatusOrb`, `AppLink`, `AppBottomNav`, `HomeHeader`, `UserAvatar`, `BrandLogo`): antes de modificarlos, busca **todas** las pantallas que los usan (`grep -rn NombreWidget lib`) y comprueba que el cambio es correcto en cada una.
4. **Servicios externos:** no cambies credenciales, `firebase_options.dart`, `google-services.json`, el `applicationId`/bundle id ni la configuración de Firebase sin autorización. No actualices dependencias sin un motivo concreto.
5. **Honestidad:** no afirmes que algo se verificó si no lo ejecutaste. No hay emulador configurado y Firebase no soporta Linux de escritorio.

## Convenciones de UI y código

- Textos en español; mayúscula solo en la primera palabra de títulos y botones ("Crear cuenta institucional").
- Usa "docente" (no "profesor" en frases; el prefijo "Prof." sí vale) y "señal de la clase".
- Ubicación siempre con `ClassSession.location`.
- Colores desde `AppColors` (no añadas `Color(0x…)` sueltos), mensajes con `showAppMessage`, validaciones con `core/validators.dart`, enlaces con `AppLink`.
- Pantallas sin sesión: `AppTopBar(showAvatar: false)`.
- Íconos por concepto: registrar asistencia → `Icons.sensors`; historial → `Icons.calendar_month_outlined`.
- Las filas con texto variable deben llevar `Expanded`/`Flexible` (se prueba en 320 dp con texto al 130 %).
- Comprueba `mounted` / `context.mounted` tras cada `await` que use `context`.

## Validación (ejecutar tras cada grupo de cambios)

```bash
flutter analyze --no-pub   # debe dar "No issues found!"
flutter test --no-pub      # todas en verde
# Referencias institucionales: ambas búsquedas deben salir vacías
grep -rnE  "\bUN\b|\bSIA\b"                  lib web android/app/src/main ios/Runner pubspec.yaml
grep -rniE "\bunal\b|\bnacional\b|amazonía"  lib web android/app/src/main ios/Runner pubspec.yaml
```

- Las pruebas cargan Roboto real (`test/test_fonts.dart`) para medir desbordamientos.
- Las pantallas que tocan Firebase en `build` no se pueden montar en pruebas: pasa los datos por parámetro. Las pestañas reciben `AcademicState` y `now`, y `AttendanceTab` acepta `register`.
- Para las pruebas usa los datos de `test/fixtures.dart` (lunes 2 de noviembre de 2026, 18:30) y `useTallView`/`pumpFrames` de `test/helpers.dart`.
- No uses `pumpAndSettle` con la pestaña Asistencia (tiene animaciones infinitas).
- Para revisar el aspecto, renderiza capturas con `matchesGoldenFile` hacia un directorio temporal y borra el test después.

## Estado del repositorio

El proyecto **no está en git**. Antes de cambios amplios, sugiere `git init` o haz una copia de seguridad.
