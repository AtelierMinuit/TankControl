# Revisión Visual Sistemática — Ronda 1 (Auditoría en Vivo)
**Fecha:** 2026-09-05 · **Sesión:** `research/ui-review/20260905-210520/round-1/`
**Plataforma:** macOS 26.6.2 · Apple Silicon ARM64 · **Bundle:** `HP Smart Tank Utility.app` (`TankControl.app`)

---

## 1. Inventario de Pantallas Auditadas (29 Capturas)

| Ref | Archivo | Tipo de Estado | Modo | Descripción |
|---|---|---|---|---|
| S01 | `01-dashboard.png` | Hardware Real (Offline) | Claro | Panel principal con estado del equipo, accesos y tinta |
| S02 | `01-dashboard-dark.png` | Hardware Real (Offline) | Oscuro | Panel principal en tema oscuro |
| S03 | `02-print.png` | Hardware Real | Claro | Centro de impresión y cola CUPS |
| S04 | `02-print-dark.png` | Hardware Real | Oscuro | Centro de impresión en tema oscuro |
| S05 | `03-scanner.png` | Hardware Real | Claro | Vista de digitalización y captura |
| S06 | `03-scanner-dark.png` | Hardware Real | Oscuro | Vista de digitalización en tema oscuro |
| S07 | `04-ink.png` | Hardware Real (Offline) | Claro | Niveles CISS de 4 depósitos (K, C, M, Y) |
| S08 | `04-ink-dark.png` | Hardware Real (Offline) | Oscuro | Niveles CISS en tema oscuro |
| S09 | `05-maintenance.png` | Hardware Real | Claro | Herramientas de mantenimiento rutinario y avanzado |
| S10 | `05-maintenance-dark.png` | Hardware Real | Oscuro | Mantenimiento en tema oscuro |
| S11 | `06-activity.png` | Hardware Real | Claro | Odómetro, contadores de hardware e historial |
| S12 | `06-activity-dark.png` | Hardware Real | Oscuro | Odómetro en tema oscuro |
| S13 | `07-settings.png` | Aplicación | Claro | Hoja modal de ajustes y modo desarrollador |
| S14 | `07-settings-dark.png` | Aplicación | Oscuro | Hoja modal en tema oscuro |
| S15 | `08-developer.png` | Developer Mode | Claro | Descriptores USB, volcados XML y diagnósticos |
| S16 | `08-developer-dark.png` | Developer Mode | Oscuro | Developer Mode en tema oscuro |
| S17 | `09-about.png` | Información | Claro | Créditos, licencias y arquitectura técnica |
| S18 | `09-about-dark.png` | Información | Oscuro | Información en tema oscuro |
| M01 | `mock-low-ink.png` | MOCK STATE | Claro | Simulación de tinta baja en los 4 tanques (<10%) |
| M02 | `mock-paper-empty.png` | MOCK STATE | Claro | Simulación de bandeja de entrada sin papel |
| M03 | `mock-door-open.png` | MOCK STATE | Claro | Simulación de puerta o cubierta abierta |
| M04 | `mock-scanner-busy.png` | MOCK STATE | Claro | Simulación de escáner en curso / ocupado |
| M05 | `mock-busy.png` | MOCK STATE | Claro | Simulación de impresión activa / ocupada |
| M06 | `mock-timeout.png` | MOCK STATE | Claro | Simulación de tiempo de espera agotado en USB |
| M07 | `mock-error.png` | MOCK STATE | Claro | Simulación de error mecánico general |
| M08 | `mock-disconnected.png`| MOCK STATE | Claro | Simulación de desconexión forzada |
| W01 | `size-760x520.png` | Ventana Mínima | Claro | Prueba de escala 760 × 520 pt |
| W02 | `size-900x650.png` | Ventana Normal | Claro | Prueba de escala 900 × 650 pt |
| W03 | `size-1200x800.png` | Ventana Grande | Claro | Prueba de escala 1200 × 800 pt |

---

## 2. Tabla de Problemas y Gravedad Detectados (Ronda 1)

