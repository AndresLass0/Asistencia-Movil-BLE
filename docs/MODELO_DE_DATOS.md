# Modelo de datos (Cloud Firestore)

> Fuente de verdad: modelos en `lib/models/`, servicios en `lib/services/` y reglas en `firestore.rules`. Si cambias un campo, actualiza los tres y este documento.
> Actualizado el 2026-11-14: matrículas (`enrollments`), invitaciones, cancelación y un celular por estudiante y sesión (`sessionDevices`). Decisiones y validación del diseño: [`DISENO_MATRICULAS.md`](DISENO_MATRICULAS.md).

## Colecciones

| Colección | Id del documento | Quién escribe | Lo lee |
|---|---|---|---|
| `users` | uid de Firebase Auth | El usuario al registrarse; luego solo `program`, `semester`, `campus`, `settings` y `bleEnabled` | El propio usuario (`UserProfileService`, `RoleGate`) |
| `codes` | código institucional | El usuario al registrarse (una sola vez) | Login con código; el docente para vincular su lista |
| `teachers` | correo en minúsculas | **Solo la administración, desde la consola** | El propio docente (su correo) |
| `courses` | automático | **El docente dueño** (`teacherUid`) | El docente dueño y el estudiante con matrícula visible |
| `enrollments` | `{courseId}_{correo}` | El docente dueño (lista, invitaciones); el estudiante solo acepta, rechaza o cancela la suya | El docente dueño y el propio estudiante |
| `sessions` | automático | **El docente dueño** (abrir y finalizar) | Usuarios verificados |
| `sessionDevices` | `{sessionId}_{huella}` | El estudiante, junto con su asistencia | Nadie lista; lectura individual |
| `attendance` | `{sessionId}_{correo}` | El estudiante (con la sesión abierta) o el docente (excepción manual) | El estudiante (las suyas) y el docente (`teacherUid`) |
| `justifications` | `{sessionId}_{correo}` | El docente dueño | El docente y el propio estudiante |
| `incidents` | automático | El estudiante matriculado (o que canceló) | El docente de la asignatura |

**Identidad del estudiante dentro de una asignatura: su correo institucional en minúsculas.** Es lo que comparten la lista oficial y la cuenta, y la app exige verificarlo. El uid solo se usa en `users` y `codes`.

### `users/{uid}`
```
name: string            email: string          role: 'student' | 'teacher'
code: string (5–15 dígitos)                     faculty: string
bleEnabled: bool        createdAt: timestamp
program?: string        semester?: int (1–20)  campus?: string     // los completa el usuario
settings?: { liveSessionAlerts: bool, riskAlerts: bool }            // por defecto true
```
`role: 'teacher'` solo se acepta al crear el perfil si el correo está en `teachers/`. **El rol del perfil solo decide qué vista se muestra**; los permisos de docente los dan las reglas (`isTeacher()`).

### `teachers/{correo}` (lista de docentes autorizados)
```
active?: bool           // false revoca el acceso; si falta, se considera true
name?: string           // opcional, solo informativo
```

### `courses/{courseId}` (un grupo de una materia, un docente)
```
name: string            period: string ("2026-1"; se ordena como texto, el mayor es el actual)
group: string           teacherName: string    room: string        building: string
code: string            // código de la materia (opcional)
teacherUid: string      // docente dueño
schedule: [ { day: 1..7 (1 = lunes), start: "HH:mm", end: "HH:mm" } ]
maxAbsences: int | null // faltas permitidas; null = sin margen ni alerta de riesgo
registrationMinutes: int (1–240)   // duración predeterminada del registro (5/10/15/20 en la app)
createdAt: timestamp
```
La misma materia con otro docente u otro horario es **otra asignatura** (otro `courseId`, distinto `group`).

