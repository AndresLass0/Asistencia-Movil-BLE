# Diseño: matrículas, importación y avisos (etapas 4–7)

> Propuesto y aprobado el 2026-11-14. **Implementado** (entrega 1, 2026-11-14): matrículas, invitaciones, cancelación, avisos y un celular por estudiante y sesión. El esquema vigente está en [`MODELO_DE_DATOS.md`](MODELO_DE_DATOS.md). **Pendiente (entrega 2):** lector `.xls` (D6) y la vista previa detallada de §7. Este documento conserva las decisiones y la validación.

## 1. Decisiones aprobadas

| # | Decisión |
|---|---|
| D1 | La matrícula sale del documento de la asignatura a una colección propia, `enrollments`, y se vincula por el **correo institucional verificado** (no por el uid ni por el código). El correo es obligatorio para cada estudiante. |
| D2 | **Un docente por asignatura.** Cada grupo de una misma materia (p. ej. Estructuras de Datos, grupos 1 y 2 con docentes distintos) es su propia asignatura (`courses`), con su docente, su horario y su lista. |
| D3 | Avisos **dentro de la app** (campana). Las notificaciones push quedan para más adelante (requieren Cloud Functions y el plan Blaze). |
| D4 | Si un estudiante canceló y una lista oficial importada después todavía lo incluye, **se respeta la cancelación** y la vista previa lo avisa. |
| D5 | La importación **reemplaza** la lista: quien no está en el archivo sale de la lista, aunque el docente lo haya agregado a mano (confirmado el 2026-11-14; sus asistencias se conservan). Antes de confirmar, la vista previa muestra cuántos entran, cambian y salen. |
| D6 | Formatos: `.xls` (Excel 97-2003, el que entrega la UDLA), `.xlsx` y `.csv`. El formato se detecta por el contenido, no por la extensión. |
| D7 | Del Excel solo se guardan **código, nombre, correo y programa**. Fecha de matrícula, documento, teléfono, EPS y `PENG_IDENTITARIO` se descartan en el teléfono del docente y nunca llegan a Firebase. |
| D8 | Agregado a mano por el docente → **invitación** que el estudiante acepta o rechaza. Importado del Excel → activo directamente. |
| D9 | El estudiante puede **cancelar** la asignatura; el docente recibe el aviso. Sus asistencias y faltas anteriores se conservan. |
| D10 | Firestore está vacío: no hay migración. Las cuentas de Auth sin perfil se borran desde la consola. |
| D11 | **Un celular registra a un solo estudiante por sesión** (contra el "favor entre amigos" con la contraseña de otro). No se ata la cuenta a un celular ni se limita cambiar de teléfono. |

## 2. Identidad

- **Persona en la app:** `users/{uid}` (sin cambios).
- **Estudiante dentro de una asignatura:** su correo institucional en minúsculas. Es lo único que comparten el Excel y la cuenta, y la app ya exige verificarlo.
- El **código** del Excel se guarda en la matrícula como dato informativo (reportes, búsqueda), y es la clave para detectar filas repetidas dentro de un archivo.

Consecuencia: `attendance`, `justifications` e `incidents` pasan a identificar al estudiante por correo. Así el docente puede tomar asistencia manual a un estudiante de la lista **aunque todavía no tenga cuenta** (hoy no puede).

## 3. Colecciones

Sin cambios: `users`, `codes` (login con código), `teachers` y `sessions`.

### `courses/{courseId}` (se quitan `roster` y `students`)
```
name, period, group, code, teacherName, teacherUid, room, building,
schedule, maxAbsences, registrationMinutes, createdAt
```

### `enrollments/{courseId}_{correo}` (nueva)
```
courseId: string       teacherUid: string      // copia de courses.teacherUid
email: string          // minúsculas, @udla.edu.co
code: string           // 5–15 dígitos (del Excel o escrito por el docente)
name: string           program: string         // '' si no viene
status: 'active' | 'invited' | 'declined' | 'withdrawn' | 'removed'
source: 'import' | 'manual'
createdAt: timestamp   statusAt: timestamp     // hora del servidor
teacherSeen: bool      // false cuando el estudiante rechaza o cancela; el docente lo marca al ver el aviso
```

