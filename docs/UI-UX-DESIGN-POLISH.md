# Informe Maestro de Pulido de Diseño y Experiencia de Usuario (UI/UX Design Polish Pass)

**Proyecto:** TankControl / HP Smart Tank 500 macOS Utility  
**Dispositivo:** HP Smart Tank 500 series (`0x03F0:0x2B54`, ASIC P15_CISS)  
**Arquitectura:** Apple Silicon (ARM64 nativo) • macOS 12.0+ (Monterey, Ventura, Sonoma, Sequoia)  
**Versión Congelada:** `0.1.0-alpha-pre-hardware`  
**Entorno de Ejecución:** 100% OFFLINE (Digital Twin / Mock Hardware)  
**Fecha:** 2026-09-05  

---

## 1. BEFORE (Estado Heredado Previo)

Con anterioridad a esta pasada de refinamiento y diseño, la aplicación presentaba una apariencia heterogénea producto de sucesivas iteraciones técnicas:
- **Sobrecarga de pestañas y jerarquía dispersa:** La barra lateral contenía hasta 9 secciones sin agrupar (`Inicio`, `Imprimir`, `Escanear`, `InkSaver`, `Estado`, `Mantenimiento`, `Diagnóstico`, `Historial`, `Ajustes`, `Ayuda`), lo que saturaba la navegación de una utilidad de escritorio.
- **Visuales de tipo panel web / Electron:** Uso de esquinas excesivamente redondeadas (radios de 16 a 20 pt), sombras difusas pesadas, gradientes y fondos de tarjeta opacos que no se integraban con los materiales semánticos de macOS (`NSColor.controlBackgroundColor`, `NSColor.windowBackgroundColor`).
- **Animaciones pulsantes continuas:** El distintivo de estado (`StatusBadge`) y los niveles de tinta aplicaban animaciones de escala y opacidad periódicas que generaban fatiga visual y violaban las directrices de sensibilidad al movimiento de Apple HIG.
- **Falta de honestidad en telemetría de tinta:** Se mostraban lecturas porcentuales de tanques como si provinieran de sensores físicos piezométricos, omitiendo que la Smart Tank 500 no dispone de flotadores electrónicos y que en modo offline los datos son simulados.
- **Herramientas de riesgo mezcladas con mantenimiento diario:** Comandos de purgado agresivo (`prime-tubes`, `inject-raw`) aparecían al mismo nivel que una alineación de cabezales estándar sin advertencias de costo en mililitros de tinta.
- **Opciones de impresión desestructuradas:** La configuración de CUPS/PPD se presentaba en una lista plana de controles difíciles de escanear visualmente.

---

## 2. PROBLEMS (Diagnóstico y Hallazgos Críticos)

La auditoría inicial (`docs/UI-UX-AUDIT.md`) catalogó los problemas en cuatro niveles de severidad:

1. **CRITICAL (Seguridad de Hardware e Integridad de Datos):**
   - Comandos destructivos o con gasto masivo de consumibles (ej. cebado de tubos) estaban accesibles sin requerir confirmación modal explícita ni desglosar el riesgo físico.
   - Ausencia de distinción visual entre datos reales de hardware y datos simulados por el gemelo digital offline.
2. **MAJOR (Arquitectura de Información y Densidad):**
   - Separación artificial entre *InkSaver Center*, *Impresión* y *Estado*. El usuario debía saltar entre tres pantallas distintas para ajustar el modo borrador y revisar el impacto en sus consumibles.
   - El escáner no seguía el flujo estándar de dos paneles de *Captura de Imagen (Image Capture)* de macOS.
3. **POLISH (Tipografía, Espaciado y Coherencia HIG):**
   - Uso de tamaños de fuente fijos con multiplicadores no canónicos en lugar de tokens semánticos nativos (`.title2`, `.headline`, `.body`, `.callout`, `.caption`).
   - Falta de soporte robusto para Modo Claro (Light Mode) en varias vistas donde los textos tenían colores hardcodeados para fondos oscuros.
4. **ACCESSIBILITY (Accesibilidad y Contraste):**
   - Dependencia exclusiva del color en los depósitos de tinta (difícil para usuarios con daltonismo).
   - Animaciones que no respetaban la preferencia de *Reducir movimiento* del sistema.

---

## 3. DESIGN SYSTEM (Sistema de Diseño Canónico macOS)

Se implementó una especificación formal de diseño nativo en `apps/HPSmartTankUtility/Sources/Design/DesignTokens.swift` y componentes reutilizables en `Sources/Design/Components/`:

