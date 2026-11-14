# Estado del proyecto

> Actualizado el 2026-11-14: sin modo demostración y con verificación de correo obligatoria. Documentos: [ARQUITECTURA](ARQUITECTURA.md) · [MODELO_DE_DATOS](MODELO_DE_DATOS.md) · [PANTALLAS_Y_FLUJOS](PANTALLAS_Y_FLUJOS.md) · [AUDITORIA_DE_CONSISTENCIA](AUDITORIA_DE_CONSISTENCIA.md) · [PLAN_DE_CORRECCIONES](PLAN_DE_CORRECCIONES.md)

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
| Importar lista .xlsx/.csv y plantilla | ✅ | ✅ lectura/escritura de archivos | Selector de archivos en el dispositivo |
| Vincular códigos con cuentas | ✅ | ✅ (datos de prueba) | Con cuentas reales |
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
| Asignaturas | Las crea el docente en la app. Las cargadas a mano antes siguen funcionando para el estudiante, pero ningún docente las ve (no tienen `teacherUid`) |

## 4. Validaciones realizadas

| Validación | Resultado |
|---|---|
| `flutter analyze --no-pub` | **No issues found** |
| `flutter test --no-pub` | **101/101 superadas**: lógica y cálculos de ambos roles, archivos .xlsx/.csv, acceso del docente (autorizado, no autorizado, sin verificar), recorrido del docente con datos de prueba, verificación de correo (finalizar sesión, excepción manual, justificar, iniciar con duración, crear clase, validaciones) y desbordamientos en 320 dp con texto al 130 % |
| `flutter build apk --debug` | **Compila** (incluye `file_picker`) |
| Revisión visual | Capturas de las pantallas del docente con datos de ejemplo. Corregidos: desplegable de periodo desbordado, "1 faltas", botón partido en dos líneas y datos de ejemplo con riesgo exagerado |
| Búsqueda institucional | Sin "UN", "SIA", "UNAL", "Nacional", "Amazonía" ni "80 %" en `lib/` |

**No verificado:**
- Las reglas de Firestore en el servidor (sin emulador ni CLI). En particular: el registro de docentes, `isTeacher()` y las consultas del docente.
- Lecturas y escrituras reales, el envío del correo de verificación y la vinculación de códigos con cuentas reales.
- La app en un dispositivo o emulador; los diálogos nativos (selector de archivos, guardar Excel, compartir PDF).
- Varios dispositivos a la vez (docente y estudiantes en la misma sesión).

## 5. Limitaciones conocidas

- **Sin BLE:** cualquier estudiante matriculado puede registrarse durante la ventana, aunque no esté en el aula. La pantalla de calibración BLE del diseño no se implementó.
- Los estudiantes sin cuenta en BioAsistencia no pueden registrarse ni recibir una asistencia manual. El docente debe volver a guardar la clase cuando se registren.
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