### `enrollments/{courseId}_{correo}`
```
courseId: string       teacherUid: string      // copia de courses.teacherUid
email: string          // minúsculas, @udla.edu.co
code: string (5–15 dígitos)                    name: string        program: string ('' si no viene)
status: 'active' | 'invited' | 'declined' | 'withdrawn' | 'removed'
source: 'import' | 'manual'
createdAt: timestamp   statusAt: timestamp     // hora del servidor
teacherSeen: bool      // false: rechazo o cancelación que el docente aún no vio
```

| Estado | Significado | Registra | Cuenta en porcentajes | El estudiante la ve |
|---|---|---|---|---|
| `active` | Matriculado | Sí | Sesiones que terminan después de `statusAt` | Mis Clases e historial |
| `invited` | Agregado a mano; falta que acepte | No | No | Solo la invitación |
| `declined` | Rechazó la invitación | No | No | No |
| `withdrawn` | Canceló la asignatura | No | Solo sesiones que empezaron antes de `statusAt` | Historial |
| `removed` | No venía en la última lista importada (o el docente lo quitó) | No | Igual que `withdrawn` | Historial |

**Transiciones:** docente: nuevo → `active` (importación) o `invited` (a mano); `invited`/`removed` → `active` (aparece en una lista importada); `declined`/`withdrawn`/`removed` → `invited` (lo vuelve a invitar); `active`/`invited` → `removed`. Estudiante: `invited` → `active`/`declined`; `active` → `withdrawn`. **`withdrawn` nunca vuelve a `active` por una importación**: solo con una invitación aceptada.

**Importar una lista (`RosterPlan.forImport`)** reemplaza la lista oficial: los del archivo quedan activos (nuevos, actualizados o de vuelta), y los que vinieron de una importación anterior y ya no están pasan a `removed`. La lista queda **igual al archivo**: también salen los agregados a mano que no vienen en él. Quien canceló o rechazó y sigue en el archivo no cambia. La vista previa muestra todo antes de aplicarlo y el formulario guarda solo las diferencias (`RosterPlan.diff`). Importar dos veces el mismo archivo no cambia nada.

### `sessions/{sessionId}`
```
courseId: string        teacherUid: string     status: 'open' | 'closed'
startsAt: timestamp (hora del servidor)
endsAt: timestamp       // fin de la ventana de registro (≤ 4 h)
closedAt?: timestamp    // cuando el docente la finaliza
```
Una sesión **admite registros** si `status == 'open'` y la hora es anterior a `endsAt`. Si `endsAt` pasó pero el docente no la finalizó, ya no admite registros y la app la muestra como "Registro cerrado · sin finalizar".

### `attendance/{sessionId}_{correo}`
```
email: string           courseId: string       sessionId: string
teacherUid: string      // copia de courses.teacherUid (permite al docente consultarla)
method: 'session' | 'manual'   // estudiante desde la app / excepción del docente
registeredAt: timestamp (hora del servidor)
studentUid?: string     deviceKey?: string     // solo en los registros del estudiante
```
El docente puede registrar manualmente a un estudiante matriculado **aunque todavía no tenga cuenta**.

### `sessionDevices/{sessionId}_{huella}` (un celular, un estudiante por sesión)
```
email: string           sessionId: string      createdAt: timestamp
```
La huella es el SHA-256, con una sal de la app, de `ANDROID_ID` (Android) o `identifierForVendor` (iOS), calculado en el código nativo (`MainActivity.kt`, `AppDelegate.swift`). No se guarda el identificador real. Se crea en el mismo lote que la asistencia; como `create` no sobrescribe, un segundo estudiante en el mismo celular y la misma sesión es rechazado por el servidor. Desde web o escritorio no se puede registrar asistencia (no hay identificador estable).

### `justifications/{sessionId}_{correo}`
```
sessionId, courseId, email, teacherUid: string
status: 'justified' | 'confirmed'
updatedAt: timestamp (hora del servidor)
```
Es una anotación del docente: **la inasistencia sigue contando** en los porcentajes (no hay una regla institucional confirmada sobre faltas justificadas).

### `incidents/{autoId}`
```
studentUid: string      email: string          courseId: string       sessionId?: string
teacherUid: string      message: string (≤ 500) createdAt: timestamp
```