### A. Escala de Espaciado (8-pt Grid estándar de Apple)
- `xxs`: 4 pt (separación entre etiquetas e iconos)
- `xs`: 8 pt (padding interno de badges y botones compactos)
- `sm`: 12 pt (espacio entre filas de datos)
- `md`: 16 pt (márgenes internos de tarjetas y paneles)
- `lg`: 20 pt (separación entre secciones funcionales)
- `xl`: 24 pt (márgenes de vista principal)
- `xxl`: 32 pt (espaciado entre bloques estructurales mayores)

### B. Radios de Curvatura Sobrios
- `small`: 6 pt (badges de estado, botones secundarios, celdas de selección)
- `medium`: 10 pt (tarjetas de configuración, campos de texto, previsualizaciones)
- `card`: 12 pt (tarjetas maestras de estado)
- `pill`: 16 pt (pastillas semánticas de estado)

### C. Tipografía Semántica del Sistema (Dynamic Type)
- Títulos de Sección: `.title2.weight(.bold)`
- Encabezados de Grupo: `.headline`
- Valores Principales: `.title3.weight(.semibold)`
- Texto General de Cuerpo: `.body` y `.bodyMedium` (`.weight(.medium)`)
- Texto de Apoyo / Ayuda: `.callout`
- Metadatos y Leyendas Técnicas: `.caption` y `.captionBold`
- Registros y Descriptores Técnicos: `.caption.monospaced()`

### D. Paleta Cromática y Superficies
- Superficies: `NSColor.controlBackgroundColor` y `NSColor.windowBackgroundColor` (adaptativas nativas a Dark/Light).
- Separadores: `NSColor.separatorColor` con opacidad calibrada.
- Tintas CISS informativas:
  - Negro (K): Adaptado a `.textColor` dinámico con símbolo ■.
  - Cian (C): `Color(red: 0.0, green: 0.64, blue: 0.88)` con símbolo ▲.
  - Magenta (M): `Color(red: 0.92, green: 0.0, blue: 0.55)` con símbolo ●.
  - Amarillo (Y): `Color(red: 0.98, green: 0.80, blue: 0.05)` con símbolo ◆.
- Estados de Hardware:
  - Normal / Lista: `Color.green` (sin parpadeo)
  - Atención / Advertencia: `Color.orange`
  - Error Crítico: `Color.red`
  - Desconectado / Inactivo: `Color.secondary`
  - Transmisión en Curso: `Color.blue`

---

## 4. ARCHITECTURA DE INFORMACIÓN (Barra Lateral Canónica)

La navegación se consolidó en una barra lateral jerárquica nativa de 7 secciones estándar más una sección condicional para especialistas:

1. **General (Dashboard):** Vista panorámica del dispositivo, estado USB, niveles CISS compactos y acciones operativas inmediatas.
2. **Impresión (Print Center):** Gestión de calidad, sustratos, perfiles ColorSync, reglas de borde a borde y ajuste directo de InkSaver.
3. **Escáner (Scanner):** Utilidad óptica bidireccional en dos columnas (ajustes a la izquierda, cama plana a la derecha).
4. **Tinta y Estado (Ink & Status):** Diagnóstico profundo de niveles CISS, cabezales térmicos, sensores de puerta, atascos y advertencia física.
5. **Mantenimiento (Maintenance):** Separación tajante entre operaciones seguras habituales y procedimientos avanzados de purga.
6. **Estadísticas (Statistics):** Contadores de páginas impresas, digitalizaciones y ciclos, distinguiendo mediciones de hardware vs estimaciones de spooler.
7. **Configuración (Settings):** Preferencias de inicio en macOS, ColorSync, barra de menús y activador de Modo Desarrollador.
8. **Desarrollo (Developer Mode — Opcional):** Descriptores de endpoints USB, volcado de árboles XML de LEDM y herramientas de laboratorio.

---

## 5. REFACTORIZACIÓN POR SECCIONES

### A. Dashboard (General)
- **Status Hero Sober:** En lugar de banners ruidosos, una cabecera limpia identifica el modelo (`HP Smart Tank 500 series`), el ASIC (`P15_CISS`) y el estado de enlace mediante un badge discreto `● Lista (En línea)`.
- **Niveles CISS Compactos:** Indicadores verticales sobrios que incluyen el símbolo geométrico accesible (■, ▲, ●, ◆) y un distintivo `Simulado` mientras no exista hardware USB físico conectado.
- **Acciones Rápidas:** Tres tarjetas estándar con un clic para alineación, limpieza y página de diagnóstico técnico.
- **Transparencia Técnica:** Resumen de configuración activa (cola CUPS, perfil ICC asignado y modo PCL3GUI Mode 10).

