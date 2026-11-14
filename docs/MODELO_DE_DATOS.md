# Modelo de datos (Cloud Firestore)

> Fuente de verdad: modelos en `lib/models/`, servicios en `lib/services/` y reglas en `firestore.rules`. Si cambias un campo, actualiza los tres y este documento.
> Actualizado el 2026-11-01 con la vista del docente.

## Colecciones

| Colección | Id del documento | Quién escribe | Lo lee |
|---|---|---|---|
| `users` | uid de Firebase Auth | El usuario al registrarse; luego solo `program`, `semester`, `campus`, `settings` y `bleEnabled` | El propio usuario (`UserProfileService`, `RoleGate`) |
| `codes` | código institucional | El usuario al registrarse (una sola vez) | Login con código; el docente para vincular su lista |
| `teachers` | correo en minúsculas | **Solo la administración, desde la consola** | El propio docente (su correo) |
| `courses` | automático | **El docente dueño** (`teacherUid`) | El docente dueño y los estudiantes en `students` |
| `sessions` | automático | **El docente dueño** (abrir y finalizar) | Usuarios autenticados |
| `attendance` | `{sessionId}_{uid}` | El estudiante (con la sesión abierta) o el docente (excepción manual) | El estudiante (las suyas) y el docente (`teacherUid`) |
| `justifications` | `{sessionId}_{uid}` | El docente dueño | El docente y el propio estudiante |
| `incidents` | automático | El estudiante matriculado | El docente de la asignatura |

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

### `courses/{courseId}`
```
name: string            period: string ("2026-1"; se ordena como texto, el mayor es el actual)
group: string           teacherName: string    room: string        building: string
code: string            // código interno de la asignatura (opcional)
teacherUid: string      // docente dueño (vacío en asignaturas cargadas desde la consola)
schedule: [ { day: 1..7 (1 = lunes), start: "HH:mm", end: "HH:mm" } ]
maxAbsences: int | null // faltas permitidas; null = sin margen ni alerta de riesgo
registrationMinutes: int (1–240)   // duración predeterminada del registro (5/10/15/20 en la app)
roster: [ { code, name, email, uid? } ]   // lista oficial cargada por el docente
students: [uid, ...]    // matriculados = entradas de roster con uid (pueden registrar)
createdAt: timestamp
```
**Vincular la lista:** al guardar la clase, la app busca cada código en `codes/{código}`. Si existe (y el correo coincide cuando la lista trae correo), guarda el `uid` en la entrada y lo añade a `students`. Los estudiantes que aún no tienen cuenta quedan en la lista **sin** `uid`: aparecen como "Sin cuenta en BioAsistencia" y no pueden registrar asistencia. Cuando se registren, el docente vuelve a guardar la clase (Editar → Guardar cambios) para vincularlos.

### `sessions/{sessionId}`
```
courseId: string        teacherUid: string     status: 'open' | 'closed'
startsAt: timestamp (hora del servidor)
endsAt: timestamp       // fin de la ventana de registro (≤ 4 h)
closedAt?: timestamp    // cuando el docente la finaliza
```
Una sesión **admite registros** si `status == 'open'` y la hora es anterior a `endsAt`. Si `endsAt` pasó pero el docente no la finalizó, ya no admite registros y la app la muestra como "Registro cerrado · sin finalizar".

### `attendance/{sessionId}_{uid}`
```
studentUid: string      courseId: string       sessionId: string
teacherUid: string      // copia de courses.teacherUid (permite al docente consultarla)
method: 'session' | 'manual'   // estudiante desde la app / excepción del docente
registeredAt: timestamp (hora del servidor)
```

### `justifications/{sessionId}_{uid}`
```
sessionId, courseId, studentUid, teacherUid: string
status: 'justified' | 'confirmed'
updatedAt: timestamp (hora del servidor)
```
Es una anotación del docente: **la inasistencia sigue contando** en los porcentajes (no hay una regla institucional confirmada sobre faltas justificadas).

### `incidents/{autoId}`
```
studentUid: string      courseId: string       sessionId?: string
teacherUid: string      message: string (≤ 500) createdAt: timestamp
```

## Cálculos

**Estudiante (`AcademicSnapshot`)**
- **Asistida:** sesión con documento en `attendance`.
- **Falta:** sesión que ya no admite registros (finalizada o con la ventana vencida) sin asistencia.
- **Porcentaje:** asistidas ÷ (asistidas + faltas); sin sesiones se muestra "—".
- **Periodo actual:** el `period` más reciente. **Clases de hoy / siguiente clase:** `schedule` + hora del dispositivo.

**Docente (`TeacherSnapshot`)**
- **Sesión realizada:** la que ya no admite registros.
- **Planilla de una sesión:** la lista oficial + matriculados que no están en ella + asistencias de estudiantes fuera de la lista.
- **Asistencia de una asignatura:** presentes ÷ (estudiantes × sesiones realizadas).
- **En riesgo:** mismo criterio que la alerta del estudiante: le queda 1 falta o menos de `maxAbsences`. Sin `maxAbsences` no hay riesgo.
- **Asistencia mensual:** agrupada por el mes de inicio de la sesión.

Las funciones `todayClassesOf` y `nextClassOf` las comparten ambos roles.

## Reglas principales

- `isTeacher()` = sesión iniciada **+ correo verificado + correo en `teachers/` activo**.
- El docente solo crea, edita o borra asignaturas con `teacherUid == su uid`, y solo abre y finaliza sesiones de esas asignaturas. Una sesión finalizada no se puede reabrir ni borrar.
- El estudiante solo registra asistencia con la sesión `open`, antes de `endsAt`, matriculado y con `method: 'session'`. El id `{sessionId}_{uid}` impide duplicados.
- El docente solo añade asistencias manuales de estudiantes matriculados en su asignatura.
- Nadie modifica ni borra asistencias.

**La proximidad (BLE) no se verifica**: cualquier estudiante matriculado puede registrarse mientras la ventana esté abierta, aunque no esté en el aula.

## Configuración y datos de prueba (consola de Firebase)

1. Publica `firestore.rules`.
2. **Autoriza a un docente:** en *Firestore*, crea el documento `teachers/<correo@udla.edu.co>` (id = correo en minúsculas) con `active: true`.
3. Ese docente se registra en la app eligiendo "Docente", **verifica su correo** con el enlace que recibe y entra en la vista del docente.
4. El docente crea una clase y carga la lista (códigos de los estudiantes). Los estudiantes que ya tienen cuenta quedan vinculados.
5. El docente pulsa "Iniciar asistencia". Los estudiantes registran su asistencia desde Inicio o Mis Clases; el docente los ve aparecer en la sesión activa.
6. El docente finaliza la sesión y revisa las inasistencias.

Las asignaturas antiguas cargadas a mano siguen funcionando para el estudiante (sin `teacherUid` ningún docente las ve). Las consultas usan igualdades simples y `whereIn`, que funcionan con los índices automáticos. Si Firestore pide un índice compuesto, el error incluye el enlace para crearlo.