| Estado | Significado | Puede registrar | Cuenta en porcentajes | Ve la asignatura |
|---|---|---|---|---|
| `active` | Matriculado | Sí | Sí | Mis Clases e historial |
| `invited` | El docente lo agregó a mano; falta que acepte | No | No | Solo la invitación |
| `declined` | Rechazó la invitación | No | No | No |
| `withdrawn` | El estudiante canceló | No | Solo hasta `statusAt` | Solo el historial |
| `removed` | No venía en la última lista importada | No | Solo hasta `statusAt` | Solo el historial |

**Transiciones permitidas**

| Quién | De → a | Cuándo |
|---|---|---|
| Docente | (nuevo) → `active` | Importación |
| Docente | (nuevo) → `invited` | Agregar a mano |
| Docente | `invited`, `removed` → `active` | Vuelve a aparecer en una lista importada |
| Docente | `declined`, `withdrawn`, `removed` → `invited` | Lo vuelve a invitar a mano |
| Docente | `active`, `invited` → `removed` | No viene en la lista importada, o lo quita a mano |
| Estudiante | `invited` → `active` / `declined` | Acepta o rechaza |
| Estudiante | `active` → `withdrawn` | Cancela la asignatura |

`withdrawn` **nunca** vuelve a `active` por una importación (D4): solo con una nueva invitación que el estudiante acepte.

### `attendance/{sessionId}_{correo}`
```
email: string          studentUid?: string     // solo si la registró el propio estudiante
deviceKey?: string     // huella del celular (solo registros del estudiante)
courseId, sessionId, teacherUid: string
method: 'session' | 'manual'                    registeredAt: timestamp
```

### `sessionDevices/{sessionId}_{dispositivo}` (nueva, D11)
```
email: string          sessionId: string       createdAt: timestamp
```
- `dispositivo` = huella del celular: SHA-256 de un identificador del sistema más una sal fija de la app. **No se guarda el identificador real** y no permite rastrear el teléfono fuera de BioAsistencia.
  - **Android:** `Settings.Secure.ANDROID_ID`. Sobrevive a reinstalar la app y a borrar sus datos; cambia con un restablecimiento de fábrica.
  - **iOS:** `identifierForVendor`. Cambia si se desinstalan todas las apps del mismo desarrollador. **No se puede probar aquí** (no hay Mac).
  - Se obtiene con un canal nativo pequeño en `MainActivity.kt` / `AppDelegate.swift`, sin paquetes nuevos.
- **Web y escritorio:** no hay un identificador estable, así que **no se puede registrar asistencia** desde ahí. La app explica que debe hacerse desde el celular.
- Se crea en el **mismo lote** que la asistencia del estudiante. Como `create` solo funciona si el documento no existe, un segundo estudiante en el mismo celular y la misma sesión es rechazado **en el servidor**.
- Nadie puede leer esta colección desde la app. La asistencia guarda `deviceKey` (la misma huella) para que el docente pueda revisar casos raros más adelante.

### `justifications/{sessionId}_{correo}`
```
sessionId, courseId, email, teacherUid: string
status: 'justified' | 'confirmed'               updatedAt: timestamp
```

### `incidents/{autoId}`
```
email, studentUid, courseId, teacherUid: string   sessionId?: string
message: string (≤ 500)                           createdAt: timestamp
```

## 4. Consultas de la app (validación de índices)

| Pantalla | Consulta | Índice |
|---|---|---|
| Estudiante: sus matrículas | `enrollments where email == yo` | Simple (automático) |
| Estudiante: sus asignaturas | `get courses/{id}` por cada matrícula visible | — |
| Estudiante: sesiones | `sessions where courseId in [≤30]` | Simple |
| Estudiante: sus asistencias | `attendance where email == yo` | Simple |
| Estudiante: registrar | `sessions where courseId == X and status == 'open'` | Igualdades: sin índice compuesto |
| Docente: todo lo suyo | `courses / sessions / enrollments / attendance / justifications / incidents where teacherUid == yo` | Simple |