### B. Centro de Impresión (Print Center)
- Reemplazo de listas planas por **Grupos Desplegables Nativos (`DisclosureGroup`)**:
  - *Calidad de Impresión:* Resolución (300, 600, 1200 dpi) y selección de sustrato (papel común, fotográfico brillante, mate).
  - *Color y Reproducción:* Asignación sRGB, perfil ICC ColorSync y casilla *Negro Puro (PureBlack)*.
  - *Papel y Alimentación:* Selección de formato (Carta, A4, Oficio, Sobres) y modo sin bordes (*Borderless*).
  - *Ahorro de Tinta (InkSaver):* Control directo con niveles PPD (`Off`, `Eco25`, `Eco50`, `Eco75`, `EdgePreserve`), con estimación porcentual de cobertura raster.
  - *Opciones Avanzadas del Controlador:* Tiempos de secado y densidad PCL3GUI.

### C. Escáner (Scanner)
- Inspirado en la interfaz de **Captura de Imagen (Image Capture)** de macOS:
  - **Columna Izquierda (Controles):** Modo de color (Color 24-bit, Escala de grises 8-bit, Línea 1-bit), resolución óptica (75 a 1200 ppi), tamaño de escaneo y carpeta de destino.
  - **Columna Derecha (Área de Vista Previa):** Representación fiel de la cama plana óptica A4/Carta con visualización de la digitalización en tiempo real.
  - Protocolo de transporte nativo compatible con puente eSCL / AirScan.

### D. Tinta y Estado (Ink & Status)
- **Aviso Obligatorio de Verificación Física:** Cartel destacado recordando al usuario que el sistema CISS de la Smart Tank 500 carece de sensores de flotador en los depósitos externos y que los porcentajes mostrados son estimaciones de software calculadas por gotas disparadas. Se instruye siempre verificar el nivel de tinta a través de la ventana frontal de plástico transparente.
- **Desglose de Cabezales y Sensores:** Inspección de estado de los cartuchos de inyección térmicos (Negro M0H50A, Tricolor M0H51A), temperatura en grados Celsius, sensores de tapa abierta, presencia de papel y sensor de carro óptico.

### E. Mantenimiento (Maintenance)
- **Separación Rigurosa:**
  - *Mantenimiento Habitual:* Alineación de cabezal y limpieza estándar de inyectores (consumo ~1.2 ml).
  - *Mantenimiento Avanzado:* Limpieza profunda (*Deep Clean*) y rotación de rodillos.
- **Hoja de Confirmación Modal (`ConfirmationSheet`):** Toda acción avanzada presenta un diálogo modal con advertencia de costo de tinta (ej. ~5.5 ml consumidos en deep-clean), riesgo de saturación de la almohadilla interna de desperdicio (*waste ink pad*) y requiere pulsar un botón explícito de confirmación.
- Los comandos de riesgo extremo sin arnés de seguridad (`prime-tubes`, `inject-raw`) fueron confinados exclusivamente al Modo Desarrollador con flags estrictos de protección.

### F. Configuración (Settings)
- Formato inspirado en los **Ajustes del Sistema (System Settings)** de macOS:
  - Opciones de arranque al inicio de sesión y presencia en la Barra de Menús.
  - Preferencias de ColorSync con selección de perfil de color activo.
  - Conmutador de *Modo Desarrollador* con texto explicativo que previene su activación accidental.

### G. Modo Desarrollador (Developer Mode)
- Sección oculta por defecto para evitar confusiones al usuario común.
- Presenta herramientas avanzadas:
  - Inspector de descriptores USB (ID `03F0:2B54`, Interfaces 0, 1, 2 y Endpoints).
  - Visor de volcado XML en bruto de LEDM / DevMgmt (`ProductStatusDyn.xml`, `ConsumableConfigDyn.xml`).
  - Botón de un toque para *Copiar Diagnóstico Completo* al Portapapeles de macOS para soporte técnico.

---

## 6. ADAPTABILIDAD, MODO CLARO/OSCURO Y ACCESIBILIDAD

