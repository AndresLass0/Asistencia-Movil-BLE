# Pantallas y flujos

> Actualizado el 2026-11-01: vistas del estudiante (`docs/images_views_estudiante/`) y del docente (`docs/images_views_docente/`).
> Esas carpetas de diseño son material de referencia local y no se versionan en el repositorio.
> Revisión visual: capturas renderizadas desde pruebas de widgets (Roboto en lugar de Plus Jakarta Sans). **No** se probó en un dispositivo con datos reales de Firestore.

## 1. Mapa

```
AuthGate ─┬─ sin sesión → Login ─┬─ push → Registro (/register)
          │                      └─ push → Recuperar (/forgot-password)
          └─ con sesión → EmailVerificationGate ── sin verificar → "Verifica tu correo"
                 │                          (Ya lo verifiqué · Reenviar · Cerrar sesión)
                 └─ verificado → RoleGate (lee users/{uid}.role)
                    ├─ estudiante (o sin perfil) → HomeScreen
                    │      ├─ [0] Inicio ──────────┐
                    │      ├─ [1] Mis Clases ──────┼─ push Detalle de asignatura
                    │      ├─ [2] Asistencia ◀─────┘
                    │      │      └─ push → Comprobante | Señal no encontrada
                    │      ├─ [3] Historial ── PDF
                    │      └─ [4] Perfil ── Cerrar sesión
                    └─ docente → TeacherGate (autorizado + correo verificado)
                           ├─ no autorizado / sin verificar → pantalla de aviso (reintentar, cerrar sesión)
                           └─ TeacherHomeScreen
                                  ├─ [0] Clases ── Iniciar asistencia → hoja de duración → push Sesión activa
                                  │        │                                   └─ Finalizar → Resumen (reemplaza)
                                  │        └─ Crear / Editar clase (push) · Eliminar
                                  ├─ [1] Historial ── detalle, PDF, Excel, revisar inasistencias (push Resumen)
                                  ├─ [2] Reportes ── periodo, consolidado PDF y Excel
                                  └─ [3] Perfil ── Cerrar sesión
```

Solo hay dos rutas con nombre (`/register`, `/forgot-password`). Todo lo demás se abre con `push` o cambiando de pestaña.

## 2. Autenticación (sin cambios en esta fase)

Login (correo `@udla.edu.co` o código), Registro (rol, código único, facultad obligatoria; envía el correo de verificación), Recuperar contraseña (doble factor "Próximamente"). **Verifica tu correo** (`EmailVerificationGate`): obligatoria para ambos roles antes de entrar. Ver `docs/MODELO_DE_DATOS.md` para `users` y `codes`.

## 3. Vistas del estudiante

Ya no existe modo demostración: las vistas solo muestran datos reales de Firestore (o estados vacíos). Las pruebas automáticas usan `FakeStudentBackend` (`test/fakes/`).

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

## 4. Vistas del docente

Todas usan datos de `TeacherBackend` (Firestore real o demostración) y muestran estados de carga, error y vacío. Diseño de referencia y decisiones: AUDITORIA §9.

### Acceso — `teacher/teacher_gate.dart`
Comprueba `teachers/{correo}` y el correo verificado. Avisos: "Cuenta docente pendiente de autorización" (Volver a comprobar) y "Verifica tu correo" (Reenviar correo, Ya lo verifiqué). Ambos con "Cerrar sesión".

### [0] Clases — `teacher/tabs/teacher_classes_tab.dart`
"Mis clases" + **Crear clase**; tarjeta del docente con el periodo. Tarjeta destacada: **sesión en curso** (presentes y hora de cierre, "Ver sesión en curso") o la clase en horario / próxima con **Iniciar asistencia**. Resumen del periodo (estudiantes, asistencia promedio, sesiones). "Mis asignaturas": grupo, aula, horario, %, inscritos (y cuántos sin cuenta), Iniciar asistencia / Ver sesión, Editar y Eliminar (bloqueados con la sesión activa; eliminar solo sin sesiones).
**Hoja "Configurar duración":** 5/10/15/20 min (preseleccionada la de la clase), hora de inicio y de cierre, aviso si nadie de la lista tiene cuenta.

