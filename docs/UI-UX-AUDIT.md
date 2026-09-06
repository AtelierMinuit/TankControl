# Auditoría Visual y de Experiencia de Usuario (UI/UX)
**Proyecto:** TankControl / HP Smart Tank 500 macOS Utility  
**Versión de Referencia:** `0.1.0-alpha-pre-hardware`  
**Fecha:** Septiembre 2026  
**Estándar de Evaluación:** Apple Human Interface Guidelines (macOS Desktop Utilities)

---

## 1. Clasificación de Hallazgos

### [CRITICAL]
1. **Mezcla de Acciones Cotidianas y Rutinas de Alto Riesgo en Interfaz General:**
   * *Problema:* Funciones de estrés térmico y consumo severo de tinta (`deepClean`, `primeTubes`, `injectRaw`, `dumpTree`) estaban accesibles directamente o insinuadas en secciones generales sin una barrera clara de separación de perfil de usuario.
   * *Solución:* Confinar terminantemente todas las herramientas de bajo nivel y rutinas extremas dentro de una sección condicional `Desarrollo` (*Developer Mode*), accesible únicamente tras activar un interruptor con advertencia en Configuración.
2. **Falta de Distinción Visual Irrefutable entre Hardware Real y Simulación Mock:**
   * *Problema:* Cuando la aplicación corre con `SMARTTANK_USE_MOCK=1`, los niveles de tinta y odómetros podían confundirse con datos leídos del bus USB real.
   * *Solución:* Incorporar insignias explícitas ("Datos simulados", "Entorno Mock Offline") en los indicadores de tinta, telemetría y cabecera de estado cuando no haya conexión física.

---

### [MAJOR]
1. **Sobresaturación de Cajas y Tarjetas Flotantes (Over-Boxing):**
   * *Problema:* Prácticamente cada dato, botón y métrica estaba encapsulado en rectángulos redondeados con bordes y sombras (`ActionCard`, `MetricCard`), generando un aspecto de "dashboard web" o panel tipo Electron en lugar de una utilidad nativa de macOS (como *Ajustes del Sistema* o *Utilidad de Discos*).
   * *Solución:* Reemplazar tarjetas decorativas por estructuras nativas: `Form`, `Section`, `LabeledContent`, `List` y `Grid` sobrios con materiales del sistema.
2. **Fragmentación en la Barra Lateral (Sidebar):**
   * *Problema:* La barra lateral contaba con 11 elementos (`Inicio`, `Imprimir`, `Escanear`, `InkSaver`, `Estado`, `Consumibles`, `Mantenimiento`, `Diagnóstico`, `Historial`, `Ajustes`, `Avanzado`), dispersando la atención del usuario.
   * *Solución:* Consolidar en 7 secciones canónicas sobrias (`General`, `Impresión`, `Escáner`, `Tinta y Estado`, `Mantenimiento`, `Estadísticas`, `Configuración`) + `Desarrollo` (oculta por defecto).
3. **Tipografía Rígida con Tamaños en Puntos Hardcodeados:**
   * *Problema:* Múltiples vistas utilizaban `Font.system(size: 22)`, `size: 16`, `size: 11`, `size: 9`, impidiendo la adaptación a las preferencias de accesibilidad de macOS (Dynamic Type).
   * *Solución:* Migrar exclusivamente a estilos semánticos de macOS: `.font(.title2)`, `.font(.headline)`, `.font(.body)`, `.font(.callout)`, `.font(.caption)`.

---

### [POLISH]
1. **Presentación de Errores con Códigos Crudos:**
   * *Problema:* Ante fallos de subproceso o desconexión USB, se presentaban volcados de texto del CLI o códigos de error como `LIBUSB_ERROR_NO_DEVICE`.
   * *Solución:* Mensajes claros orientados al usuario (ej. *"La impresora está ocupada o apagada"*) con los detalles técnicos y volcados confinados dentro de un `DisclosureGroup` colapsable ("Detalles técnicos").
2. **Uso Excesivo del Color de Acento (AccentColor Sprawl):**
   * *Problema:* El color cian/teal de acento se aplicaba indistintamente a fondos, bordes, iconos decorativos y botones.
   * *Solución:* Emplear `Color.accentColor` con moderación estricta para controles interactivos principales. Limitar K/C/M/Y exclusivamente a componentes donde el color transmita información física real (depósitos de tinta).
3. **Escáner sin Separación Visual Clara de Previsualización:**
   * *Problema:* El área de escaneo carecía del flujo visual estándar de *Captura de Imagen* (panel de ajustes izquierdo vs área de lienzo derecho bien delimitada).
   * *Solución:* Reorganizar en layout canónico de dos paneles: ajustes de digitalización a la izquierda (Origen, Modo, Resolución, Área, Formato, Destino) y lienzo de previsualización independiente a la derecha.

---

### [OPTIONAL]
1. **Animaciones Innecesarias:**
   * *Problema:* Animaciones de resorte o pulsaciones repetitivas en badges de conexión que generaban distracción visual.
   * *Solución:* Eliminar animaciones decorativas; conservar únicamente transiciones discretas de estado y barras de progreso activas.