**No hace falta ningún índice compuesto.** Pendiente para más adelante: el docente descarga todas sus asistencias históricas; con varios semestres convendrá filtrarlas por periodo.

**Costo aproximado:** al abrir la app, un estudiante con 6 asignaturas lee unos 12 documentos más sus sesiones y asistencias. Importar 35 estudiantes son unas 35 escrituras en un solo lote.

## 5. Reglas (resumen)

- `myEmail()` = el correo del token en minúsculas (`request.auth.token.email.lower()`). `enrollmentOf(c)` = `enrollments/{c}_{myEmail()}`.
- **courses:** lectura para el docente dueño, o para un usuario verificado cuya matrícula esté en `active`, `invited`, `withdrawn` o `removed`. Escritura solo para el docente dueño.
- **enrollments:**
  - Lectura: el docente dueño (`teacherUid`) o el propio estudiante verificado (`email == myEmail()`).
  - Creación: solo el docente dueño de la asignatura. El id debe ser `{courseId}_{email}`, el correo `@udla.edu.co`, el código de 5–15 dígitos, el estado `active` si `source == 'import'` o `invited` si es `manual`, y `createdAt` y `statusAt` iguales a la hora del servidor.
  - Actualización por el docente: nombre, código y programa; el estado según la tabla de transiciones; `teacherSeen`. No puede cambiar `email`, `courseId` ni `teacherUid`.
  - Actualización por el estudiante: solo `status`, `statusAt` y `teacherSeen`, con las transiciones de la tabla, `statusAt` = hora del servidor y `teacherSeen` = false.
  - Borrado: solo el docente dueño (al eliminar la asignatura).
- **attendance:**
  - Estudiante: correo verificado, id `{sessionId}_{myEmail()}`, matrícula `active`, sesión abierta y antes de `endsAt`, y `getAfter(sessionDevices/{sessionId}_{deviceKey}).email == myEmail()` (el lote debe crear ese documento).
- **sessionDevices:** creación solo por un usuario verificado, con `email == myEmail()` y `createdAt` = hora del servidor, si existe en el mismo lote su asistencia (`existsAfter`). Sin lectura, actualización ni borrado.
  - Docente: dueño de la asignatura, y la matrícula de ese correo está `active`.
  - Lectura: el propio estudiante (`email == myEmail()`) o el docente dueño.
- **justifications:** las escribe el docente dueño y las lee el propio estudiante por correo.
- **incidents:** las crea el estudiante verificado con matrícula `active` o `withdrawn`, y las lee el docente dueño.

## 6. Avisos dentro de la app (campana)

- **Estudiante:** sus matrículas en `invited` → "Prof. X te agregó a {asignatura} · {grupo}", con los botones Aceptar y Rechazar. Además de la sesión abierta que ya se avisa hoy.
- **Docente:** matrículas con `teacherSeen == false` y estado `withdrawn` o `declined` → "{nombre} canceló / rechazó {asignatura}". Al verlo se marca `teacherSeen = true`.

## 7. Importación (flujo)

1. **Leer:** se detecta el formato por el contenido (`.xls`, `.xlsx` o `.csv`) y se toma la primera hoja.
2. **Encabezados:** se normalizan (mayúsculas, tildes, espacios, `_`). Equivalencias:
   - código: `CODIGOESTUDIANTE`, `CODIOESTUDIANTE`, `CODIGO`, `COD`…
   - nombre: `NOMBRECOMPLETO`, `NOMBRE`…
   - correo: `MAIL_INST`, `CORREO`, `EMAIL`…
   - programa: `PROGRAMA`.

   Si falta el código, el nombre o el correo, el archivo se rechaza con un mensaje claro.
