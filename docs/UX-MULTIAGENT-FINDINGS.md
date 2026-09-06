# HP Smart Tank 500 — Matriz Consolidada de Hallazgos Multiagente (UX & Product Design)

**Versión de Software Auditada:** `0.1.0-alpha-pre-hardware`  
**Dispositivo Físico Conectado:** HP Smart Tank 500 (`0x03F0:0x2B54`), Serie `CN1924S1W7`  
**Fecha de Sesión:** 5 de Septiembre de 2026  
**Coordinación:** Antigravity Master Controller  

---

## Resumen Ejecutivo de la Auditoría

Se ejecutó una revisión sistemática a través de 21 perspectivas especializadas (Agentes 1 al 21) interactuando tanto con la arquitectura de la aplicación nativa `TankControl` como con la telemetría viva obtenida directamente de la impresora física HP Smart Tank 500 conectada por USB 2.0.

Se evaluaron aspectos de arquitectura de información (IA), coherencia con las Human Interface Guidelines (HIG) de Apple, rendimiento asíncrono, honestidad de consumibles, seguridad de operaciones de mantenimiento y accesibilidad.

---

## Matriz Consolidada de Hallazgos

| ID | Problema Identificado | Evidencia en Código / Hardware | Agentes Implicados | Severidad | Acción Requerida |
|---|---|---|---|---|---|
| **F-01** | La barra lateral contenía 8 secciones en lugar de las 6 canónicas requeridas por la especificación. | `PrinterManager.swift:5-14` exponía `Configuración` y `Desarrollo` en el flujo principal de usuario diario. | Agente 2 (IA), Agente 3 (HIG), Agente 21 (PO) | **P1** | Reestructurar a las 6 canónicas: `General`, `Impresión`, `Escáner`, `Tinta`, `Mantenimiento`, `Actividad`. Mover Configuración a Preferencias (`⌘,`) y ocultar Modo Desarrollador tras un toggle. |
| **F-02** | Firmware de hardware real reporta `genuineHP` ("Depós. llenos") pero el servicio lo catalogaba como "Estado desconocido". | Telemetría viva de `ProductStatusDyn.xml`: `<pscat:StatusCategory>genuineHP</pscat:StatusCategory>` y `<psdyn:LocString lang="es">Depós. llenos</psdyn:LocString>`. El parser devolvía "Estado desconocido". | Agente 5 (Telemetría), Agente 13 (Copy), Agente 19 (Consistencia) | **P0** | Actualizar `hp-smart-tank-tool.c` y `RealSmartTankService.swift` para mapear `genuineHP` a estado Listo con la descripción `"Depós. llenos"` o `"Lista y en reposo"`. |
| **F-03** | El Dashboard no respondía de inmediato a las 4 preguntas críticas en <10s ni ofrecía los 3 botones de acción primaria. | `DashboardView.swift` dispersaba la información técnica en múltiples tarjetas sin jerarquía rápida de decisión. | Agente 2 (IA), Agente 4 (Visual), Agente 20 (Crítico), Agente 21 (PO) | **P1** | Rediseñar el Dashboard con una tarjeta de decisión superior que responde (*¿Conectada?*, *¿Lista?*, *¿Problemas?*, *¿Tinta?*) y 3 botones claros: `Escanear`, `Abrir Cola`, `Actualizar`. |
| **F-04** | Dispersión de métricas de uso y ausencia de la vista canónica de `Actividad`. | Existen 9,721 páginas impresas reales (3,077 mono, 6,644 color), pero se encontraban divididas entre `StatisticsView` y `HistoryView` no canónicas. | Agente 17 (Odómetro), Agente 2 (IA), Agente 21 (PO) | **P1** | Crear la vista unificada `ActivityView.swift` mostrando odómetro real formateado, desglose mono/color, tasa de atascos (0) y lista de trabajos recientes. |
| **F-05** | Riesgo de falsa confianza en el 100% de tinta por falta de aviso sobre medición algorítmica `dropCount`. | `ConsumableConfigDyn.xml` declara `<dd:ConsumableLevelMessagingStyle>dropCount</dd:ConsumableLevelMessagingStyle>`. Los tanques no tienen flotadores eléctricos. | Agente 6 (Consumibles), Agente 13 (Copy), Agente 14 (A11y), Agente 20 (Crítico) | **P1** | Incorporar aviso prominente permanente en la vista de Tinta y en el Dashboard recordando inspeccionar las ventanas transparentes frontales. |
| **F-06** | Acciones de mantenimiento de alto impacto (Deep Clean / Prime Tubes) sin advertencia explícita de volumen de tinta en ml. | `MaintenanceView.swift` permitía ejecutar limpiezas sin cuantificar que una purga drena ~12–15 ml (~20% del frasco GT52) hacia las almohadillas. | Agente 12 (Mantenimiento), Agente 13 (Copy), Agente 21 (PO) | **P1** | Segmentar Mantenimiento en dos niveles ("Preventivo Diario" vs "Servicio Avanzado"), agregando modal de confirmación con advertencia de consumo en ml. |
| **F-07** | Parser de consumibles reportaba 7 entradas duplicadas mezclando cabezales de impresión y tanques. | La respuesta XML contiene la estación 1 (cabezal `X4E75A`) y estaciones 2-5 (tanques C, M, Y, K). El parser mostraba etiquetas duplicadas "CMY Desconocido". | Agente 6 (Consumibles), Agente 4 (Visual) | **P1** | Filtrar y normalizar exclusivamente los 4 tanques físicos de tinta: K (Negro GT51), C (Cian GT52), M (Magenta GT52), Y (Amarillo GT52). |
| **F-08** | Inexistencia de indicador claro del origen de los datos (`LIVE` vs `MOCK` vs `CACHED`). | Cuando se alternaba entre hardware real y simulador, el usuario no tenía certeza absoluta de si los datos provenían del cable USB o de la simulación. | Agente 5 (Telemetría), Agente 19 (Consistencia) | **P2** | Implementar badges de origen de datos en la barra de herramientas y tarjetas: `LIVE` (verde) y `MOCK` (morado) para trazabilidad total. |
| **F-09** | Falta de atajo estándar de preferencias macOS `⌘,` para la configuración. | La app no tenía cableado el atajo de menú estándar para abrir la ventana/hoja de Ajustes. | Agente 3 (macOS HIG) | **P2** | Implementar el atajo `⌘,` y botón de engranaje en la barra de herramientas de la ventana principal. |
| **F-10** | Contraste insuficiente en el indicador de tinta Amarilla en temas claros. | El color amarillo puro (#EAB308) sobre fondos blancos presenta un ratio de contraste inferior a 3:1 para texto. | Agente 4 (Visual), Agente 14 (Accesibilidad) | **P2** | Aplicar ajuste de contraste reforzado: usar tono ámbar oscuro (#78350F) para texto y bordes delimitadores bien definidos. |

---

## Plan de Ejecución de Refactorización

1. **Reestructuración de Navegación (`PrinterManager.swift` y `MainSplitView.swift`):**
   - Limitar `SidebarSection` a exactamente 6 casos.
   - Migrar `Configuración` a botón de barra de herramientas superior y comando `⌘,`.
   - Relegar `Modo Desarrollador` al interior de Configuración.
2. **Creación de `ActivityView.swift`:**
   - Visualización de odómetro real: 9,721 páginas totales (3,077 texto / 6,644 color).
   - Indicador de salud mecánica (0 atascos de papel, 0 fallos de alimentación).
   - Historial de impresiones recientes con estado CUPS.
3. **Refactorización de `DashboardView.swift` y `StatusView.swift`:**
   - Panel de decisión superior respondiendo las 4 preguntas en <10 segundos.
   - Acciones de 1 clic: `Escanear`, `Abrir cola`, `Actualizar`.
   - Tarjeta de honestidad física de tinta sobre el conteo de gotas.
4. **Hardening de Parsers de Telemetría:**
   - Soporte nativo para estado `genuineHP` ("Depós. llenos") en `RealSmartTankService.swift` y `hp-smart-tank-tool.c`.
   - Normalización de las 4 estaciones de tinta de la Smart Tank 500 (K, C, M, Y).
5. **Verificación de Usabilidad (T1–T5) y Compilación Limpia:**
   - Ejecutar `build_app.sh`, verificar firma ad-hoc y validar los 198 tests unitarios existentes.
