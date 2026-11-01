# Pantallas y flujos

> Actualizado el 2026-11-01, tras implementar las vistas del estudiante (diseños en `docs/images_views_estudiante/`).
> Revisión visual: capturas renderizadas desde pruebas de widgets (Roboto en lugar de Plus Jakarta Sans). **No** se probó en un dispositivo con datos reales de Firestore.

## 1. Mapa

```
AuthGate ─┬─ sin sesión → Login ─┬─ push → Registro (/register)
          │                      └─ push → Recuperar (/forgot-password)
          └─ con sesión → HomeScreen
                 ├─ [0] Inicio ──────────┐
                 ├─ [1] Mis Clases ──────┼─ "Ver detalle" / tarjeta → push Detalle de asignatura
                 ├─ [2] Asistencia ◀─────┘  (botones "Registrar asistencia", campana, alerta)
                 │      └─ push → Comprobante | Señal no encontrada ─ pop(AttendanceAction)
                 ├─ [3] Historial (Mi progreso académico) ── "Descargar PDF"
                 └─ [4] Perfil ── Editar información · alertas · Cerrar sesión → Login
```

## 2. Autenticación (sin cambios en esta fase)

Login (correo `@udla.edu.co` o código), Registro (rol, código único, facultad), Recuperar contraseña (doble factor "Próximamente"). Ver `docs/MODELO_DE_DATOS.md` para `users` y `codes`.

## 3. Vistas del estudiante

**Modo demostración (solo depuración):** "Demostración: Entrar como Estudiante" del Login abre estas mismas vistas con datos de ejemplo en memoria (`DemoStudentBackend`). Nada se lee ni se escribe en Firebase y una franja oscura lo indica. Se puede registrar la asistencia de la sesión abierta de ejemplo, editar el perfil y generar el PDF; las incidencias no se envían. "Cerrar sesión" vuelve al Login. "Entrar como Docente" solo avisa de que la vista docente aún no existe.

Todas las pestañas muestran estados de **carga**, **error** ("No se pudieron cargar tus clases" con la causa) y **sin asignaturas** ("Aún no tienes asignaturas").

### Cabecera (todas las pestañas)
Logo, "BioAsistencia" y subtítulo por pestaña ("Portal Docente" en Inicio si el rol es docente). El chip de sede solo aparece si el usuario la registró en Perfil. La **campana** abre la lista de sesiones abiertas pendientes, con su botón "Registrar"; el punto verde indica que hay alguna.

### [0] Inicio — `tabs/dashboard_tab.dart`
| Elemento | Fuente |
|---|---|
| "Hola, {nombre}" + fecha | Auth/perfil + reloj |
| "¿Estás en el aula?" → Registrar asistencia | Elige la asignatura automáticamente |
| Alerta de riesgo | Asignaturas con `maxAbsences` y ≤ 1 falta restante, si la preferencia está activa |
| Mis clases de hoy | `schedule` + hora: "Sesión abierta" (con botón), "Presente", "En horario", "Hoy a las X", "Sin registro", "Finalizada". Tocar la tarjeta abre el detalle |
| Resumen de asistencia | Periodo actual: %, asistencias, ausencias, total |
| Siguiente clase | Próxima franja del horario ("Hoy", "Mañana" o el día); abre el detalle |

### [1] Mis Clases — `tabs/classes_tab.dart`
Título con indicador **En línea / Sin conexión** (según la caché de Firestore); "Periodo X • N asignaturas inscritas"; **banner** de sesión abierta con "Registrar asistencia" y botón para ocultarlo; **búsqueda** por asignatura, docente, aula o grupo; filtros **Todas / Con sesión activa / Por horario**. Cada tarjeta muestra estado, grupo, docente, anillo de %, horario, aula y "X de Y asistencias", con los botones "Registrar asistencia" (solo con sesión pendiente) y "Ver detalle de clase".

### Detalle de asignatura — `course_detail_screen.dart` (nuevo; sin diseño de referencia)
Periodo, grupo, docente, %, horario y aula; asistidas, faltas y margen (o total de sesiones); botón Registrar si hay sesión pendiente; lista de sesiones con su estado (Presente con hora, Abierta, Ausente); reportar incidencia. Se actualiza en vivo.

### [2] Asistencia — `tabs/attendance_tab.dart`
Muestra la asignatura fijada al entrar. Busca la sesión abierta en el servidor y registra la asistencia. Si no hay una clase que registrar: "No hay una clase para registrar", con acceso a Mis Clases.

### Comprobante — `attendance/attendance_success_screen.dart`
"¡Asistencia registrada!" o "Ya habías registrado tu asistencia". Comprobante `AS-aammdd-hhmmss`, asignatura y docente, fecha y hora de inicio de la sesión, hora de registro del servidor con "+N min desde el inicio", aula, y método "Sesión abierta por el docente". Botones Volver al inicio / Ver en mi historial.

### Señal no encontrada — `attendance/attendance_failed_screen.dart`
Título, mensaje e ícono según la causa: sin sesión abierta, sin conexión, rechazado o error. Consejos (conexión, asignatura correcta, confirmar con el docente); botones Intentar nuevamente y Volver al inicio; **Reportar incidencia** guarda un documento en `incidents`.

### [3] Historial — `tabs/history_tab.dart` (Mi progreso académico)
Promedio histórico, número de periodos, clases totales, asistidas e inasistencias; chips de periodo (el actual marcado "En curso"); promedio del periodo; tarjeta por asignatura con %, "X / Y asistidas", barra de progreso, faltas y margen (solo con `maxAbsences`). Tocar una tarjeta abre el detalle. **Descargar historial académico (PDF)** genera el documento y abre el diálogo del sistema.

### [4] Perfil — `tabs/profile_tab.dart`
Avatar, nombre, correo, rol, código, nivel académico (semestre o "Sin registrar") e índice presencial (% histórico). La información académica (programa, facultad y sede) se edita desde **Editar**, excepto la facultad. Tarjeta de Bluetooth LE con "Próximamente" y un interruptor de preferencia. Interruptores **Sesiones de aula en vivo** (alerta dentro de la app) y **Alerta de riesgo presencial**. Cerrar sesión con confirmación.

## 4. Flujos

| Flujo | Pasos |
|---|---|
| F1 Registrar asistencia | El docente abre la sesión → la campana, el banner y la alerta avisan → Registrar → búsqueda en el servidor → Comprobante (o Fallo con la causa) |
| F2 Consultar | Mis Clases → Ver detalle (sesiones y estados) · Historial → periodos y PDF |
| F3 Reportar | Fallo o Detalle → Reportar incidencia → `incidents` |
| F4 Perfil | Editar programa, semestre y sede · alertas · BLE (preferencia) |
| F5 Cerrar sesión | Perfil → confirmar → Login |