## Cálculos

**Estudiante (`AcademicSnapshot`)**
- **Asistida:** sesión con documento en `attendance`.
- **Falta:** sesión que ya no admite registros (finalizada o con la ventana vencida) sin asistencia, **en la que debía estar** según su matrícula (`Enrollment.expectedAt`).
- **Mis Clases / Inicio:** solo asignaturas con matrícula `active`. Las invitaciones se muestran aparte; las canceladas o retiradas solo en el historial.
- **Porcentaje:** asistidas ÷ (asistidas + faltas); sin sesiones se muestra "—".
- **Periodo actual:** el `period` más reciente. **Clases de hoy / siguiente clase:** `schedule` + hora del dispositivo.

**Docente (`TeacherSnapshot`)**
- **Sesión realizada:** la que ya no admite registros.
- **Planilla de una sesión:** las matrículas que debían estar en esa sesión (`expectedAt`; en una sesión abierta, todos los `active`) + asistencias de estudiantes que ya no estaban en la lista. Las invitaciones pendientes no cuentan.
- **Avisos:** matrículas `withdrawn`/`declined` con `teacherSeen == false` (campana del docente).
- **Asistencia de una asignatura:** presentes ÷ (estudiantes × sesiones realizadas).
- **En riesgo:** mismo criterio que la alerta del estudiante: le queda 1 falta o menos de `maxAbsences`. Sin `maxAbsences` no hay riesgo.
- **Asistencia mensual:** agrupada por el mes de inicio de la sesión.

Las funciones `todayClassesOf` y `nextClassOf` las comparten ambos roles.

## Reglas principales

- `verified()` = sesión iniciada **+ correo verificado**. Se exige para leer asignaturas y sesiones, registrar asistencia (estudiante) y reportar incidencias. No se exige para crear `users/{uid}` y `codes/{código}`, porque se guardan al registrarse, antes de poder abrir el enlace.
- `isTeacher()` = sesión iniciada **+ correo verificado + correo en `teachers/` activo**.
- El docente solo crea, edita o borra asignaturas con `teacherUid == su uid`, y solo abre y finaliza sesiones de esas asignaturas. Una sesión finalizada no se puede reabrir ni borrar.
- El estudiante solo registra asistencia con su matrícula `active`, la sesión `open`, antes de `endsAt`, con `method: 'session'` y creando a la vez `sessionDevices/{sesión}_{huella}`. El id `{sessionId}_{correo}` impide duplicados.
- El docente solo añade asistencias manuales de estudiantes con matrícula `active` en su asignatura.
- Cada estudiante solo lee **su** matrícula: nadie ve la lista de sus compañeros.
- Nadie modifica ni borra asistencias.

**La proximidad (BLE) no se verifica**: cualquier estudiante matriculado puede registrarse mientras la ventana esté abierta, aunque no esté en el aula.

## Configuración y datos de prueba (consola de Firebase)

1. Publica `firestore.rules`.
2. **Autoriza a un docente:** en *Firestore*, crea el documento `teachers/<correo@udla.edu.co>` (id = correo en minúsculas) con `active: true`.
3. Ese docente se registra en la app eligiendo "Docente", **verifica su correo** con el enlace que recibe y entra en la vista del docente.
4. El docente crea una clase y carga la lista oficial (código, nombre y **correo institucional**). No hace falta que los estudiantes tengan cuenta: cuando se registren con ese correo verán la clase solos.
5. Cada estudiante se registra y **verifica su correo** antes de ver sus clases. El docente pulsa "Iniciar asistencia". Los estudiantes registran su asistencia desde Inicio o Mis Clases; el docente los ve aparecer en la sesión activa.
6. El docente finaliza la sesión y revisa las inasistencias.

Las consultas usan igualdades simples y `whereIn`, que funcionan con los índices automáticos. Si Firestore pide un índice compuesto, el error incluye el enlace para crearlo.
