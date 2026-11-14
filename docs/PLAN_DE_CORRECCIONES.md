# Plan de correcciones

> Plan original del 2026-11-01, actualizado con el avance de la primera fase de correcciones. Los IDs remiten a `AUDITORIA_DE_CONSISTENCIA.md` (estado detallado en su §0).
> ✅ Hecho y verificado · 🟡 Parcial · ⏳ Pendiente · ❓ Requiere decisión o autorización.

## Decisiones tomadas por el equipo (2026-11-01)

| Tema | Decisión |
|---|---|
| Inicio de sesión | Con correo `@udla.edu.co` **o** con código; el correo debe ser del dominio UDLA |
| Código | Obligatorio al registrarse; estudiante: código estudiantil; docente: código o documento propio |
| Almacenamiento | Cloud Firestore (perfil + índice código → correo). El equipo habilita Firestore y publica `firestore.rules` |
| Doble factor en Recuperar | Se conserva deshabilitado, "Próximamente" |
| Accesos demo | Eliminados (2026-11-14) |
| Regla del 80 % | No confirmada → texto neutro |

## Fase 0 — Preparación

| # | Tarea | Estado |
|---|---|---|
| 0.1 | Inicializar git | ⏳❓ No autorizado todavía. Se hizo una copia de seguridad previa fuera del proyecto. |
| 0.2 | Pruebas reales en lugar del test roto | ✅ 31 pruebas |
| 0.3 | Eliminar código muerto | ✅ |

## Fase 1 — Identidad institucional

| # | Tarea | Estado |
|---|---|---|
| 1.1 | "Universidad Nacional" → "Universidad de la Amazonia" | ✅ |
| 1.2 | Nombre "BioAsistencia" sin "UN" | ✅ |
| 1.3 | Grafía "Amazonia" / "UDLA" | ✅ |
| 1.4 | Retirar "SIA" | ✅ |
| 1.5 | Datos de demo con datos de la UDLA | ⏳❓ Sin datos reales disponibles |
| 1.6 | Facultades y texto legal | 🟡 Término "Facultad" unificado; lista y "Estatuto Estudiantil" ⏳❓ |
| 1.7 | Nombre visible en plataformas | ✅ (ícono e identificadores ⏳❓) |

## Fase 2 — Honestidad funcional

| # | Tarea | Estado |
|---|---|---|
| 2.1 | Retirar promesas no implementadas | ✅ |
| 2.2 | Campo de doble factor | ✅ "Próximamente" |
| 2.3 | Botones demo | ✅ Eliminados (2026-11-14) |
| 2.4 | Comprobante sin valores fijos | ✅ |
| 2.5 | Estado de Inicio coherente con el escaneo | ✅ |
| 2.6 | Mensaje de resumen | ✅ Neutro |
| 2.7 | Historial coherente con "Ver en mi historial" | ✅ En memoria |
| 2.8 | Enlace a la política de datos | ⏳❓ Falta la URL |

## Fase 3 — Navegación y validación

| # | Tarea | Estado |
|---|---|---|
| 3.1 | "Inicia sesión" sin duplicar el Login | ✅ |
| 3.2 | `AuthGate` como único conmutador | ✅ |
| 3.3 | Validadores compartidos | ✅ |
| 3.4 | Manejo de errores al iniciar Firebase | ✅ |
| 3.5 (nueva) | Login con código + perfiles en Firestore | ✅ en código · ❓ requiere publicar reglas en la consola |

## Fase 4 — Consistencia visual

| # | Tarea | Estado |
|---|---|---|
| 4.1 | Logo único | 🟡 `BrandLogo` en login; logo oficial ⏳❓ |
| 4.2 | `AppTopBar` unificada, avatar opcional | ✅ |
| 4.3 | Títulos/botones en español y mayúsculas coherentes | ✅ |
| 4.4 | Íconos y términos | ✅ íconos, "docente", ubicación · 🟡 términos de marca |
| 4.5 | Orbe de fallo y títulos de resultado | ✅ |
| 4.6 | Quitar `hintIsValue` | ✅ |
| 4.7 | Campos obligatorios | ✅ |
| 4.8 | Desbordamientos | 🟡 320 dp / 130 % verificado |
| 4.9 | Centralizar colores/estilos | 🟡 mínimo (riesgo medio, no prioritario) |
| 4.10 (nueva) | Botón central de la barra alineado con su etiqueta | ✅ |

## Fase 4b — Vistas del estudiante (2026-11-01) ✅

Implementadas desde los diseños de `docs/images_views_estudiante/`, con Firestore real: Inicio, Mis Clases, Detalle, Asistencia, Comprobante, Fallo, Historial con PDF y Perfil. Inconsistencias resueltas en la AUDITORIA §8. Las tareas 5.2 (persistencia de asistencias e historial real) y 5.5 (parcial: `AttendanceTab.register` inyectable) quedan cubiertas.

## Fase 4c — Vista del docente (2026-11-01) ✅ implementada · ⏳ sin validar en servidor

Implementada desde `docs/images_views_docente/`: acceso con autorización (`teachers/{correo}` + correo verificado), Clases, Crear/Editar clase con importación Excel/CSV, Sesión activa, Resumen de asistencia, Historial, Reportes y Perfil, más la demostración del docente. Reglas nuevas para `courses`, `sessions`, `attendance` (manual), `justifications` e `incidents`. Inconsistencias: AUDITORIA §9. Pendiente: publicar las reglas y probar en dispositivos.

## Fase 5 — Funcionalidad de fondo (pendiente)

| # | Tarea | Dependencia |
|---|---|---|
| 5.1 | Vista de docente (qué ve y qué puede hacer) | ✅ Fase 4c (falta validar en servidor) |
| 5.2 | Persistir asistencias en Firestore e Historial real | ✅ Hecho (falta publicar las reglas) |
| 5.2b | Vista docente para abrir y cerrar sesiones y crear asignaturas | ✅ Fase 4c |
| 5.3 | Verificación de correo / restricción de dominio en Auth | ✅ Obligatoria para ambos roles en la app (`EmailVerificationGate`) y en las reglas (`verified()`), sin cambiar la configuración de Firebase |
| 5.4 | BLE real (paquete, permisos, textos sobre ubicación) | ❓ Hardware y protocolo |
| 5.5 | `AuthService` inyectable + pruebas de flujos con Firebase simulado | — |
| 5.6 | Firma de release e identificadores definitivos | ❓ Re-registro en Firebase |
| 5.7 | Alternativa segura al `get` público de `codes/` (Cloud Function) | ❓ Plan Blaze |
| 5.8 | Política de datos, facultades, reglamento, datos de sede reales | ❓ Información institucional |

## Criterio de cierre de cada fase

`flutter analyze` sin problemas, `flutter test` en verde y recorrido manual de los flujos F1–F5 de `PANTALLAS_Y_FLUJOS.md` **en un dispositivo** (pendiente: no se ha hecho en esta fase).