| Pantalla | Problema Detectado | Gravedad | Solución Propuesta (Fix) |
|---|---|---|---|
| **Escáner** (`03-scanner`) | Ausencia de controles estándar de escaneo (Modo, Resolución, Tamaño, Formato, Destino). La vista relega al usuario a Captura de Imagen sin UI integrada. | **P1** | Integrar panel lateral nativo con selectores: Modo de color, Resolución (75-1200 DPI), Área (A4/Carta/Foto), Formato (PDF/PNG/JPEG), Destino, y botones jerarquizados [Previsualizar] y [Escanear]. |
| **Tinta / Medidor** (`04-ink-dark`, `mock-low-ink`) | El depósito Negro (`K`) usa `Color.black` puro. En Modo Oscuro, el nivel tiene contraste nulo contra el fondo gris oscuro de la tarjeta. | **P1** | Incorporar un sutil borde de contraste o tono calibrado (`Color(white: 0.18)` con borde) para que el nivel de tinta negra sea 100% legible en fondos oscuros. |
| **Mantenimiento** (`05-maintenance`) | Los botones de acción de hardware ("Imprimir Patrón", "Limpiar Cabezales", "Alinear") permanecen habilitados aun cuando la impresora está desconectada. Al pulsarlos, fallan con error crudo. | **P1** | Deshabilitar los botones mecánicos con `.disabled(!printer.connectionState.isConnected && !printer.useMock)` y mostrar un aviso explicativo. |
| **Impresión** (`02-print`) | Vista excesivamente árida; sólo texto negativo ("La cola no se consulta desde esta vista"). No muestra el estado real de la cola CUPS del sistema (`HP_Smart_Tank_500`). | **P1** | Mostrar tarjeta informativa con la cola activa CUPS real (`HP_Smart_Tank_500`), su URI (`usb://...`), estado del servidor cupsd y botón de acceso directo. |
| **Actividad** (`06-activity`) | Muestra una pastilla verde con "Último registro guardado" incluso con la impresora desconectada y sin telemetría previa, lo que confunde al usuario haciéndole creer que hay conexión activa. | **P2** | Cambiar la pastilla a color neutro (`.secondary`) y texto "Sin conexión activa" cuando el hardware está desconectado. |
| **Configuración** (`07-settings`) | La hoja modal tiene tamaño fijo sobredimensionado (`580x500 pt`), dejando un enorme espacio vacío en la parte inferior. | **P2** | Ajustar el tamaño del sheet a un diseño compacto proporcional (`520x360 pt`) con espaciado balanceado. |
| **Desarrollo / Sidebar** (`08-developer`) | El enlace "Desarrollo" en la barra lateral tiene color rojo forzado. Al estar seleccionado con el acento azul de macOS, el texto rojo sobre fondo azul produce choque cromático y pésimo contraste. | **P2** | Retirar el `.foregroundColor(.red)` en la fila de navegación para que la selección estándar de macOS invierta limpiamente a texto blanco. |
| **Acerca de** (`09-about`) | Al pulsar "Acerca de..." en Configuración, se inyecta temporalmente un ítem "Acerca de" en la barra lateral principal, rompiendo la arquitectura canónica de 6 secciones. | **P2** | Mostrar "Acerca de" como una ventana secundaria o sección integrada en Ajustes, sin mutar la barra lateral principal. |
| **General / Layout** (`size-1200x800`) | En resoluciones amplias, la cabecera de la sección Tinta expande "Nivel estimado" hasta el borde derecho de la ventana mientras la tarjeta superior se detiene a 900 pt, creando desalineación visual. | **P2** | Estandarizar `maxWidth: 860` en todo el contenedor de detalle para garantizar coherencia en pantallas grandes. |
| **Accesibilidad** (`01-dashboard`) | Botón de refresco solo presentaba icono sin texto visible (resuelto parcialmente con accessibilityLabel, requiere tooltip explícito). | **P3** | Garantizar `help()` y `accessibilityLabel()` completos en todos los controles interactivos. |

---

## 3. Clasificación por Severidad
- **P0 (Bloqueantes / Crashes / Corrupción):** 0
- **P1 (Problemas estructurales de UX / Faltantes visuales clave / Contraste):** 4
- **P2 (Inconsistencias de layout / Tamaños sobredimensionados / Estados equívocos):** 5
- **P3 (Microdetalles / Tooltips):** 1
