# Arquitectura — BioAsistencia (proyecto_asistencia)

> Actualizado el 2026-11-01, con las vistas del estudiante y del docente. Esquema de datos en [MODELO_DE_DATOS.md](MODELO_DE_DATOS.md).

## 1. Propósito

App Flutter de registro de asistencia a clase de la Universidad de la Amazonia (UDLA), con vista de **estudiante** y de **docente**.

- **Real:** Firebase Auth (correo `@udla.edu.co` o código) y Cloud Firestore (perfiles, asignaturas, sesiones, asistencias e incidencias).
- **Validación de la asistencia:** sesión abierta por el docente (servidor + reglas). **La proximidad BLE no está implementada.**
- **Docente:** crea asignaturas, carga la lista de estudiantes, abre sesiones con ventana de registro, ve presentes en vivo, finaliza, revisa inasistencias y exporta (PDF y Excel).
- **Fuera de la app:** autorizar docentes (`teachers/{correo}`, consola de Firebase).

## 2. Estructura

```
lib/
├── main.dart                     # Arranque (try/catch de Firebase) y StartupErrorApp
├── firebase_options.dart         # FlutterFire (no editar a mano)
├── core/                         # colores, tema, rutas, validadores, mensajes, fechas
├── models/
│   ├── course.dart               # Course, ClassSchedule, RosterEntry
│   ├── course_session.dart       # CourseSession (status + ventana endsAt)
│   ├── attendance_record.dart    # AttendanceRecord (id = sessionId_uid, method)
│   ├── justification.dart        # revisión de inasistencias del docente
│   ├── incident.dart             # incidencias reportadas por estudiantes
│   ├── academic_snapshot.dart    # cálculos del estudiante + todayClassesOf/nextClassOf
│   ├── teacher_snapshot.dart     # cálculos del docente + TeacherState
│   └── user_profile.dart         # UserProfile, UserRole, UserSettings
├── services/
│   ├── user_profile_service.dart # users / codes / teachers (autorización)
│   ├── academic_service.dart     # flujo del estudiante (courses + sessions + attendance)
│   ├── attendance_service.dart   # registro del estudiante e incidencias
│   ├── student_backend.dart      # StudentBackend + FirebaseStudentBackend
│   ├── teacher_backend.dart      # TeacherBackend + FirebaseTeacherBackend
│   ├── demo_backend.dart         # DemoMode + DemoStudentBackend (solo depuración)
│   ├── demo_teacher_backend.dart # DemoTeacherBackend (solo depuración)
│   ├── report_service.dart       # PDF (pdf + printing) y Excel de ambos roles
│   └── spreadsheet.dart          # leer/escribir .xlsx y .csv; parseRoster
├── screens/
│   ├── auth_gate.dart            # AuthGate + RoleGate
│   ├── login_screen.dart, register_screen.dart, forgot_password_screen.dart
│   ├── home_screen.dart, course_detail_screen.dart, tabs/, attendance/   # estudiante
│   └── teacher/                  # docente
│       ├── teacher_gate.dart, teacher_home_screen.dart, teacher_ui.dart
│       ├── course_form_screen.dart, active_session_screen.dart, session_summary_screen.dart
│       └── tabs/teacher_{classes,history,reports,profile}_tab.dart
└── widgets/                      # compartidos (§6)
assets/fonts/                     # Roboto (Apache 2.0), incrustada en los PDF
test/                             # logic, academic, screens, student_screens, demo_mode, teacher_logic, teacher_screens
firestore.rules                   # reglas (se publican desde la consola)
```

## 3. Arranque y sesión

`main.dart` → `Firebase.initializeApp` (con `StartupErrorApp` si falla) → `MaterialApp(home: AuthGate)`. `AuthGate` escucha `userChanges()` y es el **único** que alterna Login y la vista principal:
- con sesión → `RoleGate` lee `users/{uid}`: `role == 'teacher'` → `TeacherGate`; si no (o sin perfil) → `HomeScreen`;
- `TeacherGate` comprueba `teachers/{correo}` y el correo verificado antes de mostrar `TeacherHomeScreen`;
- sin sesión y con `DemoMode` activo (solo depuración) → la vista del rol con datos de ejemplo.

### Roles y permisos
El rol del perfil **solo decide la vista**. La autorización está en las reglas: `isTeacher()` = correo verificado + `teachers/{correo}` activo (lo administra la institución). El registro como docente se rechaza (y se revierte la cuenta) si el correo no está autorizado. Sin Cloud Functions ni claims personalizados (plan gratuito).

## 4. Flujo de datos

```
Firestore ──AcademicService.watch(uid)──▶ AcademicSnapshot ──▶ HomeScreen
          ──UserProfileService.watch(uid)─▶ UserProfile    ──┘   │ AcademicState + perfil
                                                                ▼
                       Dashboard · Clases · Asistencia · Historial · Perfil · Detalle
```

- `AcademicService.watch` combina tres consultas: `courses` (`students` arrayContains uid), `sessions` (`courseId` whereIn, en bloques de 30) y `attendance` (`studentUid` == uid). Emite un `AcademicSnapshot` cuando las tres tienen datos, y propaga los errores. Marca `isFromCache` para el indicador "En línea / Sin conexión".
- `AcademicSnapshot` es inmutable y sin UI: porcentajes, faltas, clases de hoy, siguiente clase, periodos, sesiones pendientes y asignatura sugerida. Está cubierto por `test/academic_test.dart`.
- `HomeScreen` se suscribe manualmente (no con `StreamBuilder`) para poder detectar sesiones nuevas y lanzar la alerta en vivo. Publica el estado en un `ValueNotifier<AcademicState>`, que también escucha el detalle de asignatura.

