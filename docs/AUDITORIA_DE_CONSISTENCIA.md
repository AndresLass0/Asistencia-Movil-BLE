# Auditoría de consistencia

> Fecha de la auditoría original: 2026-11-01 (estado actualizado en §0). Alcance: todo `lib/`, `test/`, configuración y plataformas.
> Basada en lectura de código. **No se ejecutó la app en un dispositivo**, así que los hallazgos visuales (desbordes, alineaciones) son riesgos inferidos del código y deben confirmarse en un emulador.
>
> **Severidad:** 🔴 Alta (engaña al usuario, rompe un flujo o afecta a la identidad/seguridad) · 🟠 Media (incoherencia notable o deuda que bloquea evolución) · 🟢 Baja (pulido).
> **Confirmar** = requiere decisión del equipo/institución antes de cambiarse.

## 0. Estado tras la fase de correcciones (2026-11-01)

> Las secciones 1–7 son el **registro original** de la auditoría; sus números de línea corresponden al código **anterior** a las correcciones. Esta tabla indica el estado actual de cada hallazgo.
> ✅ Corregido y verificado (análisis + pruebas y/o captura) · 🟡 Parcial · ⏳ Pendiente (motivo indicado).

| ID | Estado | Detalle |
|---|---|---|
| INST-01 | ✅ | "Universidad de la Amazonia" en el pie del comprobante; prueba automática verifica que no aparece "Universidad Nacional". |
| INST-02 | ✅ | Nombre unificado "BioAsistencia" (título de la app, login, comentario). |
| INST-03 | ✅ | Eliminadas todas las menciones a "SIA" (no existe integración). Si se integra el sistema académico de la UDLA, usar su nombre real. |
| INST-04 | ✅ | "Universidad de la Amazonia" sin tilde en todos los textos. |
| INST-05 | ✅ | "UDLA" en mayúsculas. |
| INST-06 | ⏳ | Datos de demo ("Sede Central", "Edificio 401"…) sin cambios: no hay datos reales de la UDLA y no se deben inventar. |
| INST-07 | 🟡 | Campo renombrado a "Facultad" (sin "sede"). La lista de 7 facultades sigue **sin validar** con la institución. |
| INST-08 | ⏳ | "Estatuto Estudiantil" sigue mostrándose también a docentes; requiere confirmar el reglamento aplicable. |
| INST-09 | 🟡 | Nombre visible "BioAsistencia" en Android, iOS, web y pubspec; README reescrito. Ícono e identificadores (`com.example…`) pendientes. |
| INST-10 | — | Dominio `@udla.edu.co` coherente; ahora centralizado en `core/validators.dart`. |
| FUN-01 | ✅ | Accesos demo eliminados (2026-11-14). |
| FUN-02 | 🟡 | El rol se guarda en Firestore; subtítulo "Portal Docente" y chip de rol en Perfil. **No existe aún una vista docente** (requiere reglas de negocio). |
| FUN-03 | ✅ | Campo "doble factor" deshabilitado con chip "Próximamente" (decisión del equipo). |
| FUN-04 | ✅ | Cada éxito registra la asistencia (en memoria) y el Historial la muestra; textos aclaran que es local. |
| FUN-05 | ✅ | Código, facultad y preferencia BLE se guardan en `users/{uid}`. |
| FUN-06 | ⏳ | Falta la URL oficial de la política de datos. |
| FUN-07 | ✅ | "Inicia sesión" usa `maybePop`. |
| FUN-08 | ✅ | `AuthGate` es el único conmutador; `/home` y `/login` ya no son rutas. |
| FUN-09 | ✅ | Validadores compartidos; login/recuperación exigen `@udla.edu.co` (decisión del equipo), login acepta además código. |
| FUN-10 | 🟡 | Quitado el ícono QR decorativo. Campana, avatar de cabecera y flecha de "Siguiente clase" siguen sin acción. |
| FUN-11 | ⏳ | "Reportar incidencia" sigue siendo demo. |
| FUN-12 | ✅ | Diálogo de confirmación al cerrar sesión (estilo del botón sin cambios). |
| FUN-13 | ✅ | Se mantienen los 3 accesos (justificados como atajos) con mismo ícono y texto. |
| VIS-01 | 🟡 | Login usa `BrandLogo` (ya no "img"). Falta logo oficial e ícono del lanzador. |
| VIS-02 | ✅ | Barras secundarias con el mismo estilo (flecha + título a la izquierda). |
| VIS-03 | ✅ | `AppTopBar(showAvatar: false)` en Registro y Recuperar. |
| VIS-04 | ✅ | "Recuperar contraseña", "Registro de usuario", "Crear cuenta institucional", "Registrar asistencia", etc. |
| VIS-05 | ✅ | Registrar asistencia = ícono de señal (`sensors`) en todos los accesos; Historial = calendario en todos. |
| VIS-06 | 🟡 | Añadido `AppColors.chipStrong`; `AppLink` y `showAppMessage` compartidos. Resto de colores y estilos en línea sin centralizar. |
| VIS-07 | ✅ | Orbe de fallo con ícono `bluetooth_disabled` (verificado en captura). |
| VIS-08 | ✅ | El login ya no pinta los *hints* como valores. |
| VIS-09 | 🟡 | Corregidas 6 filas con riesgo; prueba automática sin desbordamientos en 320 dp con texto al 130 % (Login, Registro, Recuperar, Inicio, Éxito, Fallo). No probado al 200 % ni en dispositivo. |
| VIS-10 | ✅ | Eliminadas las marcas parciales ("*", "Requerido", "Oficial SIA"); todos los campos son obligatorios. |
| VIS-11 | ✅ | "Comprobante de asistencia" / "Registro de asistencia". |
| VIS-12 (nuevo) | ✅ | Detectado en la revisión visual: el botón central de la barra inferior estaba centrado en la pantalla y no sobre su etiqueta "Asistencia". Corregido (`app_bottom_nav.dart`). |
| VIS-13 (nuevo) | ✅ | El chip de estado quedaba pegado al horario en las tarjetas de clase; añadido espaciado. |
| INF-01 | ✅ | Eliminado "detectará automáticamente tu perfil". |
| INF-02 | 🟡 | Nombre unificado; los eslóganes ("Sistema de Presencia Inteligente", "Portal Oficial de Autenticación Académica") se mantienen. |
| INF-03 | ✅ | Eliminadas promesas de biometría, verificación de matrícula, firma criptográfica y sincronización. |
| INF-04 | ✅ | Código de comprobante derivado de la hora real; sin "SHA", "OFICIAL" ni "A tiempo". |
| INF-05 | ✅ | "Toca para buscar la señal" y chip "En curso". (La clase demo sigue siendo 6–8 PM fija.) |
| INF-06 | ✅ | Texto neutro "Has asistido a X de Y clases"; sin regla del 80 % (no confirmada). |
| INF-07 | 🟡 | "profesor" → "docente" en todos los textos. Se conservan términos de marca ("resonancia", "sintonía"). |
| INF-08 | ✅ | Ubicación siempre con `ClassSession.location`. |
| INF-09 | ⏳ | Significado de "Presente (93%)" sin aclarar. |
| INF-10 | 🟡 | "N asignaturas" calculado; "Mañana" sigue fijo (demo sin fechas). |
| INF-11 | ✅ | "Facultad" en etiqueta, *hint* y mensaje. |
| INF-12 | ✅ | "Repite tu contraseña". |
| INF-13 | ⏳ | El mensaje genérico de credenciales podría verse en Recuperar en un caso raro. |
| TEC-01 | ✅ | 31 pruebas (`test/logic_test.dart`, `test/screens_test.dart`) en verde. |
| TEC-02 | ✅ | Eliminados `lib/src/my_app.dart` y la lista comentada de `main.dart`. |
| TEC-03 | 🟡 | Firestore encapsulado en `UserProfileService`; Auth sigue directo en las pantallas. |
| TEC-04 | 🟡 | `AttendanceService.resetForTesting()`; sigue siendo estático. |
| TEC-05 | ✅ | `StartupErrorApp` si Firebase no inicia. |
| TEC-06 | ✅ | `flutter analyze`: sin problemas. |
| TEC-07 | 🟡 | `showAppMessage` compartido; ilustraciones de círculos aún duplicadas. |
| TEC-08 | ⏳ | Aceptable; sin cambios. |
| TEC-09 | ✅ | Inicio y Perfil reciben los datos por parámetro. `UserAvatar` sigue leyendo `currentUser`. |
| TEC-10 | ⏳ | Fuente descargada en tiempo de ejecución; `cupertino_icons` sin usar (no se tocan dependencias sin motivo). |
| TEC-11 | ✅ | Eliminado el parámetro sin uso. |
| TEC-12 | ⏳ | Sin BLE real ni permisos. |
| SEG-01 | 🟡 | Las reglas exigen correo `@udla.edu.co` para crear perfiles y códigos, y **correo verificado** (ambos roles, 2026-11-14) para leer asignaturas y sesiones, registrar asistencia e incidencias. Firebase Auth sigue permitiendo crear cuentas de cualquier dominio por API (no pueden operar sin verificar un buzón `@udla.edu.co`). |
| SEG-02 | ⏳ | Firma de release e identificadores (requiere re-registro en Firebase). |
| SEG-03 | ⏳ | Sin cambios en claves (no autorizado). |
| SEG-04 | ⏳ | El proyecto sigue sin git (no se inicializó sin autorización). Copia de seguridad previa a los cambios hecha fuera del proyecto. |
| SEG-05 (nuevo) | ⚠️ Aceptado | `codes/{código}` es legible sin sesión (necesario para entrar con el código): quien conozca un código válido puede ver el correo asociado. Riesgo aceptado al elegir Firestore; la alternativa segura es una Cloud Function. |
| A11Y-01 | ✅ | Enlaces con `AppLink` (semántica de botón, área táctil ampliada); selector de rol con `Semantics`. |
| A11Y-02 | ✅ | Botón central con `Semantics(label: 'Asistencia', button: true)`. |
| A11Y-03 | 🟡 | Probado al 130 %; alturas fijas de la barra inferior sin cambios. |
| A11Y-04 | ✅ | "Seguridad: baja / media / alta". |

