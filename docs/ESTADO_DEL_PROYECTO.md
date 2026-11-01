# Estado del proyecto

> Actualizado el 2026-11-01, tras implementar las vistas del estudiante. Documentos: [ARQUITECTURA](ARQUITECTURA.md) · [MODELO_DE_DATOS](MODELO_DE_DATOS.md) · [PANTALLAS_Y_FLUJOS](PANTALLAS_Y_FLUJOS.md) · [AUDITORIA_DE_CONSISTENCIA](AUDITORIA_DE_CONSISTENCIA.md) · [PLAN_DE_CORRECCIONES](PLAN_DE_CORRECCIONES.md)

## 1. Resumen

BioAsistencia (UDLA) ya tiene una **experiencia de estudiante completa conectada a Firestore**: Inicio, Mis Clases, detalle de asignatura, registro de asistencia, comprobante, historial con PDF y perfil. La asistencia se valida con la **sesión abierta por el docente**, en el servidor y en las reglas. Ya no queda ningún dato simulado (`DemoData` y la simulación de 4 s se eliminaron).

## 2. Qué funciona

- Autenticación con correo UDLA o código; registro con perfil y código único; recuperación; cierre de sesión.
- Lectura en vivo de asignaturas, sesiones y asistencias del estudiante.
- Registro de asistencia sin duplicados, con hora del servidor.
- Estadísticas por asignatura, periodo e histórico.
- Alertas dentro de la app (sesión abierta, riesgo por margen), campana e indicador de conexión.
- Reporte de incidencias, PDF del historial y edición de programa, semestre, sede y preferencias.
- Modo demostración del estudiante (solo depuración) con datos de ejemplo en memoria, para revisar las vistas sin Firestore.

## 3. Lo que depende de algo externo o falta

| Tema | Estado |
|---|---|
| Configuración de Firestore | **Hay que crear la base y publicar `firestore.rules`** (no hay CLI de Firebase en este equipo y no se publicó nada) |
| Asignaturas y sesiones | La app no las crea: se cargan desde la consola (guía en MODELO_DE_DATOS) o desde una futura **vista docente** |
| Verificación de proximidad (BLE) | No implementada: cualquier matriculado puede registrarse con la sesión abierta |
| Notificaciones push | No: las alertas solo funcionan con la app abierta |
| Vista docente | No existe |
| Verificación de correo, firma de release, identificadores, logo oficial | Pendientes (ver PLAN) |

## 4. Validaciones

| Validación | Resultado |
|---|---|
| `flutter analyze --no-pub` | **No issues found** |
| `flutter test --no-pub` | **65/65 superadas** (incluye el modo demostración): lógica, cálculos académicos, PDF, autenticación, 5 pestañas, detalle, comprobante, fallo y desbordamientos en 320 dp con texto al 130 %; sin toques fallidos |
| `flutter build apk --debug` | **Compila** (`app-debug.apk`). El primer intento falló sin que se capturara la causa; los dos siguientes terminaron bien |
| Revisión visual | Capturas de las 8 pantallas con datos de ejemplo, comparadas con los diseños. Corregidos: título cortado en la cabecera, títulos de sección partidos, "Salón Aula", chip de sesión recortado y tarjeta de Bluetooth apretada. Segunda revisión: textos que sugerían BLE activo (DIS-18) |
| Búsqueda institucional | Sin "UN", "SIA", "UNAL", "Nacional", "Amazonía" ni "80 %" en `lib/` |

**No verificado:**
- Las reglas de Firestore en el servidor (sin emulador ni CLI).
- Lecturas y escrituras reales contra Firebase.
- La app en un dispositivo o emulador con una cuenta real.
- El diálogo nativo de `printing`.
- La fuente Plus Jakarta Sans en las capturas.

## 5. Dudas abiertas

1. ¿Quién abre y cierra las sesiones (vista docente en la app o un sistema externo)?
2. ¿Cómo será la verificación de proximidad (protocolo BLE, hardware del docente)?
3. ¿Hay reglas institucionales de faltas (para no depender de `maxAbsences` por asignatura)?
4. ¿Hay una fuente oficial de programa, semestre y sede (hoy los registra el usuario)?
5. ¿Hacen falta notificaciones push (FCM)?
6. Pendientes anteriores: facultades, reglamento, política de datos, logo, verificación de correo y git.

## 6. Próximos pasos

1. Publicar las reglas, cargar datos de prueba y recorrer F1–F5 en un dispositivo.
2. Definir y construir la vista docente (abrir y cerrar sesiones).
3. Implementar la verificación BLE cuando haya un protocolo definido.