## 5. Registro de asistencia

`AttendanceService.registerForCourse`:
1. consulta en el **servidor** (no en caché) la sesión `open` más reciente de la asignatura;
2. si ya existe `attendance/{sessionId}_{uid}`, la devuelve marcada como `alreadyRegistered`;
3. si no, la crea con `registeredAt` del servidor y la vuelve a leer;
4. tiempo máximo de 15 s. Los errores se traducen a `AttendanceFailure`: `noOpenSession`, `offline`, `denied` o `unknown`.

`AttendanceTab` muestra la animación de búsqueda al menos 1,5 s (solo por experiencia de uso; no altera el resultado). Luego abre el comprobante o la pantalla de fallo.

## 5b. Vista del docente

`TeacherHomeScreen` mantiene las suscripciones de `TeacherBackend.watch(uid)`: cinco consultas `where('teacherUid', ==, uid)` (`courses`, `sessions`, `attendance`, `justifications`, `incidents`) combinadas en un `TeacherSnapshot` y publicadas en un `ValueNotifier<TeacherState>` que escuchan las pestañas, la sesión activa y el resumen.

Ciclo de una sesión:
1. **Iniciar:** `startSession(course, minutos)` crea `sessions` con `status: open`, `startsAt` del servidor y `endsAt = ahora + minutos`.
2. **Registro:** los estudiantes registran (`attendance`, `method: session`) mientras `status == open` y antes de `endsAt`. El docente puede añadir excepciones (`method: manual`). El id `{sessionId}_{uid}` evita duplicados.
3. **Cierre automático:** al pasar `endsAt` las reglas rechazan nuevos registros; la sesión cuenta como realizada.
4. **Finalizar:** `closeSession` → `status: closed`, `closedAt` del servidor (no se puede reabrir).
5. **Revisión:** `setAbsenceStatus` guarda `justifications` (justificada o confirmada).

`StudentBackend` y `TeacherBackend` aíslan Firebase de las pantallas: la implementación real delega en Firestore y la de demostración trabaja en memoria. Las pantallas reciben el backend por parámetro.

## 6. Componentes compartidos

| Widget | Uso |
|---|---|
| `AppBottomNav` | 5 pestañas; botón central = Asistencia (índice 2) |
| `HomeHeader` | Logo, subtítulo, chip de sede (solo si el usuario la registró), campana con sesiones pendientes, avatar |
| `AppTopBar` | Pantallas secundarias (`showAvatar: false` sin sesión) |
| `AppCard`, `PrimaryButton`, `SecondaryButton`, `StatusChip`, `StatusOrb`, `AppLink`, `AppTextField`, `BrandLogo`, `UserAvatar` | Base visual |
| `PercentRing` | Anillo de porcentaje (Inicio, Clases, Historial, Detalle) |
| `SectionHeader` | Títulos de sección con ícono (Perfil) |
| `LoadingView`, `MessageView`, `AcademicErrorView`, `NoCoursesView` | Estados de carga, error y vacío |
| `showIncidentDialog` | Reporte de incidencias (Fallo y Detalle) |
| `TeacherBottomNav` | Barra del docente: Clases · Historial · Reportes · Perfil |
| `DemoBanner` | Aviso del modo demostración (ambos roles) |
| `teacher/teacher_ui.dart` | `runTeacherAction`, `confirmAction`, `StatTile`, `StatRow`, `InitialsAvatar` |

## 7. Navegación

- Estudiante: 0 Inicio · 1 Mis Clases · 2 Asistencia · 3 Historial · 4 Perfil.
- Docente: 0 Clases · 1 Historial · 2 Reportes · 3 Perfil (`TeacherBottomNav`). Sesión activa, resumen y formulario de clase se abren con `push`; al finalizar, el resumen **reemplaza** a la sesión activa; "Consultar historial" vuelve con `pop(true)` y cambia a la pestaña 1.
- La asignatura de Asistencia se **fija al entrar** (explícita desde un botón, o sugerida: primero una sesión pendiente y si no, la clase en horario). Las actualizaciones posteriores no reinician la búsqueda.
- `push`: detalle de asignatura y pantallas de resultado. Las rutas con nombre siguen siendo solo `/register` y `/forgot-password`.

## 8. Dependencias

| Paquete | Versión | Motivo |
|---|---|---|
| `firebase_core` / `firebase_auth` / `cloud_firestore` | 4.15.2 / 6.7.0 / 6.10.2 | Backend |
| `google_fonts` | 6.3.3 | Plus Jakarta Sans |
| `pdf` | 3.13.1 | **Nuevo:** generar el historial en PDF (aparece en el diseño) |
| `printing` | 5.15.1 | Diálogo del sistema para guardar o compartir el PDF |
| `file_picker` | 13.3.1 | **Nuevo (docente):** abrir la lista de estudiantes (.xlsx/.csv) y guardar planillas Excel |
| `archive` / `xml` | 4.6.0 / 7.0.1 | Ya eran dependencias de `pdf`; ahora se declaran directas para leer y escribir .xlsx (el paquete `excel` es incompatible con `pdf`) |
| `cupertino_icons`, `flutter_lints` | — | Plantilla y análisis |

## 9. Identificadores

Nombre visible "BioAsistencia"; `applicationId`/bundle `com.example…` sin cambiar; firma de release con claves de debug (pendiente).
