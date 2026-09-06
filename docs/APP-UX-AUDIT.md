# Auditoría Técnica y de Experiencia de Usuario (UX/UI) — HP Smart Tank Utility

**Proyecto:** Utilidad de Escritorio para HP Smart Tank 500  
**Ruta del Componente:** `apps/HPSmartTankUtility/`  
**Fecha:** 2026-09-05  
**Estado:** AUDITORÍA BASE DE ARQUITECTURA  

---

## 1. Resumen Ejecutivo

La aplicación existente (`HPSmartTankUtility`) es un primer prototipo funcional escrito en Swift y SwiftUI que logra interactuar con el binario auxiliar `hp-smart-tank-tool` e invocar el escáner del sistema. Sin embargo, su concepción ad-hoc presenta serias limitaciones de escalabilidad, seguridad y coherencia con las directrices de interfaz humana de macOS (Human Interface Guidelines).

El objetivo de esta auditoría es identificar la deuda técnica, las deficiencias de experiencia de usuario y los riesgos operacionales antes de acometer el rediseño bajo la nueva identidad **TankControl**.

---

## 2. Hallazgos Técnicos y Arquitectónicos

### 2.1 Monolito en Archivo Único
- **Problema:** Los 1.073 renglones de código residen íntegramente en `Sources/main.swift`.
- **Impacto:** Modelos de datos (`SupplyItem`, `OdometerResponse`), lógica de ejecución de procesos (`PrinterManager`), vistas SwiftUI (`ContentView`, `InkTankView`, `MaintenanceCard`), gestión de la barra de menús (`AppDelegate`) y control de notificaciones se encuentran acoplados en el mismo ámbito léxico.
- **Solución Requerida:** Modularizar en directorios especializados: `Models/`, `Services/`, `Design/Components/`, `Views/` y `App/`.

### 2.2 Ventana con Dimensiones Rígidas y Ausencia de Navegación
- **Problema:** La ventana principal está fijada rígidamente en `NSRect(x: 0, y: 0, width: 550, height: 780)` con máscaras `[.titled, .closable, .miniaturizable]`, omitiendo `.resizable`.
- **Impacto:** No existe barra lateral de navegación (`NavigationSplitView`). Toda la interfaz es un desplazamiento vertical continuo que mezcla información de estado, contadores del odómetro y 13 tarjetas de mantenimiento en una sola columna/cuadrícula apretada.
- **Solución Requerida:** Adoptar el patrón canónico de macOS de barra lateral (`NavigationSplitView`) con áreas funcionales bien jerarquizadas (Inicio, Imprimir, Escanear, InkSaver, Estado, Mantenimiento, Diagnóstico, Historial, Ajustes).

### 2.3 Exposición de Operaciones Peligrosas en la Interfaz General
- **Problema:** Operaciones con consumo severo de tinta o riesgo mecánico ("Purga Profunda", "Cebado CISS", "Inyección Raw") aparecen en la misma cuadrícula y con el mismo nivel visual que "Limpieza Básica" o "Alineación".
- **Impacto:** Un usuario estándar puede presionar accidentalmente "Cebar Tubos" o "Purga Profunda", provocando un desperdicio significativo de tinta y saturación prematura de las almohadillas residuales. Además, estas acciones se exponen directamente en el menú de la barra de tareas (`NSStatusItem`).
- **Solución Requerida:** Aislar operaciones destructivas tras un **Developer Mode** (desactivado por defecto) y exigir un modal explícito de confirmación (`ConfirmationSheet`) que detalle qué sucederá, cuánta tinta se consumirá y por qué no debe repetirse.

### 2.4 Ausencia de Capa de Servicios Desacoplada
- **Problema:** `PrinterManager` invoca directamente `runToolCommand` mediante `Foundation.Process()`, mezclando el estado de la UI con la sincronización de subprocesos.
- **Impacto:** No es posible probar la interfaz de usuario en entornos CI/CD o en máquinas sin el binario `hp-smart-tank-tool`. El interruptor `useMock` se limita a añadir `--mock` a los argumentos de CLI si el binario existe.
- **Solución Requerida:** Definir un protocolo formal `SmartTankServiceProtocol` con dos implementaciones independientes: `RealSmartTankService` (interacción local mediante `ProcessRunner` endurecido) y `MockSmartTankService` (simulación completa de estados, colas, escaneos y consumibles para desarrollo offline).

### 2.5 Cadenas Hardcodeadas y Falta de Accesibilidad
- **Problema:** Todas las cadenas de texto están en español plano dentro del código Swift, sin claves localizables ni compatibilidad con `NSLocalizedString` / `String(localized:)`.
- **Impacto:** No admite localización fluida a inglés u otros idiomas. Los tanques de tinta dependen casi exclusivamente del color visual, afectando negativamente a usuarios con discromatopsias o que utilizan VoiceOver.
- **Solución Requerida:** Estructurar claves de localización y asegurar que cada componente de UI (especialmente `InkTankGauge`) exponga etiquetas accesibles completas con nombre del color, porcentaje numérico y estado.

---

## 3. Matriz de Evaluación de UX/UI

| Área de Experiencia | Estado Actual | Diagnóstico | Meta en Rediseño TankControl |
| :--- | :---: | :--- | :--- |
| **Jerarquía Visual** | Deficiente | 13 botones de acción en una sola pantalla sin orden de prioridad. | Dashboard limpio con estado, consumibles y accesos rápidos principales. |
| **Navegación** | Inexistente | Desplazamiento vertical en ventana fija de 550 px. | `NavigationSplitView` estándar de macOS con soporte para redimensionamiento. |
| **Gestión Offline** | Regular | El estado indica "Desconectado" pero mantiene visibles todos los botones de acción. | Estado elegante con sugerencia de conexión y utilidades offline habilitadas. |
| **InkSaver** | Ausente | No existe vista dedicada ni previsualizador antes/después. | Centro InkSaver interactivo con slider de comparación y cálculo de cobertura. |
| **Escáner** | Primitivo | Se limita a ejecutar `open -a "Image Capture"`. | Controlador nativo con selección de resolución, modo y previsualización. |
| **Diagnóstico** | Fragmentario | Sólo tarjetas de mantenimiento; sin chequeo integral de componentes. | Vista de diagnóstico con matriz (macOS, CUPS, USB, AirScan, PPD) y exportación. |
| **Barra de Menú** | Sobrecargada | Incluye acciones peligrosas ("Cebado Forzado", "Inyección Raw"). | Monitor ligero con estado general, niveles condensados y acceso rápido a escaneo. |
| **Seguridad de Procesos** | Moderada | Proceso básico sin cancelación cooperativa estructurada. | `ProcessRunner` endurecido con timeouts, validación de rutas y array de argumentos. |

---

## 4. Conclusión de la Auditoría

La aplicación actual requiere una reingeniería completa de su capa de presentación y servicios, preservando intactos los binarios compilados en `tools/`. La transformación hacia **TankControl** convertirá el software en una utilidad de referencia para macOS.