- **Modo Claro / Oscuro Dinámico:** Se eliminaron todos los colores RGB constantes y se migraron a tokens semánticos nativos de AppKit (`NSColor.controlBackgroundColor`, `NSColor.textColor`, `NSColor.separatorColor`).
- **Símbolos Accesibles:** Los depósitos de tinta y gráficos incluyen glifos unívocos (■, ▲, ●, ◆) permitiendo la lectura instantánea sin importar deficiencias cromáticas del observador.
- **Dimensiones de Ventana Adaptativas:**
  - Tamaño mínimo garantizado: 760 × 520 pt (apto para pantallas de 13" sin clipping).
  - Tamaño por defecto: 860 × 560 pt.
  - Diseño fluido que aprovecha pantallas de 27" y monitores Studio Display sin estirar indebidamente los controles.
- **Sensibilidad al Movimiento:** Eliminación de animaciones parpadeantes o pulsantes; las transiciones utilizan animaciones estándar de 0.2s con curva `.easeInOut`.

---

## 7. GALERÍA DE MOCKUPS Y CAPTURAS GENERADAS

El generador nativo Cocoa/CoreGraphics (`tools/generate_mockups.swift`) produjo las imágenes de alta fidelidad en `Brand/screenshots/`:

| Archivo | Vista Representada | Tema | Aspectos Clave Destacados |
|---|---|:---:|---|
| `dashboard_mockup.png` | Dashboard General | Dark | Status Hero sobrio, 4 tanques KCMY con glifos y pastilla de estado. |
| `dashboard_light_mockup.png` | Dashboard General | Light | Verificación de contraste en modo claro con paleta de grises nativa. |
| `ink_status_mockup.png` | Tinta y Estado | Dark | Cartel de advertencia física CISS, tanques detallados y matriz de sensores. |
| `print_center_mockup.png` | Centro de Impresión | Dark | Controles PPD organizados en DisclosureGroups de macOS. |
| `scanner_mockup.png` | Escáner | Dark | Distribución en dos columnas estilo Captura de Imagen con preview plana. |
| `maintenance_mockup.png` | Mantenimiento | Dark | Separación clara entre tareas habituales y avanzadas con desglose de ml. |
| `settings_mockup.png` | Configuración | Dark | Interfaz estilo System Settings y conmutador de Modo Desarrollador. |
| `developer_mode_mockup.png` | Modo Desarrollador | Dark | Descriptores USB, visor de árbol XML LEDM y volcado de telemetría. |
| `inksaver_mockup.png` | InkSaver Center | Dark | Comparador interactivo de trama raster con aviso de transparencia. |

---

## 8. VALIDACIÓN, CONSTRUCCIÓN Y VERIFICACIÓN DE SEGURIDAD

1. **Construcción Nativa del Bundle:**
   - Script de compilación: `./apps/HPSmartTankUtility/build_app.sh`
   - Target de compilación: `arm64-apple-macos12.0`
   - Resultado: Bundle válido generado en `research/builds/audit-clean/night-20260904/TankControl.app`
   - Firma de código ad-hoc: Verificada mediante `codesign --verify --deep --strict` (Código de salida: 0, firma íntegra).

2. **Suite Completa de Pruebas Automatizadas:**
   - Comando: `python3 -m unittest discover -s tests -v`
   - Cobertura: **198/198 pruebas superadas con éxito (100% PASS en 30.58s)**.
   - Preservación de pruebas de hardening: Las firmas exigidas por `test_security_hardening.py` (`toolBinaryPath`, validación de helpers dentro del bundle, flags de confirmación de hardware) se mantuvieron intactas.

3. **Cero Regresiones en el Núcleo del Controlador (C Core):**
   - Se verificaron los hashes SHA-256 de todos los componentes de bajo nivel:
     - `tools/rastertopcl3gui.c`: `418e14c2287220cf...` (Sin cambios)
     - `tools/cups_backend_smarttank.c`: `36942567327e9dbc...` (Sin cambios)
     - `tools/hp_scan.c`: `0e6f8923dc42f323...` (Sin cambios)
     - `tools/hp-smart-tank-tool.c`: `e8381df5ecfdd5d7...` (Sin cambios)

---

## 9. DEUDA DE UX RESTANTE (Validación Física Futura)

Concluido el pulido visual y arquitectónico offline, los siguientes puntos quedan explícitamente delimitados como deuda técnica y de experiencia de usuario que **requiere hardware físico para su calibración final**:

1. **Feedback Háptico y Sonoro en Errores Reales:** Calibrar las notificaciones de macOS cuando ocurra un atasco mecánico real o se agote el papel en la bandeja física.
2. **Latencia del Escaneo eSCL en Vivo:** Medir la velocidad de transferencia de la imagen escaneada por USB sobre Interface 2 para ajustar la barra de progreso en resoluciones de 600 y 1200 dpi.
3. **Calibración de la Estimación de Gotas:** Ajustar el factor multiplicador de mililitros de tinta consumida por página frente a impresiones de prueba reales pesadas en báscula de precisión miligráfica.
4. **Verificación de la Barra de Menús en Monitores Múltiples:** Probar el comportamiento del popover de la barra de menús en configuraciones multimonitor con diferentes densidades de píxeles (Retina vs estándar).
