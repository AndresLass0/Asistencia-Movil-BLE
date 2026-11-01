# Modelo de datos (Cloud Firestore)

> Fuente de verdad: modelos en `lib/models/`, servicios en `lib/services/` y reglas en `firestore.rules`. Si cambias un campo, actualiza los tres y este documento.

## Colecciones

| Colección | Id del documento | Quién escribe | Lo lee la app en |
|---|---|---|---|
| `users` | uid de Firebase Auth | El usuario, al registrarse; luego solo `program`, `semester`, `campus`, `settings` y `bleEnabled` | `UserProfileService` |
| `codes` | código institucional | El usuario, al registrarse (una sola vez) | Login con código |
| `courses` | libre | **Consola / futura vista docente** (la app no escribe) | `AcademicService` |
| `sessions` | libre | **Consola / futura vista docente** (la app no escribe) | `AcademicService`, `AttendanceService` |
| `attendance` | `{sessionId}_{uid}` | El estudiante, solo con la sesión abierta | `AcademicService` |
| `incidents` | automático | El estudiante | Nadie desde la app (los revisa el docente o el administrador) |

### `users/{uid}`
```
name: string            email: string          role: 'student' | 'teacher'
code: string (5–15 dígitos)                     faculty: string
bleEnabled: bool        createdAt: timestamp
program?: string        semester?: int (1–20)  campus?: string     // los completa el usuario
settings?: { liveSessionAlerts: bool, riskAlerts: bool }            // por defecto true
```

### `courses/{courseId}`
```
name: string            period: string ("2026-1"; se ordena como texto, el mayor es el actual)
group?: string          teacherName?: string   room?: string       building?: string
schedule?: [ { day: 1..7 (1 = lunes), start: "HH:mm", end: "HH:mm" } ]
maxAbsences?: int       // faltas permitidas; sin este campo no se muestra margen ni alerta
students: [uid, ...]    // matriculados (obligatorio para que el estudiante vea la asignatura)
```

### `sessions/{sessionId}`
```
courseId: string        status: 'open' | 'closed'
startsAt: timestamp     endsAt?: timestamp
```

### `attendance/{sessionId}_{uid}`
```
studentUid: string      courseId: string       sessionId: string
registeredAt: timestamp (hora del servidor)
```

### `incidents/{autoId}`
```
studentUid: string      courseId: string       sessionId?: string
message: string (≤ 500) createdAt: timestamp (hora del servidor)
```

## Cálculos (en `AcademicSnapshot`)

- **Asistida:** sesión con documento en `attendance`.
- **Falta:** sesión **cerrada** sin asistencia. Una sesión abierta sin registro no cuenta como falta.
- **Porcentaje:** asistidas ÷ (asistidas + faltas). Si no hay sesiones, se muestra "—".
- **Periodo actual:** el `period` más reciente entre las asignaturas del estudiante.
- **Clases de hoy / siguiente clase:** a partir de `schedule` y de la hora del dispositivo.
- **Sesión pendiente:** sesión abierta sin asistencia del estudiante (activa la campana, el banner y la alerta en vivo).

## Validación de la asistencia

Las reglas permiten crear `attendance` solo si:
1. el id es `{sessionId}_{uid}`, lo que impide duplicados;
2. la sesión existe y está `open`;
3. el `courseId` coincide con el de la sesión y el estudiante está en `courses/{courseId}.students`;
4. `registeredAt` es la hora del servidor.

**La proximidad (BLE) no se verifica todavía**: cualquier estudiante matriculado puede registrarse mientras la sesión esté abierta, aunque no esté en el aula.

## Cargar datos de prueba (consola de Firebase)

1. Publica `firestore.rules`.
2. Regístrate en la app con un correo `@udla.edu.co` y copia tu uid desde *Authentication*.
3. En *Firestore* crea `courses/prog1`, por ejemplo:
   `name: "Programación I"`, `period: "2026-2"`, `teacherName: "…"`, `room: "…"`, `schedule: [{day: 1, start: "08:00", end: "10:00"}]`, `students: ["<tu uid>"]`.
4. Crea `sessions/ses1` con `courseId: "prog1"`, `status: "open"` y `startsAt` con la fecha y hora actuales.
5. En la app: Inicio y Mis Clases muestran la sesión abierta, y "Registrar asistencia" crea `attendance/ses1_<uid>`.
6. Cambia `status` a `"closed"` y crea otra sesión sin registrarte: aparecerá como falta.

Las consultas usan `whereIn` e igualdades simples, que funcionan con los índices automáticos. Si Firestore pide un índice compuesto, el mensaje de error incluye el enlace para crearlo.
