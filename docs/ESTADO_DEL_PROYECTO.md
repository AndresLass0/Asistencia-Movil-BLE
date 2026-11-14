# Estado del proyecto

> Actualizado el 2026-11-14: sin modo demostración, verificación de correo obligatoria y matrículas por correo (invitaciones, cancelación, un celular por estudiante y sesión). Documentos: [ARQUITECTURA](ARQUITECTURA.md) · [MODELO_DE_DATOS](MODELO_DE_DATOS.md) · [PANTALLAS_Y_FLUJOS](PANTALLAS_Y_FLUJOS.md) · [AUDITORIA_DE_CONSISTENCIA](AUDITORIA_DE_CONSISTENCIA.md) · [PLAN_DE_CORRECCIONES](PLAN_DE_CORRECCIONES.md)

## 1. Resumen

BioAsistencia (UDLA) tiene dos vistas conectadas a Firestore:
- **Estudiante:** Inicio, Mis Clases, detalle, registro de asistencia, comprobante, historial con PDF y perfil.
- **Docente:** clases (crear, editar, eliminar, cargar la lista desde Excel/CSV), sesión de asistencia con ventana de registro y presentes en vivo, resumen con revisión de inasistencias, historial, reportes y perfil, con exportación a PDF y Excel.

La asistencia se valida con la **sesión que abre el docente** y su ventana de registro, en el servidor y en las reglas. **La verificación por proximidad (BLE) no está implementada.**

## 2. Estado por funcionalidad

| Funcionalidad | Implementado | Probado automáticamente | Pendiente de validar |
|---|---|---|---|
| Login, registro, recuperación, cierre de sesión | ✅ | ✅ (sin Firebase) | En dispositivo |
| Vistas del estudiante | ✅ | ✅ | Con datos reales |
| Autorización de docentes (`teachers` + correo verificado) | ✅ app y reglas | ✅ pantallas de acceso | **Reglas en el servidor** |
| Crear / editar / eliminar clase | ✅ | ✅ (datos de prueba) | Escrituras reales |
| Importar lista .xlsx/.csv (reemplaza, con vista previa) y plantilla | ✅ | ✅ plan de importación, encabezados UDLA | Selector de archivos en el dispositivo |
| Importar `.xls` (Excel 97-2003, formato de la UDLA) | ❌ entrega 2 | — | — |
| Matrículas por correo (`enrollments`), invitaciones y cancelación | ✅ app y reglas | ✅ lógica y pantallas | **Reglas en el servidor** |
| Un celular registra a un solo estudiante por sesión | ✅ app, reglas y canal nativo | ✅ lógica; el APK compila | En dispositivos reales (Android); iOS sin compilar aquí |
| Avisos en la app (campana) | ✅ | ✅ | Con datos reales |
| Abrir sesión con duración, cierre automático, finalizar | ✅ | ✅ | Reglas en el servidor |
| Presentes en vivo, excepción manual | ✅ | ✅ | Con varios dispositivos |
| Justificar / confirmar inasistencias | ✅ | ✅ | Escrituras reales |
| Historial, reportes, riesgo, incidencias | ✅ | ✅ cálculos y pantallas | Con datos reales |
| PDF y Excel del docente | ✅ | ✅ generación del .xlsx | Diálogos nativos de guardar/compartir |
| Verificación de correo obligatoria (ambos roles) | ✅ app y reglas | ✅ pantalla de verificación | Recepción del correo en buzones `@udla.edu.co` |
| Modo demostración | Eliminado (2026-11-14); los datos de ejemplo solo existen en `test/fakes/` | — | — |
| **BLE (emisión y detección)** | ❌ | — | Requiere protocolo y hardware |
| Notificaciones push | ❌ | — | Decisión pendiente |

## 3. Lo que depende de algo externo

| Tema | Qué hacer |
|---|---|
| Firestore | Crear la base y **publicar `firestore.rules`** (no se publicó nada desde aquí: no hay CLI de Firebase) |
| Docentes | Crear `teachers/<correo>` con `active: true` en la consola por cada docente autorizado |
| Correo de verificación | Usa la plantilla por defecto de Firebase Auth (se puede personalizar en la consola) |
| Asignaturas | Las crea el docente en la app, con su lista. Los estudiantes las ven solos al registrarse con el correo de la lista |

## 4. Validaciones realizadas

| Validación | Resultado |
|---|---|
| `flutter analyze --no-pub` | **No issues found** |
| `flutter test --no-pub` | **117/117 superadas** (incluye matrículas, plan de importación, invitaciones, cancelación y faltas según la matrícula): lógica y cálculos de ambos roles, archivos .xlsx/.csv, acceso del docente (autorizado, no autorizado, sin verificar), recorrido del docente con datos de prueba, verificación de correo (finalizar sesión, excepción manual, justificar, iniciar con duración, crear clase, validaciones) y desbordamientos en 320 dp con texto al 130 % |
| `flutter build apk --debug` | **Compila** (incluye `file_picker` y el canal nativo de la huella del celular). iOS no se puede compilar aquí (no hay Mac) |
| Revisión visual | Capturas de las pantallas del docente con datos de ejemplo. Corregidos: desplegable de periodo desbordado, "1 faltas", botón partido en dos líneas y datos de ejemplo con riesgo exagerado |
| Búsqueda institucional | Sin "UN", "SIA", "UNAL", "Nacional", "Amazonía" ni "80 %" en `lib/` |

**No verificado:**
- Las reglas de Firestore en el servidor (sin emulador ni CLI). En particular: el registro de docentes, `isTeacher()` y las consultas del docente.
- Lecturas y escrituras reales, el envío del correo de verificación, las matrículas y el límite de lecturas de las reglas en lotes grandes (importar 35 o más estudiantes).
- La app en un dispositivo o emulador; los diálogos nativos (selector de archivos, guardar Excel, compartir PDF).
- Varios dispositivos a la vez (docente y estudiantes en la misma sesión).

## 5. Limitaciones conocidas

- **Sin BLE:** cualquier estudiante matriculado puede registrarse durante la ventana, aunque no esté en el aula. La pantalla de calibración BLE del diseño no se implementó.
- Un celular por estudiante y sesión reduce el "favor entre amigos", pero no lo impide si alguien presta su propio celular; la huella se puede falsificar con conocimientos técnicos.
- Desde web o escritorio no se puede registrar asistencia (no hay un identificador estable del dispositivo).
- Si la lista oficial cambia el correo de un estudiante, cuenta como otra persona (el correo es la identidad).
- `endsAt` se calcula con el reloj del teléfono del docente: si está muy atrasado respecto al servidor, las reglas rechazan la sesión.
- Las justificaciones no cambian los porcentajes (no hay una regla institucional confirmada).
- No hay notificaciones push: las alertas solo funcionan con la app abierta.

## 6. Dudas abiertas

1. Protocolo y hardware BLE (¿emite el teléfono del docente o una baliza en el aula?).
2. ¿Las faltas justificadas deben descontarse? ¿Hay un reglamento de faltas global?
3. ¿Quién administra la lista de docentes autorizados y cómo se solicita?
4. ¿Hacen falta notificaciones push (FCM)?
5. Pendientes anteriores: facultades, reglamento, política de datos, logo, firma de release.

## 7. Próximos pasos

1. Publicar las reglas, autorizar un docente de prueba y recorrer D1–D3 y F1 en dos dispositivos.
2. Definir el protocolo BLE e implementarlo.
3. Firma de release e identificadores definitivos.