---

Índice: [INST](#1-identidad-institucional) · [FUN](#2-consistencia-funcional) · [VIS](#3-consistencia-visual) · [INF](#4-consistencia-de-información) · [TEC](#5-revisión-técnica) · [SEG](#6-seguridad) · [A11Y](#7-accesibilidad-y-usabilidad)

---

## 1. Identidad institucional

Búsqueda realizada (sin distinguir mayúsculas) por `unal`, `nacional`, `UN` como palabra, `universidad`, `udla`, `amazon`, `SIA` en todo el repositorio excepto `build/`, `.dart_tool/` y `pubspec.lock`, más revisión manual de nombres de plataforma. **No** aparecen "UNAL", "unal.edu.co" ni "Universidad Nacional de Colombia" literalmente; sí las siguientes referencias.

| ID | Sev. | Ubicación | Tipo | Evidencia | Recomendación |
|---|---|---|---|---|---|
| INST-01 | 🔴 | `lib/screens/attendance/attendance_success_screen.dart:84` | Visible | `'Campus Sostenible • Universidad Nacional'` en el pie de la pantalla de éxito. | Corregir: es una referencia a otra universidad. Reemplazar por "Universidad de la Amazonia" (o eliminar el pie). Sin ambigüedad. |
| INST-02 | 🔴 Confirmar | `lib/main.dart:24` (`MaterialApp.title`, visible en el selector de apps de Android y en la pestaña del navegador), `lib/screens/login_screen.dart:167` (título del login), `lib/core/app_colors.dart:3` (comentario) | Visible + comentario | `'BioAsistencia UN'`. "UN" es la abreviatura habitual de la Universidad Nacional de Colombia. En el resto de la app el nombre es solo "BioAsistencia" (`home_header.dart:46`, `register_screen.dart:257`). | Definir el nombre oficial del producto (¿"BioAsistencia", "BioAsistencia UDLA"…?) y aplicarlo en los 3 sitios. |
| INST-03 | 🟠 Confirmar | `lib/screens/forgot_password_screen.dart:134-135` ("Sistema de Información Académica (SIA)"), `lib/screens/register_screen.dart:144` ("Oficial SIA"), `lib/screens/attendance/attendance_success_screen.dart:143` ("OFICIAL SIA") y `:426` ("sistema académico SIA") | Visible | "SIA" es el nombre del sistema académico de la UNAL. No se pudo verificar desde el repositorio cómo se llama el sistema académico de la UDLA. Además ninguna integración con "SIA" existe (ver INF-03). | Confirmar el nombre del sistema de la UDLA; mientras no exista integración, retirar las menciones o sustituirlas por texto neutro. |
| INST-04 | 🟢 Confirmar | `lib/screens/login_screen.dart:392`, `lib/screens/register_screen.dart:574-575` | Visible | Se escribe "Universidad de la Amazon**í**a" (con tilde). El nombre institucional que usa el propio encargo es "Universidad de la Amazonia". | Confirmar la grafía oficial y unificar. |
| INST-05 | 🟢 | `lib/screens/register_screen.dart:302` vs `lib/screens/forgot_password_screen.dart:235` | Visible | "CREDENCIALES INSTITUCIONALES **udla**" (minúsculas) frente a "IDENTIDAD CENTRAL **UDLA**". | Unificar a "UDLA". |
| INST-06 | 🟠 Confirmar | `lib/data/demo_data.dart:7,13-14,22-23,34-35` | Datos de prueba | "Sede Central", "Edificio 401/210/300", "Aula 302", "Laboratorio 104". La numeración de edificios de tres cifras (p. ej. "Edificio 401") corresponde al estilo del campus de la UNAL en Bogotá; no hay evidencia de que exista en la UDLA. Los nombres de docentes son ficticios. | Sustituir por sedes/bloques reales de la UDLA o por nombres claramente genéricos. Confirmar el nombre de la sede (se muestra en la cabecera de todas las pestañas: `home_header.dart:61-66`). |
| INST-07 | 🟠 Confirmar | `lib/screens/register_screen.dart:19-27` (y copia comentada en `lib/main.dart:34-42`) | Visible | Lista de 7 facultades. No se pudo verificar contra una fuente oficial desde el repositorio. La etiqueta dice "Facultad y **Sede** Académica" pero no hay sedes. | Validar la lista con la UDLA y decidir si se pide la sede. |
| INST-08 | 🟢 Confirmar | `lib/screens/register_screen.dart:572-575` | Visible | "…Ley 1581 de 2012 y el **Estatuto Estudiantil** de la Universidad de la Amazonía." Se muestra igual cuando el rol elegido es **Docente**. La Ley 1581 de 2012 (protección de datos en Colombia) es correcta. | Confirmar el nombre del reglamento aplicable y si debe variar por rol; enlazar la política de datos de la UDLA. |
| INST-09 | 🟠 Confirmar | `android/app/src/main/AndroidManifest.xml:3` (`proyecto_asistencia`), `ios/Runner/Info.plist` (`Proyecto Asistencia`), `web/index.html:21,32`, `web/manifest.json:2-8`, `pubspec.yaml:2`, `README.md`, ícono de lanzador de Flutter por defecto, `applicationId` `com.example.proyecto_asistencia` | Configuración técnica | No hay referencias a otra universidad, pero tampoco identidad UDLA: el nombre bajo el ícono del teléfono es "proyecto_asistencia" y el ícono es el logo de Flutter. | Definir nombre visible, ícono e identificador de paquete. **Cambiar el `applicationId`/bundle id obliga a volver a registrar la app en Firebase**: no tocar sin plan. |
| INST-10 | — | Dominio `@udla.edu.co` en `login_screen.dart:195,246,254`, `register_screen.dart:67-68,154,167`, `forgot_password_screen.dart:82,105` | Visible + validación | Uso coherente en toda la app. | Solo confirmar que estudiantes **y** docentes usan ese dominio. |

---

## 2. Consistencia funcional

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| FUN-01 | 🟠 | `login_screen.dart:36-38, 280-294` | Los botones "Demostración: Entrar como Docente/Estudiante" solo muestran un SnackBar; la etiqueta promete entrar. | Decidir: implementarlos (p. ej. cuentas demo) u ocultarlos fuera de modo debug. |
| FUN-02 | 🔴 | `register_screen.dart:29, 136-139`; `home_screen.dart:21`; `dashboard_tab.dart:20` | El selector **Estudiante/Docente** cambia `_isStudent` pero el valor nunca se guarda ni se usa. No existe ninguna vista de docente: cualquier usuario ve "Portal Estudiantil", "Hola, Estudiante" (fallback) y el flujo de marcar asistencia. | Definir el modelo de roles (dónde se guarda: Firestore, *custom claims*…) y qué ve cada rol. Requiere decisión (ver dudas). |
| FUN-03 | 🟠 | `forgot_password_screen.dart:112-136` | Campo "Documento de identidad o Código Estudiante — Doble factor" sin `controller`: no se lee, no se valida, no se envía. Además, "Código Estudiante" excluye a docentes. | Eliminarlo o implementarlo; si se mantiene, ajustar texto para ambos roles. |
| FUN-04 | 🔴 | `attendance_success_screen.dart:44-59, 72-77`; `history_tab.dart` | "¡Asistencia registrada!" sin registrar nada; "Ver en mi historial" lleva a un placeholder vacío que dice "Aquí verás todas tus asistencias registradas". El flujo principal de la app termina en una contradicción. | Mientras no exista persistencia, indicar claramente que es una demo o mostrar un estado vacío honesto en Historial. A medio plazo: persistir asistencias. |
| FUN-05 | 🟠 | `register_screen.dart:30-32, 38, 93-98` | Documento, facultad y preferencia BLE se validan como obligatorios y luego se descartan (solo se envían correo, contraseña y nombre). | Persistir o dejar de pedirlos. Hoy se exige información personal sin usarla (relevante bajo la Ley 1581). |
| FUN-06 | 🟢 | `register_screen.dart:565-571` | "Tratamiento de Datos Personales" tiene estilo de enlace (verde, subrayado) pero no es pulsable. Se pide aceptar una política que no se puede leer. | Añadir enlace o diálogo con la política. |
| FUN-07 | 🟠 | `register_screen.dart:232-233` | "Inicia sesión" usa `pushReplacementNamed('/login')`. Como se llegó desde el Login que vive dentro de `AuthGate`, la pila queda `[AuthGate(Login), Login]`: al pulsar atrás aparece **otro Login idéntico**. La flecha atrás de la misma pantalla sí hace `maybePop` correctamente. | Usar `Navigator.pop` (volver al Login existente). |
| FUN-08 | 🟠 | `login_screen.dart:60`, `register_screen.dart:101`, `profile_tab.dart:17`, `app_routes.dart:15,21` | Tras login/registro/logout se navega con `pushNamedAndRemoveUntil`, lo que **elimina `AuthGate`** de la pila: si la sesión expira o se revoca, la app no reacciona. Responsabilidad duplicada (AuthGate + navegación manual). `/home` es accesible sin sesión. | Elegir un único mecanismo: dejar que `AuthGate` conmute (sin navegar manualmente) o proteger rutas. |
| FUN-09 | 🟠 | `login_screen.dart:46-48`, `forgot_password_screen.dart:38-41`, `register_screen.dart:67-69` | Validación de correo desigual: registro exige `@udla.edu.co`; login y recuperación solo comprueban que haya `@`, aunque sus textos dicen "correo institucional". | Compartir un validador único. |
| FUN-10 | 🟢 | `home_header.dart:68-84` (campana con punto), `:84` y `app_top_bar.dart:71` (avatar), `dashboard_tab.dart:542-548` (flecha de "Siguiente clase"), `attendance_success_screen.dart:189` (ícono QR) | Elementos con apariencia interactiva sin acción. El punto verde de la campana sugiere notificaciones pendientes que no existen. | Darles acción o retirar la apariencia de botón. |
| FUN-11 | 🟢 | `attendance_failed_screen.dart:78-94` | "Reportar incidencia al docente" → SnackBar "(demo)". | Implementar o marcar como próximamente. |
| FUN-12 | 🟢 | `profile_tab.dart:48-53` | "Cerrar sesión" sin confirmación y con el mismo estilo que la acción principal positiva (`PrimaryButton` verde). | Confirmación y estilo secundario/destructivo. |
| FUN-13 | 🟢 | `dashboard_tab.dart:38, 167-168`; `app_bottom_nav.dart:88-114` | Tres accesos a la misma acción "registrar asistencia" en Inicio + barra (hero, tarjeta de clase y botón central). **Justificable** como atajos, pero con íconos y textos distintos (ver VIS-05). | Mantener si se desea, pero unificar ícono y texto. |

---

## 3. Consistencia visual

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| VIS-01 | 🔴 | `login_screen.dart:127-165` vs `widgets/brand_logo.dart` (usado en `home_header.dart:39`) | La marca no coincide: el login muestra un recuadro gris con el texto **"img"** y un punto rojo (placeholder); dentro de la app el logo es una huella verde. El ícono del lanzador es el de Flutter. | Definir el logo oficial (¿uso del escudo UDLA?) y usar `BrandLogo` (o un asset) en ambos lugares. |
| VIS-02 | 🟠 | `forgot_password_screen.dart:60-64` vs `register_screen.dart:124` vs `attendance_*_screen.dart:22/25` | Barras superiores equivalentes con configuración distinta: Recuperar usa "← Volver" + título centrado; Registro y resultados, solo flecha + título a la izquierda. Recuperar tiene además un segundo botón "Volver a iniciar sesión" (`:145-157`), Registro no. | Un estilo único para pantallas secundarias. |
| VIS-03 | 🟠 | `widgets/app_top_bar.dart:71` | `AppTopBar` siempre pinta `UserAvatar`; en Registro y Recuperar no hay sesión y aparece un círculo verde con "U". | Parámetro para ocultar el avatar (o no mostrarlo sin usuario). |
| VIS-04 | 🟠 | `forgot_password_screen.dart:61` ("**Password Recovery**", en inglés), `register_screen.dart:124` ("Registro **De** Usuario"), `:219` ("Crear Cuenta Institucional"), `dashboard_tab.dart:260` ("Registrar\nAsistencia") vs `:93` y `attendance_tab.dart:80` ("Registrar asistencia"), `login_screen.dart:275` ("Iniciar sesión") | Idioma y mayúsculas incoherentes (mezcla de *Title Case* y frase normal). | Español y mayúscula inicial solo en la primera palabra, en todos los títulos y botones. |
| VIS-05 | 🟠 | Registrar asistencia: `dashboard_tab.dart:94` (`record_voice_over_outlined`), `:259` (`how_to_reg_outlined`), `app_bottom_nav.dart:110` (`sensors`). Historial: `app_bottom_nav.dart:74` y `history_tab.dart:17` (`calendar_month_outlined`) vs `attendance_success_screen.dart:74` (`history_edu_outlined`). `record_voice_over_outlined` se reutiliza para "Confirmación docente" (`attendance_failed_screen.dart:141`) | La misma acción usa íconos distintos y un mismo ícono significa cosas distintas. | Tabla de íconos por concepto. |
| VIS-06 | 🟢 | Colores fuera de `AppColors`: `login_screen.dart:145,148`, `register_screen.dart:284`, `dashboard_tab.dart:66,228,315`, `attendance_success_screen.dart:124,237`. Decoraciones de tarjeta copiadas a mano en `login_screen.dart:228-239`, `register_screen.dart:276-286, 406-417, 489-500`, `attendance_success_screen.dart:103-115` en vez de `AppCard`. `AppTheme.textTheme` prácticamente no se usa (todos los `TextStyle` son en línea). | Cada pantalla parece maquetada por separado aunque comparten paleta. | Centralizar colores y estilos de texto; reutilizar `AppCard`/`AppTextField`. |
| VIS-07 | 🟠 | `attendance_failed_screen.dart:27-39` | El orbe de error tiene `centerColor: Colors.white` y **ningún `center`**: el círculo central queda blanco y vacío (el éxito sí muestra un check). | Añadir ícono central (p. ej. `bluetooth_disabled`). |
| VIS-08 | 🟠 | `login_screen.dart:247, 260` + `app_text_field.dart:100-102` | `hintIsValue: true` pinta los *hints* ("usuario@udla.edu.co", "•••••••••••") con el color del texto real: los campos parecen ya rellenados. Registro y Recuperar no lo hacen. | Quitar `hintIsValue` en el login. |
| VIS-09 | 🟠 | `register_screen.dart:160-171` (fila de dos `Text` sin `Flexible`), `attendance_success_screen.dart:79-87` (fila sin `Flexible`), `attendance_tab.dart:176-184` (ubicación sin `Flexible`), `app_bottom_nav.dart:21,29` (alturas fijas 88/66), `app_top_bar.dart:63-68` (título sin `maxLines`) | Riesgo de desbordamiento (franjas amarillas/negras) en pantallas estrechas (~320 dp) o con texto ampliado. **No verificado en dispositivo.** | Probar con `textScaler` 1.3–2.0 y anchos pequeños; añadir `Flexible`/`maxLines`. |
| VIS-10 | 🟢 | `login_screen.dart:250-251` (asterisco rojo solo en el correo), `register_screen.dart:144,152-153,176` ("Oficial SIA", "Requerido" en verde, "Numérico") | El hueco derecho de la etiqueta se usa para cosas distintas (obligatoriedad, origen del dato, formato) y la obligatoriedad se marca distinto en cada pantalla; en Registro todos los campos son obligatorios pero solo uno dice "Requerido". | Convención única para campos obligatorios. |
| VIS-11 | 🟢 | `attendance_failed_screen.dart:22`, `attendance_success_screen.dart:25` | Ambas pantallas se titulan "Detalle de asistencia", también cuando no hubo asistencia. | Títulos según resultado. |

---

## 4. Consistencia de información

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| INF-01 | 🔴 | `login_screen.dart:195-196` vs `home_screen.dart:21`, `dashboard_tab.dart:20`, `profile_tab.dart` | El login promete "El sistema detectará automáticamente tu perfil"; no hay detección y todo usuario ve el portal de estudiante. | Retirar la frase hasta que existan roles (FUN-02). |
| INF-02 | 🟠 | `main.dart:24`, `login_screen.dart:167,171,379`, `home_header.dart:46`, `home_screen.dart:21`, `register_screen.dart:257` | El producto se llama de muchas formas: "BioAsistencia UN", "BioAsistencia", "Sistema de Presencia Inteligente", "Portal Oficial de Autenticación Académica", "Portal Estudiantil", "BioAsistencia • Conexión Cifrada". | Definir nombre y eslogan. |
| INF-03 | 🔴 | `forgot_password_screen.dart:83-84` ("código biométrico de acceso"), `:122` ("Doble factor"), `:134-135` ("Verificaremos tu matrícula en el SIA"), `register_screen.dart:144` ("Oficial SIA"), `attendance_success_screen.dart:199-205` ("Firma criptográfica", "SHA"), `:423-426` ("sincronizado con el sistema académico SIA"), nombre "Bio"Asistencia + ícono de huella | Se prometen capacidades que no existen (biometría, 2FA, verificación de matrícula, firma criptográfica, sincronización con el sistema académico). | Retirar o reformular hasta implementarlas. |
| INF-04 | 🔴 | `attendance_success_screen.dart:137` ("#AS-9824"), `:171` ("A tiempo"), `:203` ("SHA: 9B2E · 4A8F") | Valores de comprobante **fijos**: todos los "comprobantes" tienen el mismo número y firma, y siempre "A tiempo" aunque la hora real no coincida con la clase. Se presentan como oficiales ("OFICIAL SIA"). | Generarlos de datos reales o etiquetar como demo. |
| INF-05 | 🟠 | `dashboard_tab.dart:226, 244` vs `attendance_tab.dart` / `attendance_service.dart:18` | Inicio afirma "En curso • BLE abierta" y "Beacon en rango detectado" **antes** de escanear; después el escaneo puede fallar ("No encontramos la señal"). La clase "en curso" es siempre 6–8 PM aunque se abra la app por la mañana, junto a la fecha real. | Derivar el estado de datos reales o usar texto neutral ("Toca para buscar la señal"). |
| INF-06 | 🟠 | `dashboard_tab.dart:383-391` | "Excelente constancia" y "Cumples con el requisito mínimo institucional (80%) para validar todos los créditos" son fijos, independientes del porcentaje. La regla del 80 % no está respaldada en el repositorio. | Confirmar la regla y calcular el mensaje a partir del porcentaje. |
| INF-07 | 🟠 | Varias | Un mismo concepto con muchos nombres: **señal**, **beacon**, **baliza**, **BLE**, **emisión**, **resonancia de aula**, **sintonía/sintonizar**, **proximidad**; y **profesor** / **docente** alternados (p. ej. `attendance_tab.dart:84` "profesor", `attendance_failed_screen.dart:143` "docente"). | Glosario: p. ej. "señal de la clase" y "docente". |
| INF-08 | 🟢 | `class_session.dart:26` ("Aula 302 • Edificio 401"), `dashboard_tab.dart:236` ("Edificio 401, Aula 302"), `attendance_success_screen.dart:181` ("Aula 302 — Edificio 401"), `dashboard_tab.dart:530` (solo aula) | El formato de la ubicación cambia entre pantallas aunque exista `ClassSession.location`. | Usar siempre `location`. |
| INF-09 | 🟢 | `dashboard_tab.dart:313` | "Presente (93%)" para una sola sesión: no está claro qué representa el 93 %. | Aclarar con el equipo. |
| INF-10 | 🟢 | `dashboard_tab.dart:161` ("2 asignaturas"), `:488` ("Mañana") | Textos fijos que deberían derivarse de los datos. | Calcular. |
| INF-11 | 🟢 | `register_screen.dart:182, 73, 430` | "Facultad y Sede Académica", "Selecciona tu facultad y sede", "Selecciona tu dependencia institucional": tres nombres para un campo que solo lista facultades. | Unificar término. |
| INF-12 | 🟢 | `register_screen.dart:193, 205` | "Repite tu contraseña **institucional**": sugiere que es la contraseña de la cuenta UDLA, cuando en realidad se crea una contraseña nueva de Firebase. Riesgo de que los usuarios reutilicen su clave institucional. | "Repite la contraseña". |
| INF-13 | 🟢 | `auth_messages.dart:12-15` usado en `forgot_password_screen.dart:49` | Si Firebase devolviera `user-not-found` al recuperar, el mensaje sería "Correo o contraseña incorrectos", que no aplica a esa pantalla. | Mensaje específico por contexto. |

---

## 5. Revisión técnica

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| TEC-01 | 🔴 | `test/widget_test.dart:16` | El único test es el contador por defecto de Flutter y **no compila** (`MyApp` no existe en `main.dart`). `flutter analyze` lo reporta como error. Aunque se arreglara, montar la app requiere Firebase inicializado. | Reemplazar por pruebas reales (ver PLAN). |
| TEC-02 | 🟠 | `lib/src/my_app.dart`, `lib/main.dart:34-42` | Código muerto: una segunda `MaterialApp` sin tema ni `AuthGate`, y una lista comentada. Confunde sobre cuál es el punto de entrada. | Eliminar (tras confirmar). |
| TEC-03 | 🟠 | 7 archivos llaman a `FirebaseAuth.instance` directamente (ver ARQUITECTURA §4) | Sin capa de servicio/repositorio de autenticación; la UI no se puede probar sin Firebase. | Introducir un `AuthService` inyectable cuando se aborde la lógica de roles. |
| TEC-04 | 🟠 | `services/attendance_service.dart:14-18` | Contador estático global: el resultado depende de cuántas veces se ha escaneado en toda la vida del proceso. No determinista en pruebas. | Interfaz + implementación simulada inyectable. |
| TEC-05 | 🟠 | `main.dart:12-14`, `firebase_options.dart:27-38` | `Firebase.initializeApp` sin manejo de errores; en Linux/macOS lanza `UnsupportedError` y la app no arranca (existe carpeta `linux/`). | Pantalla de error o retirar plataformas no soportadas. |
| TEC-06 | 🟢 | `attendance_success_screen.dart:389`, `dashboard_tab.dart:141` | 2 *infos* del analizador (`use_null_aware_elements`). | Aplicar la sugerencia. |
| TEC-07 | 🟢 | `_showMessage` repetido en `login_screen.dart:29`, `register_screen.dart:52`, `forgot_password_screen.dart:27`; círculos concéntricos repetidos en `forgot_password_screen.dart:166-217`, `dashboard_tab.dart:107-114` y `widgets/status_orb.dart` | Duplicación. | Extraer utilidades/widgets. |
| TEC-08 | 🟢 | `register_screen.dart` (587 líneas), `dashboard_tab.dart` (556), `attendance_success_screen.dart` (439) | Archivos grandes, aunque divididos en widgets privados. | Aceptable; mover subwidgets a archivos si crecen. |
| TEC-09 | 🟢 | `user_avatar.dart:14`, `dashboard_tab.dart:19`, `profile_tab.dart:22`; `home_header.dart:4,62` | `currentUser` se lee en `build` (no reactivo). Un widget compartido (`HomeHeader`) depende de `DemoData`. | Pasar datos por parámetro / escuchar `userChanges()`. |
| TEC-10 | 🟢 | `app_theme.dart:19`, `pubspec.yaml:36` | `google_fonts` descarga la fuente en tiempo de ejecución (sin conexión en el primer arranque se usa la fuente por defecto). `cupertino_icons` no se usa. | Empaquetar la fuente si se requiere uso sin conexión. |
| TEC-11 | 🟢 | `login_screen.dart:36` | Parámetro `context` no usado en `_demo`. | Limpieza. |
| TEC-12 | 🟠 | `AndroidManifest.xml`, `register_screen.dart:507-509` | No hay permisos Bluetooth ni paquete BLE. El texto promete detectar "sin geolocalizarte", pero en Android 11 o inferior el escaneo BLE exige permiso de ubicación. | Tener en cuenta al implementar BLE; revisar el texto. |

---

## 6. Seguridad

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| SEG-01 | 🔴 | `register_screen.dart:67`, ausencia de `sendEmailVerification` | La restricción a `@udla.edu.co` es **solo del cliente** y no hay verificación de correo: cualquiera puede crear una cuenta con un correo UDLA que no le pertenece, o con cualquier dominio llamando directamente a la API de Firebase Auth. | Verificación de correo obligatoria y restricción del lado del servidor (p. ej. *blocking functions* de Identity Platform o reglas en el backend). |
| SEG-02 | 🟠 | `android/app/build.gradle.kts` (`signingConfig = debug`, `applicationId = com.example…`) | La *release* se firma con claves de debug y el identificador es de ejemplo: no publicable. | Configurar firma propia antes de distribuir. |
| SEG-03 | 🟢 | `lib/firebase_options.dart`, `android/app/google-services.json` | Contienen claves API de Firebase. Son identificadores de cliente (no secretos) y es normal incluirlos, pero conviene restringirlas en Google Cloud y activar App Check. No se encontraron claves privadas ni contraseñas. | Restringir claves; App Check. **No modificado.** |
| SEG-04 | 🟠 | Raíz del proyecto | El directorio **no es un repositorio git**: no hay historial ni respaldo de los cambios. | Inicializar control de versiones antes de la fase de correcciones. |

---

## 7. Accesibilidad y usabilidad

| ID | Sev. | Ubicación | Problema | Recomendación |
|---|---|---|---|---|
| A11Y-01 | 🟠 | `login_screen.dart:99-107, 264-271`, `register_screen.dart:231-239, 338-340` | Enlaces y selector de rol hechos con `GestureDetector` sobre `Text`: sin semántica de botón para lectores de pantalla y áreas táctiles menores de 48 dp. | `TextButton`/`InkWell` con `Semantics`. |
| A11Y-02 | 🟠 | `app_bottom_nav.dart:88-114` | El botón central es un `GestureDetector` con solo un ícono, sin etiqueta semántica; su texto "Asistencia" es otro objetivo táctil separado. | `Semantics(label: 'Asistencia', button: true)` o `Tooltip`. |
| A11Y-03 | 🟢 | `app_bottom_nav.dart:21,29`, `app_top_bar.dart:21`, `home_header.dart:16` | Alturas fijas que pueden recortar texto ampliado. | Probar con escalado de texto. |
| A11Y-04 | 🟢 | `register_screen.dart:446-471` | La barra de seguridad de contraseña solo comunica el nivel por color/cantidad; la etiqueta es siempre "Seguridad". | Texto "Débil/Media/Fuerte". |

---

## 8. Inconsistencias de los diseños del estudiante (2026-11-01)

Diseños revisados: las 7 imágenes de `docs/images_views_estudiante/`.

| ID | Inconsistencia | Resolución |
|---|---|---|
| DIS-01 | La barra inferior difiere entre diseños: 5 pestañas (Inicio · Mis Clases · Historial · Progreso · Perfil) en Inicio y 4 (Inicio · Asistencia · Historial · Perfil) en el resto; el círculo destacado cambia de pestaña | Se unificó en **5**: Inicio · Mis Clases · **Asistencia** (central fijo) · Historial · Perfil. "Progreso" e "Historial" son la misma pantalla (su chip dice "Historial y Progreso Académico") |
| DIS-02 | Referencias a otra institución: "BioAsistencia UN", `vruizc@unal.edu.co`, "Minas / Ingeniería", "Sede Central / Medellín", "SIA", "Universidad Nacional" | No se copiaron. Se usa la identidad UDLA y datos reales del usuario |
| DIS-03 | Logo como placeholder "img" y cabeceras distintas ("Campus Presencial", árbol, "Detalle De…") | Cabecera única `HomeHeader` con `BrandLogo` |
| DIS-04 | Datos sin fuente: horarios, grupos, docentes, conteos, periodos, programa, semestre, índice, "Transmisor calibrado · Cada 15 s" | Horarios, grupos, docentes, conteos y periodos salen de Firestore. Programa, semestre y sede los edita el usuario ("Sin registrar" si faltan). La tarjeta de BLE dice "Próximamente" |
| DIS-05 | Regla del 80 % ("Alerta de riesgo presencial", "Cumples el 80 %") | No confirmada: la alerta usa `maxAbsences` por asignatura y el resumen es neutro |
| DIS-06 | "Margen: N permitidas" sin regla | Solo se muestra si la asignatura define `maxAbsences` |
| DIS-07 | "Estado regular", "Estudiante Activo", "Óptimo": juicios sin fuente | Omitidos; se muestra el rol real |
| DIS-08 | "Comprobante #AS-9824", "OFICIAL SIA", "Firma SHA", "A tiempo (+3m)" fijos | Código derivado del registro; "+N min desde el inicio" calculado con la sesión real; sin firma ni "oficial" |
| DIS-09 | "Señal BLE detectada", "Beacon en rango" | BLE no existe: "El docente abrió la sesión" |
| DIS-10 | "Ver detalle" sin pantalla de destino | Se creó `CourseDetailScreen` con el estilo de la app |
| DIS-11 | Selector desplegable **y** chips de periodo (control duplicado) | Se dejaron solo los chips |
| DIS-12 | Avatar repetido junto al saludo (además de la cabecera) | Omitido |
| DIS-13 | Interruptor "Ahorro inteligente de energía" sin función posible (no hay escaneo) | Omitido |
| DIS-14 | Perfil sin "Cerrar sesión" | Se conservó el botón (función existente) |
| DIS-15 | "Demostración: Vista sin asignaturas matriculadas" (simulador de estado vacío) | Sustituido por el estado vacío real |
| DIS-16 | Íconos por asignatura (terminal, red, base de datos) sin dato que los respalde | Ícono genérico de asignatura |
| DIS-17 | "Asistencia registrada" sin persistencia (antes en memoria) | Persistida en `attendance` con reglas (sesión abierta, matrícula, sin duplicados) |
| DIS-18 | Consejos de "Señal no encontrada" sobre Bluetooth y acercarse al docente; "Sintonía completada"; textos de Registro que presentaban BLE como activo | Sustituidos por consejos reales (conexión, asignatura correcta, confirmar con el docente), "Registro completado sin novedades" y BLE como "próxima versión" (revisión del 2026-11-01) |

## 9. Inconsistencias de los diseños del docente (2026-11-01)

Diseños en `docs/images_views_docente/` (9 HTML). Todos se revisaron completos: texto, botones, formularios y scripts.

| ID | Inconsistencia en el diseño | Resolución |
|---|---|---|
| DOC-01 | "BioAsistencia UN", "UNAL", "SIA", "Universidad Nacional", "Sede Bogotá/Amazonia/Leticia", "Vicerrectoría Académica", "DNTI", correos `@unal.edu.co` | No se copiaron. Identidad UDLA; sede y facultad del perfil o "Sin registrar" |
| DOC-02 | **Cualquiera podía elegir "Docente" al registrarse** y las reglas lo aceptaban sin verificación (hallazgo del código, no del diseño) | Lista `teachers/{correo}` administrada por la institución + correo verificado; `isTeacher()` en las reglas; registro docente rechazado si el correo no está autorizado |
| DOC-03 | "Iniciar asistencia BLE", "Baliza transmitiendo", "BLE confirmado", "Resonancia", radar | No hay BLE. Se inicia una **sesión con ventana de registro**; los textos dicen que la verificación por proximidad no está disponible |
| DOC-04 | Contadores simulados con `setInterval` (19→27 detectados), "Consolidando…" con `setTimeout` | Datos en vivo de Firestore (`attendance`) y operaciones reales |
| DOC-05 | "Acta criptográfica firmada", "Sello PKI", "Token Ed25519 rodante", "Firma digital", "Validación biométrica (huella/FaceID)" | Retirados: no existen. Los PDF dicen que no reemplazan certificaciones oficiales |
| DOC-06 | "Sincronizar con SIA", "Sincronizado SIA", "Firebase Cloud" | Retirados (no hay integración académica) |
| DOC-07 | "Meta reglamentaria UNAL del 80 %", "Meta sede 85 %", ">15 % riesgo estatutario", "Alertas al superar 10 %" | No confirmadas: el riesgo usa `maxAbsences` por asignatura (igual que el estudiante) |
| DOC-08 | "Notificar" a estudiantes en riesgo y "Pulso háptico a 18 dispositivos" | Sin canal de notificaciones: no se implementan |
| DOC-09 | Pantalla "Preferencias y calibración BLE" (potencia Tx, RSSI, anti-spoofing, filtro de muros, telemetría) | No implementada; en Perfil se muestra "Proximidad (Bluetooth) · Próximamente" |
| DOC-10 | Dos barras inferiores distintas (4 y 5 pestañas, con "Sesión") | Una barra de 4: Clases · Historial · Reportes · Perfil. La sesión activa se abre desde Clases y la campana |
| DOC-11 | Dos pantallas de cierre ("Resumen y cierre" y "Cierre y resumen") con datos solapados | Unificadas en `SessionSummaryScreen` |
| DOC-12 | "Guardar como borrador (sin alumnos)" | Se puede crear la clase sin estudiantes ("Crear clase sin estudiantes") y completarla al editar |
| DOC-13 | "Espacio físico" como lista cerrada de edificios inventados | Campos libres Aula y Edificio |
| DOC-14 | "Margen de cortesía 0–30 min" y "Auto-cierre al terminar el bloque" | Se convierten en la **duración del registro** (5/10/15/20 min) con cierre automático real (`endsAt`, exigido en las reglas) |
| DOC-15 | Logout en el ícono de Perfil de la barra (confunde navegación y cierre) | Perfil es una pestaña; "Cerrar sesión" con confirmación |
| DOC-16 | Nombres, códigos y cifras de ejemplo (Carlos Restrepo, 28 inscritos, 91.8 %…) | Solo datos reales; el modo demostración usa "Estudiante de ejemplo NN" y lo indica |
| DOC-17 | "Justificar/Notificar" en la alerta de riesgo sin sesión asociada | La justificación se hace por sesión (Resumen). En Reportes la alerta es informativa |
| DOC-18 | Incidencias del estudiante ("Reportar al docente") que nadie podía leer | El docente las ve en Reportes (`incidents.teacherUid`) |
