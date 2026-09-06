# Sistema de Diseño de TankControl (macOS Apple Silicon)

Este documento define las directrices, tokens visuales, componentes de interfaz y arquitectura de interacción del software de control y utilidades **TankControl**, diseñado específicamente para la impresora multifunción **HP Smart Tank 500** (`0x03F0:0x2B54`, ASIC P15_CISS).

---

## 1. Identidad de Producto y Principios Rectores

* **Nombre Canónico:** `TankControl`
* **Descriptor:** *Native printing, scanning & ink management for macOS*
* **Plataforma Objetivo:** macOS 12 Monterey, macOS 13 Ventura, macOS 14 Sonoma, macOS 15 Sequoia y posteriores (Arquitectura nativa Apple Silicon ARM64).
* **Principios de Diseño:**
  1. **Nativo y Ligero:** Cero frameworks pesados o web-views embebidas. 100% SwiftUI y AppKit con enlace directo a CUPS y APIs del sistema.
  2. **Transparencia Técnica:** Distingue rigurosamente mediciones de hardware reales de estimaciones raster de software (como el algoritmo InkSaver).
  3. **Segregación de Riesgo:** Las rutinas de alto desgaste físico (Purga Profunda Nivel 2, Cebado CISS) están estrictamente confinadas tras la barrera del *Developer Mode* y protegidas por una hoja modal de confirmación (`ConfirmationSheet`).
  4. **Offline-First:** Funciona de forma completa y elegante sin conexión a Internet, sin telemetría remota y con un gemelo digital integrado (*Mock Digital Twin*) para desarrollo y pruebas.

---

## 2. Tokens de Diseño (Design Tokens)

Implementados en `apps/HPSmartTankUtility/Sources/Design/DesignTokens.swift`.

### 2.1. Paleta Cromática Semántica

| Token | Valor / Hex | Uso Principal |
|---|---|---|
| `brandTeal` | `#0094B8` (`rgb: 0.0, 0.58, 0.72`) | Acento primario, selección en barra lateral, botones destacados |
| `brandDarkTeal` | `#05597A` | Variaciones de profundidad y sombras suaves |
| `inkBlack` (K) | `#1F1F21` | Tinta negra CISS, texto puro protegido |
| `inkCyan` (C) | `#00A3E0` | Tinta cian CISS |
| `inkMagenta` (M) | `#EB008B` | Tinta magenta CISS |
| `inkYellow` (Y) | `#FFD100` | Tinta amarilla CISS |
| `statusReady` | Verde macOS | USB Activo, comprobación diagnóstica pasada |
| `statusProcessing` | Azul macOS | Trabajo en curso, digitalización |
| `statusWarning` | Naranja macOS | Tinta baja (<15%), hardware desconectado |
| `statusError` | Rojo macOS | Atasco de papel, fallo crítico, confirmación de riesgo |

### 2.2. Tipografía y Radios

* **Tipografía:** SF Pro Text / SF Pro Rounded para métricas y odómetros numéricos.
* **Radios de Esquina:**
  * Pequeño: `6 pt` (badges, indicadores).
  * Medio: `10 pt` (botones, campos).
  * Tarjeta: `12 pt` (ActionCard, MetricCard, depósitos CISS).
  * Píldora: `20 pt` (pastillas de estado).

---

## 3. Catálogo de Componentes Reutilizables

Ubicados en `apps/HPSmartTankUtility/Sources/Design/Components/`.

1. **`StatusBadge`:**
   * Muestra el estado actual del dispositivo (`ready`, `connecting`, `printing`, `warning`, `error`, `disconnected`) con un punto de pulso animado y etiqueta semántica.
2. **`InkTankGauge`:**
   * Calibrador visual de depósito continuo CISS con acabado acrílico, reflejo especular y marcas de graduación.
   * **Accesibilidad Universal:** Incluye un símbolo geométrico único sobre el tanque (Cuadrado para K, Triángulo para C, Diamante para M, Círculo para Y), garantizando distinción para usuarios con daltonismo.
   * Totalmente etiquetado con propiedades VoiceOver.
3. **`ActionCard`:**
   * Tarjeta macOS para invocar rutinas de diagnóstico o calibración con icono contextual, título, descripción concisa y botón de acción con soporte de carga.
4. **`ConfirmationSheet`:**
   * Hoja modal obligatoria ante acciones críticas de hardware (`deepClean`, `primeTubes`, `injectRaw`). Desglosa de forma honesta el consumo estimado de tinta en mililitros, el desgaste de bomba, la duración y exige marcar una casilla de comprensión antes de permitir la ejecución.
5. **`VisualComparatorView`:**
   * Control interactivo de tipo deslizador (*slider*) que divide una página impresa entre su render original (100% saturación) y la versión optimizada con InkSaver, mostrando la reducción raster porcentual y el delta en KB del spooler.
6. **`DiagnosticRow`:**
   * Fila expandible para auditar subsistemas (macOS, CUPS, PPD, Filtro, USB, Escáner, ColorSync) con detalles técnicos y sugerencias de reparación.
7. **`MetricCard`:**
   * Presentación de métricas de telemetría (páginas impresas, escaneos, gotas, almohadillas) en tipografía SF Pro Rounded.

---

## 4. Arquitectura de Información y Navegación

Estructurada mediante `NavigationSplitView` / `NavigationView` en tres zonas clave:

```text
Sidebar
├── Principal
│   ├── Inicio (Dashboard consolidado, 4 tanques CISS, métricas rápidas)
│   ├── Imprimir (Presets de calidad, cola local CUPS)
│   ├── Escanear (Parámetros DPI/color, previsualización, Image Capture)
│   └── InkSaver (Modos Eco, comparador visual, calculadora de ahorro)
├── Dispositivo
│   ├── Estado (Odómetro profundo, telemetría de gotas, salud de cabezal)
│   ├── Mantenimiento (Rutinas seguras vs operaciones críticas protegidas)
│   └── Diagnóstico (Auditoría de 8 subsistemas, exportador de reportes)
└── Sistema
    ├── Historial (Registro de trabajos locales, privacidad garantizada)
    ├── Ajustes (Notificaciones, Modo Simulación, Developer Mode)
    └── Ayuda (Árbol interactivo de resolución de problemas)
```

---

## 5. Modo Simulación y Desarrollo Offline (Digital Twin)

El proyecto incluye un gemelo digital completo (`MockSmartTankService.swift`) que simula respuestas realistas de estado, lecturas de odómetro (1,420 páginas, 11.2M gotas) y tanques de tinta.

* Se puede activar mediante la variable de entorno:
  ```bash
  SMARTTANK_USE_MOCK=1 ./research/builds/audit-clean/night-20260904/TankControl.app/Contents/MacOS/TankControl
  ```
* O mediante el conmutador interactivo dentro de la interfaz en **Ajustes > Modo Simulación Offline**.