### Crear / Editar clase — `teacher/course_form_screen.dart`
Nombre*, código, grupo, periodo* (AAAA-1/2), aula y edificio; franjas horarias (día + inicio y fin); **lista de estudiantes**: cargar .xlsx/.csv (código, nombre, correo; con o sin encabezados; informa filas omitidas), descargar plantilla .xlsx, añadir a mano, quitar; duración predeterminada del registro; faltas permitidas (opcional). Al guardar vincula los códigos con cuentas existentes e informa cuántos quedaron vinculados.

### Sesión activa — `teacher/active_session_screen.dart`
Estado (registro abierto / tiempo cumplido / finalizada), cuenta atrás, hora de inicio, aula, aviso de que no hay verificación por proximidad, progreso presentes/total. Lista con búsqueda: **Presentes** (hora; "Desde la app" o "Registro manual") y **Pendientes** ("Marcar presente" con confirmación, o "Sin cuenta en BioAsistencia"). **Finalizar asistencia** con confirmación → Resumen.

### Resumen de asistencia — `teacher/session_summary_screen.dart`
Estado, asignatura, fecha y horas, presentes (%), ausentes, total. **Ausentes** con Justificar / Confirmar falta (cambiable). Presentes plegables. Descargar planilla PDF, planilla Excel y "Consultar historial de clases" (pestaña 1).

### [1] Historial — `teacher/tabs/teacher_history_tab.dart`
Filtro por mes y por asignatura; sesiones, asistencia promedio y estudiantes; tarjeta por sesión (fecha, horas, duración, aula, presentes/ausentes) con planilla desplegable, PDF, Excel y "Revisar inasistencias".

### [2] Reportes — `teacher/tabs/teacher_reports_tab.dart`
Selector de periodo (o todos). Resumen (%, estudiantes, sesiones, en riesgo), barras de asistencia por mes, tarjeta por asignatura (%, presentes por sesión, en riesgo, estudiantes desplegables), **alerta temprana**, **incidencias reportadas** y exportación del consolidado (Excel y PDF).

### [3] Perfil — `teacher/tabs/teacher_profile_tab.dart`
Nombre, correo, rol, código, facultad y sede ("Sin registrar" si faltan); resumen del periodo; cursos a cargo; "Proximidad (Bluetooth) · Próximamente"; Cerrar sesión.

## 5. Flujos

| Flujo | Pasos |
|---|---|
| F1 Registrar asistencia | El docente abre la sesión → la campana, el banner y la alerta avisan → Registrar → búsqueda en el servidor → Comprobante (o Fallo con la causa) |
| F2 Consultar | Mis Clases → Ver detalle (sesiones y estados) · Historial → periodos y PDF |
| F3 Reportar | Fallo o Detalle → Reportar incidencia → `incidents` |
| F4 Perfil | Editar programa, semestre y sede · alertas · BLE (preferencia) |
| F5 Cerrar sesión | Perfil → confirmar → Login |
| F0 Alta de cuenta | Registro → correo de verificación → abrir enlace → "Ya lo verifiqué" → vista del rol |
| D1 Acceso docente | Administración crea `teachers/{correo}` → registro como Docente → verificar correo → TeacherGate → Clases |
| D2 Crear clase | Clases → Crear clase → datos, horario, lista (Excel/CSV o manual) → Guardar (vincula códigos) |
| D3 Tomar asistencia | Clases → Iniciar asistencia → duración → Sesión activa (presentes en vivo, excepciones) → Finalizar → Resumen → justificar o confirmar → PDF/Excel |
| D4 Consultar | Historial (por mes y asignatura) · Reportes (periodo, riesgo, incidencias, consolidado) |