3. **Celdas:** los números se convierten a texto entero ("4245…" sin ".0" ni notación científica), las fechas se ignoran y los espacios se recortan.
4. **Validación por fila:** código de 5–15 dígitos, nombre no vacío y correo válido `@udla.edu.co`. Las filas vacías se saltan.
5. **Repetidos dentro del archivo:** mismo código o mismo correo → se conserva el primero y los demás se reportan.
6. **Comparación con la lista actual:** nuevos, sin cambios, actualizados (nombre, código o programa), que salen (`removed`) y cancelados que siguen en el archivo (no cambian, D4).
7. **Vista previa:** total de filas, válidas, nuevos, actualizados, salen, repetidos, rechazados (con fila y motivo) y avisos (códigos de distinta longitud, cancelados presentes). Botones Confirmar y Cancelar.
8. **Guardar:** un solo lote de escrituras. Si falla, no se guarda nada a medias.

Importar dos veces el mismo archivo no cambia nada: los ids `{courseId}_{correo}` son fijos y los datos son iguales.

## 8. BLE

El protocolo no está definido. Cuando lo esté, los datos de la señal irán en `sessions/{id}` (p. ej. un identificador distinto en cada sesión). El resto del modelo no cambia.

## 9. Validación del diseño (etapa 7)

Cada operación de la app se comparó con las reglas y los límites de Firestore:

| Comprobación | Resultado |
|---|---|
| Cada consulta tiene una regla que la permite con su propio filtro (`email == yo` / `teacherUid == yo`) | ✅ Firestore rechaza las consultas que podrían devolver documentos no permitidos; todas filtran por el campo que exige la regla |
| Un estudiante no puede ver la lista de sus compañeros | ✅ Solo lee `enrollments` con su correo; `courses` ya no contiene la lista |
| Un estudiante no puede matricularse solo, reactivarse tras cancelar ni tocar la matrícula de otro | ✅ Solo transiciones `invited → active/declined` y `active → withdrawn` sobre su propio correo |
| Un estudiante no puede registrar asistencia de otro | ✅ El id y `email` deben ser su correo del token, verificado |
| Asistencia manual a estudiantes sin cuenta | ✅ Ahora es posible: el id usa el correo, no el uid |
| Dos estudiantes en el mismo celular y la misma sesión (D11) | ✅ El segundo lote falla: `sessionDevices/{sesión}_{dispositivo}` ya existe y `create` no sobrescribe. La app muestra "Este celular ya registró a otro estudiante en esta sesión" |
| Bloquear el celular de otro creando su `sessionDevices` | ✅ Hace falta conocer su huella, que nadie puede leer, y el documento solo se crea junto a una asistencia propia |
| Reintentar el registro (mala señal) | ✅ Si la asistencia ya existe, la app responde "ya registrada" sin volver a escribir |
| Mayúsculas en el correo | Las reglas comparan con `request.auth.token.email.lower()` y la app guarda todo en minúsculas |
| Límite de lecturas dentro de las reglas (10 por documento; 20 por lote) | Registro del estudiante: 4 (sesión, asignatura, matrícula y `sessionDevices`). Asistencia manual: 4 (asignatura, docente, sesión, matrícula). Importación: cada alta lee la asignatura y `teachers/{correo}`, siempre los mismos dos documentos. **Verificar en el dispositivo** que un lote de 35 o más altas pasa; si no, se guarda en lotes más pequeños |
| Tamaño máximo de un lote (500 escrituras) | ✅ Una lista de 300 estudiantes cabe. Si alguna vez hay más, se divide |
| Índices compuestos | ✅ No hacen falta (§4) |

## 10. Orden de implementación

1. Modelos y lógica pura: `Enrollment`, estados y transiciones, y los cálculos del estudiante y del docente basados en matrículas.
2. Reglas de Firestore (incluida `sessionDevices`) y el canal nativo para la huella del celular.
3. Servicios: `FirebaseStudentBackend` y `FirebaseTeacherBackend`, y sus versiones de prueba en `test/fakes/`.
4. Pantallas del docente (lista de la asignatura, agregar a mano) y del estudiante (invitaciones, cancelar), más los avisos.
5. Lector `.xls` e importación con vista previa (etapa 9).
6. Pruebas, documentación y revisión de desbordamientos.