2. **Dimensiones de Ventana Adaptativas:**
   * *Problema:* Dimensiones fijas que no se adaptaban bien a pantallas compactas de 13" o monitores externos Retina.
   * *Solución:* Establecer límites adaptativos `minWidth: 760`, `minHeight: 520`, tamaño por defecto `860 × 580`.

---

## 2. Matriz de Controles UI vs Acciones y Seguridad

Para garantizar que el rediseño visual **no altere ni elimine ninguna funcionalidad existente**, se audita cada control:

| Control UI | Acción Invocada | Backend / Helper | Nivel de Riesgo | Estado en Rediseño |
|---|---|---|---|---|
| **Botón Refrescar** | `printer.refresh()` | `hp-smart-tank-tool json-status` | Nulo (Lectura) | Disponible en Toolbar y Dashboard |
| **Página de Prueba CUPS** | `printerService.sendTestPage()` | `/usr/bin/lp -d HP_Smart_Tank_500` | Nulo (Trabajo seguro) | Sección `Impresión` |
| **Selector de Presets** | `printerService.selectedPreset = p` | Configuración local | Nulo | Sección `Impresión` (DisclosureGroup) |
| **Digitalizar Página** | `scannerService.performScan()` | `hp_scan` / eSCL Bridge | Bajo (Mecánico) | Sección `Escáner` |
| **Abrir Captura de Imagen** | `scannerService.openImageCapture()` | `/System/Applications/Image Capture.app` | Nulo | Sección `Escáner` |
| **Selector InkSaver** | `inkSaverService.activeLevel = l` | PPD / PCL3GUI filter flag | Nulo (Software RIP) | Sección `Impresión > Ahorro de Tinta` |
| **Verificación Inyectores** | `printer.nozzleTest()` | `hp-smart-tank-tool nozzle-test --confirm-hardware` | Bajo (Gasto mínimo de tinta) | Sección `Mantenimiento Normal` |
| **Limpieza Básica Cabezales** | `printer.cleanHeads()` | `hp-smart-tank-tool clean-heads --confirm-hardware` | Moderado (Consumo tinta N1) | Sección `Mantenimiento Normal` |
| **Limpieza de Rodillos** | `printer.cleanRollers()` | `hp-smart-tank-tool clean-rollers --confirm-hardware` | Bajo (Movimiento rodillos) | Sección `Mantenimiento Normal` |
| **Alineación de Cabezales** | `printer.alignHeads()` | `hp-smart-tank-tool align --confirm-hardware` | Moderado (Consumo hoja/tinta) | Sección `Mantenimiento Normal` |
| **Limpieza Profunda (N2)** | `printer.deepClean()` | `hp-smart-tank-tool deep-clean --confirm-hardware` | **Alto (Consumo severo ~6ml)** | Sección `Mantenimiento Avanzado` (Requiere `ConfirmationSheet`) |
| **Cebado Forzado CISS** | `printer.primeTubes()` | `hp-smart-tank-tool prime-tubes --confirm-hardware` | **Crítico (Desgaste bomba ~18ml)** | **Exclusivo Developer Mode** (Requiere confirmación) |
| **Inyección RAW USB** | `printer.injectRawDemo()` | `hp-smart-tank-tool inject-raw --confirm-hardware` | **Crítico (Trama cruda EP 0x02)** | **Exclusivo Developer Mode** (Requiere confirmación) |
| **Volcado Firmware LEDM** | `printer.dumpFirmwareTree()` | `hp-smart-tank-tool dump-tree` | Bajo (Lectura XML cruda) | **Exclusivo Developer Mode** |
| **Salud de Cabezales** | `printer.showHeadHealth()` | `hp-smart-tank-tool head-health` | Nulo (Lectura térmica) | Sección `Estadísticas` / `Tinta y Estado` |
| **Almohadillas Desecho** | `printer.showWasteInk()` | `hp-smart-tank-tool waste-ink` | Nulo (Lectura contador) | Sección `Estadísticas` |
| **Auditoría de Costes** | `printer.showAccounting()` | `hp-smart-tank-tool accounting` | Nulo (Cálculo estadístico) | Sección `Estadísticas` |
| **Copiar Diagnóstico** | `exportDiagnosticReport()` | Sanitize de telemetría y estado | Nulo (Sin datos privados) | Disponible en `Configuración` y `Desarrollo` |
| **Toggle Developer Mode** | `printer.developerMode.toggle()` | Preferencia local (`AppStorage`) | Moderado (Desbloquea herramientas) | Sección `Configuración` (Con alerta de advertencia) |
| **Toggle Modo Simulación** | `printer.useMock.toggle()` | `MockSmartTankService` | Nulo | Sección `Configuración` |

---

## 3. Conclusión de la Auditoría

El rediseño mantendrá el 100% de los comandos y llamadas de subproceso existentes, pero estructurará la presentación visual con estricto apego a las directrices de diseño nativo de Apple:
* Densidad de información controlada.
* Jerarquía tipográfica y cromática basada en el sistema.
* Eliminación de cajas decorativas superfluas.
* Protección de componentes mecánicos y cabezales térmicos mediante segregación de niveles de usuario.
