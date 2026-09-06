# Arquitectura de Información y Navegación — TankControl

**Producto:** TankControl for macOS  
**Documento:** Arquitectura de Navegación y Modelo de Estados  
**Fecha:** 2026-09-05  
**Estado:** ESPECIFICACIÓN TÉCNICA CANÓNICA  

---

## 1. Visión General de Navegación

La interfaz de usuario de **TankControl** adopta el patrón estructural nativo de macOS: **`NavigationSplitView`**. Este esquema reemplaza la ventana monolítica de tamaño fijo por una ventana adaptable, responsiva y redimensionable con una barra lateral (*Sidebar*) organizada por dominios funcionales y un panel de detalle central (*Detail View*).

```
┌───────────────────────────┬──────────────────────────────────────────────────────────────────┐
│  BARRA LATERAL (Sidebar)  │  PANEL DE DETALLE (Detail View)                                  │
├───────────────────────────┼──────────────────────────────────────────────────────────────────┤
│  PRINCIPAL                │                                                                  │
│    ● Inicio (Dashboard)   │  [Estado del Dispositivo: ● Lista y Conectada]                   │
│    ○ Imprimir             │                                                                  │
│    ○ Escanear             │  [Niveles de Tinta CISS:  K 88%  C 74%  M 68%  Y 91%]            │
│    ○ InkSaver             │                                                                  │
│                           │  [Acciones Rápidas: Escanear | Imprimir Prueba | InkSaver]       │
│  DISPOSITIVO              │                                                                  │
│    ○ Estado               │  [Resumen de Cola CUPS: 0 trabajos en espera]                    │
│    ○ Consumibles          │                                                                  │
│    ○ Mantenimiento        │                                                                  │
│    ○ Diagnóstico          │                                                                  │
│                           │                                                                  │
│  SISTEMA                  │                                                                  │
│    ○ Historial            │                                                                  │
│    ○ Ajustes              │                                                                  │
│                           │                                                                  │
│  AVANZADO (Developer)     │                                                                  │
│    ○ Modo Técnico         │                                                                  │
└───────────────────────────┴──────────────────────────────────────────────────────────────────┘
```

---

## 2. Mapa Detallado de Vistas

### 2.1 Grupo Principal (Uso Frecuente)
1. **Inicio (`DashboardView`):**
   - Resumen del estado de la impresora (conectada/desconectada/imprimiendo).
   - Vista rápida de los 4 tanques de tinta con advertencias de nivel bajo.
   - Botonera de acciones inmediatas (Escanear, Imprimir página de prueba, Ajustar InkSaver).
   - Estado de la cola local de trabajos.
2. **Imprimir (`PrintCenterView`):**
   - Monitor de la cola de impresión CUPS (trabajos activos, completados, retenidos).
   - Presets locales de impresión (Documento Texto, Documento Eco, Fotografía Rápida, Foto Alta Resolución, Solo Tinta Negra).
   - Acceso al diálogo nativo de macOS (`CMD+P`).
3. **Escanear (`ScannerView`):**
   - Selector de resolución óptica calibrada (75, 150, 300, 600, 1200 DPI).
   - Selector de modo cromático: Color sRGB, Escala de Grises (8-bit) o Monocromático B/N.
   - Selector de área: A4, Carta, Foto 10×15 cm o Selección personalizada.
   - Lienzo de previsualización interactivo y botón de captura.
4. **InkSaver Center (`InkSaverCenterView`):**
   - Explicación clara y honesta de la tecnología de micro-perforación y reducción raster.
   - Selector de perfil: Desactivado, Eco Ligero, Eco Equilibrado, Eco Máximo, Preservar Bordes, Eco Grayscale.
   - **Comparador Visual Antes/Después:** Slider deslizante interactivo que muestra una muestra impresa original vs procesada con cálculo de reducción de cobertura.

