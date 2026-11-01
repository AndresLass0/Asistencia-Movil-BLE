# Arquitectura — BioAsistencia (proyecto_asistencia)

> Actualizado el 2026-11-01, tras implementar las vistas del estudiante. Esquema de datos en [MODELO_DE_DATOS.md](MODELO_DE_DATOS.md).

## 1. Propósito

App Flutter de registro de asistencia a clase para estudiantes de la Universidad de la Amazonia (UDLA).

- **Real:** Firebase Auth (correo `@udla.edu.co` o código) y Cloud Firestore (perfiles, asignaturas, sesiones, asistencias e incidencias).
- **Validación de la asistencia:** sesión abierta por el docente (servidor + reglas). **La proximidad BLE no está implementada.**
- **Fuera de la app:** la creación de asignaturas y la apertura/cierre de sesiones (consola de Firebase o futura vista docente).

## 2. Estructura

```
lib/
├── main.dart                     # Arranque (try/catch de Firebase) y StartupErrorApp
├── firebase_options.dart         # FlutterFire (no editar a mano)
├── core/                         # colores, tema, rutas, validadores, mensajes, fechas
├── models/
│   ├── course.dart               # Course + ClassSchedule (horario semanal)
│   ├── course_session.dart       # CourseSession (sesiones del docente)
│   ├── attendance_record.dart    # AttendanceRecord (id = sessionId_uid)
│   ├── academic_snapshot.dart    # AcademicSnapshot (cálculos) + AcademicState (carga/datos/error)
│   └── user_profile.dart         # UserProfile, UserRole, UserSettings
├── services/
│   ├── user_profile_service.dart # users / codes
│   ├── academic_service.dart     # flujo combinado courses + sessions + attendance
│   ├── attendance_service.dart   # registro de asistencia e incidencias
│   ├── report_service.dart       # PDF del historial (pdf + printing)
│   ├── student_backend.dart      # StudentBackend + FirebaseStudentBackend
│   └── demo_backend.dart         # DemoMode + DemoStudentBackend (solo depuración)
├── screens/
│   ├── auth_gate.dart, login_screen.dart, register_screen.dart, forgot_password_screen.dart
│   ├── home_screen.dart          # suscripciones, 5 pestañas, alertas, PDF
│   ├── course_detail_screen.dart # detalle de asignatura (push)
│   ├── tabs/{dashboard,classes,attendance,history,profile}_tab.dart
│   └── attendance/attendance_{success,failed}_screen.dart
└── widgets/                      # compartidos (§6)
assets/fonts/                     # Roboto (Apache 2.0), incrustada en el PDF
test/                             # logic, academic, screens, student_screens (+ fixtures, helpers)
firestore.rules                   # reglas (se publican desde la consola)
```

## 3. Arranque y sesión

`main.dart` → `Firebase.initializeApp` (con `StartupErrorApp` si falla) → `MaterialApp(home: AuthGate)`. `AuthGate` escucha `userChanges()` y es el **único** que alterna Login y `HomeScreen(user)`.

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

## 7. Navegación

- Pestañas: 0 Inicio · 1 Mis Clases · 2 Asistencia · 3 Historial · 4 Perfil.
- La asignatura de Asistencia se **fija al entrar** (explícita desde un botón, o sugerida: primero una sesión pendiente y si no, la clase en horario). Las actualizaciones posteriores no reinician la búsqueda.
- `push`: detalle de asignatura y pantallas de resultado. Las rutas con nombre siguen siendo solo `/register` y `/forgot-password`.

## 8. Dependencias

| Paquete | Versión | Motivo |
|---|---|---|
| `firebase_core` / `firebase_auth` / `cloud_firestore` | 4.15.2 / 6.7.0 / 6.10.2 | Backend |
| `google_fonts` | 6.3.3 | Plus Jakarta Sans |
| `pdf` | 3.13.1 | **Nuevo:** generar el historial en PDF (aparece en el diseño) |
| `printing` | 5.15.1 | **Nuevo:** diálogo del sistema para guardar o compartir el PDF |
| `cupertino_icons`, `flutter_lints` | — | Plantilla y análisis |

## 9. Identificadores

Nombre visible "BioAsistencia"; `applicationId`/bundle `com.example…` sin cambiar; firma de release con claves de debug (pendiente).