### 2.2 Grupo Dispositivo (Mantenimiento y Salud)
5. **Estado (`StatusView`):**
   - Telemetría de sensores físicos (cubierta frontal, bandeja de papel, atasco de carro).
   - Firmware, número de serie detectado y versión de control ASIC P15_CISS.
   - Odómetro oficial del fabricante (total de impresiones, páginas mono, páginas color, gotas disparadas por canal).
6. **Consumibles (`SuppliesView`):**
   - Vista ampliada de tanques con capacidad teórica, alertas de recarga y referencia de botellas originales recomendadas (GT51 / GT52 / GT53).
   - Diagnóstico del cabezal de impresión (contactos eléctricos y temperatura).
7. **Mantenimiento (`MaintenanceView`):**
   - *Sección Segura:* Alineación de cabezales, impresión de patrón de inyectores (Nozzle Check), limpieza de rodillos de arrastre.
   - *Sección Crítica (Requiere confirmación):* Limpieza profunda de inyectores y purga de tubos CISS (ambas advertidas con el consumo estimado de tinta y desgaste de almohadillas).
8. **Diagnóstico (`DiagnosticsView`):**
   - Verificación integral de los 10 componentes del subsistema: macOS, CUPS Spooler, Driver binario, PPD, Bus USB, Escáner LEDM, AirScan eSCL, AirPrint IPP, ColorSync ICC y Paquete instalador.
   - Indicadores semánticos: `PASS`, `WARN`, `FAIL`, `NOT AVAILABLE`.
   - Botón de exportación para generar el informe técnico `SmartTank-Diagnostic-YYYYMMDD.txt` sin información personal.

### 2.3 Grupo Sistema (Gestión y Configuración)
9. **Historial (`HistoryView`):**
   - Registro local de trabajos impresos (título del documento, páginas, fecha, modo InkSaver utilizado).
   - Sin almacenamiento de imágenes ni contenidos del documento (privacidad absoluta).
10. **Ajustes (`SettingsView`):**
    - Pestañas de configuración: General, Notificaciones, Apariencia (Modo Claro/Oscuro/Sistema), InkSaver por defecto.
    - Pestaña **Avanzado**: Toggle del **Developer Mode** (desactivado por defecto) que requiere confirmación explícita para evitar modificaciones imprudentes.
11. **Privacidad (`PrivacyView`):**
    - Manifiesto verificable de cero telemetría, procesamiento 100% en local y ausencia total de dependencias en la nube.
12. **Acerca de (`AboutView`):**
    - Versión de release (`0.1.0-alpha`), arquitectura ARM64 Apple Silicon nativa, licencias de código abierto vinculadas (MIT, LGPL-2.1) y descargo legal de marcas.
13. **Ayuda Local (`HelpView`):**
    - Guías ilustradas de conexión USB, recarga de tanques, solución de atascos de papel y árbol de resolución de incidencias (*Troubleshooting*).

---

## 3. Máquina Central de Estados (`PrinterConnectionState`)

Toda la aplicación se suscribe a una máquina de estados única implementada en Swift para garantizar consistencia entre la ventana principal, los menús y las notificaciones:

```swift
enum PrinterConnectionState: Equatable {
    case unknown
    case disconnected(reason: String)
    case connecting
    case ready(statusDescription: String)
    case printing(jobId: String, page: Int, totalPages: Int)
    case scanning(progress: Double)
    case busy(taskDescription: String)
    case warning(issue: DeviceWarning)
    case error(error: SmartTankError)
}
```

### 3.1 Transiciones de Estado y Manejo Sin Hardware (Offline)
- Cuando la impresora no está conectada físicamente por USB:
  - El estado se establece en `.disconnected(reason: "Dispositivo USB no detectado")`.
  - La interfaz **NO** despliega alertas rojas de fallo crítico. En su lugar, muestra un banner informativo suave con un diagrama de conexión USB y mantiene plenamente operativas todas las utilidades locales (historial, comparador InkSaver, presets, diagnóstico de software y visor de logs).
  - Al pulsar el botón de simulación (*Mock Mode*), el estado conmuta limpiamente a `.ready(statusDescription: "Simulador Mock Activo")` con una marca de agua explícita de "Datos de Demostración".
