# Índice Sistemático de Capturas de Pantalla — TankControl (HP Smart Tank Utility)

**Sesión de Auditoría:** `20260905-210520` (`latest`)  
**Entorno de Ejecución:** macOS 26.6.2 (Darwin Kernel 25.3.0, Apple Silicon M-Series ARM64)  
**Binario:** `research/builds/audit-clean/night-20260904/TankControl.app/Contents/MacOS/TankControl`  
**Dispositivo:** HP Smart Tank 500 series (USB VID: `0x03F0`, PID: `0x1454`)  
**Hardware Físico:** Desconectado / Offline al momento de la sesión (Estado reportado honestamente por la UI).

---

## 1. Capturas Principales — Tema Claro (Light Mode)

| Archivo | Descripción de la Pantalla | Estado Representado | Resolución | Enlace Relativo |
| :--- | :--- | :---: | :---: | :---: |
| `01-dashboard.png` | Panel General: Decisión rápida <10s, estado del equipo, acceso directo a tareas y vista de tinta | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/01-dashboard.png) |
| `02-print.png` | Impresión / Centro de Cola: Cola CUPS nativa (`HP_Smart_Tank_500`), URI, botón de cola y capacidades PPD | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/02-print.png) |
| `03-scanner.png` | Escáner CIS: Panel de control (Modo, Resolución 75-1200 DPI, Área, Formato, Destino), botones de acción y lienzo de vista previa | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/03-scanner.png) |
| `04-ink.png` | Niveles de Tinta: Tanques CISS continuo (K, C, M, Y), advertencia de honestidad física y estado vacío controlado | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/04-ink.png) |
| `05-maintenance.png` | Mantenimiento: Lista de rutinas mecánicas (Patrón, Limpieza N1/N2, Alineación) con botones protegidos por gating de hardware | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/05-maintenance.png) |
| `06-activity.png` | Actividad y Telemetría: Tarjetas estructuradas para odómetro de hardware e historial local de trabajos | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/06-activity.png) |
| `07-settings.png` | Configuración: Modal sheet nativo con tarjetas de Notificaciones, Desarrollo e Identidad de aplicación | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/07-settings.png) |
| `08-developer.png` | Modo Desarrollador: Descriptores de endpoints USB, estado de drivers y banco de pruebas de comandos | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/08-developer.png) |
| `09-about.png` | Acerca de: Logotipo de la app, versión semántica, build hash, disclaimer legal y créditos de autoría | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/09-about.png) |

---

## 2. Capturas Principales — Tema Oscuro (Dark Mode)

| Archivo | Descripción de la Pantalla | Estado Representado | Resolución | Enlace Relativo |
| :--- | :--- | :---: | :---: | :---: |
| `01-dashboard-dark.png` | Panel General en modo oscuro: Verificación de contraste en tarjetas translúcidas | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/01-dashboard-dark.png) |
| `02-print-dark.png` | Cola CUPS en modo oscuro: Legibilidad de URI técnica y badges de estado | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/02-print-dark.png) |
| `03-scanner-dark.png` | Escáner en modo oscuro: Pickers desplegables y lienzo de previsualización | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/03-scanner-dark.png) |
| `04-ink-dark.png` | Niveles de Tinta en modo oscuro: Contraste de íconos geométricos y tipografía | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/04-ink-dark.png) |
| `05-maintenance-dark.png` | Mantenimiento en modo oscuro: Separadores de lista agrupada y estilo de botones | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/05-maintenance-dark.png) |
| `06-activity-dark.png` | Actividad en modo oscuro: Tarjetas de contadores y tarjetas de historial | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/06-activity-dark.png) |
| `07-settings-dark.png` | Configuración en modo oscuro: Fondo translúcido con blur de material nativo | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/07-settings-dark.png) |
| `08-developer-dark.png` | Modo Desarrollador en modo oscuro: Bloques de código monoespaciado de alto contraste | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/08-developer-dark.png) |
| `09-about-dark.png` | Acerca de en modo oscuro: Jerarquía tipográfica y disclaimer legal | DISCONNECTED | 1720x1120 (860x560 @2x) | [Ver captura](round-2/09-about-dark.png) |

---

## 3. Estados Simulados de Hardware (Mock States)

| Archivo | Descripción del Estado | Estado Representado | Resolución | Enlace Relativo |
| :--- | :--- | :---: | :---: | :---: |
| `mock-low-ink.png` | Niveles CISS críticos (<10% en depósitos K, C, M, Y) con formas geométricas accesibles y badge púrpura | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-low-ink.png) |
| `mock-paper-empty.png` | Bandeja superior de entrada sin papel; banner de advertencia con instrucciones claras | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-paper-empty.png) |
| `mock-door-open.png` | Cubierta frontal de acceso a cabezales abierta; alerta de seguridad mecánica | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-door-open.png) |
| `mock-scanner-busy.png` | Escáner ocupado digitalizando; bloqueo preventivo de tareas concurrentes | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-scanner-busy.png) |
| `mock-busy.png` | Impresión PCL3GUI activa en cola; badge "• Ocupado" en toolbar sin truncamiento | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-busy.png) |
| `mock-timeout.png` | Falta de respuesta USB tras timeout de 5 segundos; banner de reconexión asistida | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-timeout.png) |
| `mock-error.png` | Error genérico de hardware con sugerencias paso a paso de resolución | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-error.png) |
| `mock-disconnected.png` | Estado desconectada/apagada explícito con guía de conexión física | MOCK STATE | 1720x1120 (860x560 @2x) | [Ver captura](round-2/mock-disconnected.png) |

---

## 4. Pruebas de Escalabilidad y Adaptabilidad de Ventana

| Archivo | Dimensión de Ventana | Estado Representado | Resolución | Enlace Relativo |
| :--- | :--- | :---: | :---: | :---: |
| `size-760x520.png` | Tamaño mínimo soportado (760 x 520 pt); verificación de ausencia de scroll horizontal o solapamientos | DISCONNECTED | 1520x1040 (760x520 @2x) | [Ver captura](round-2/size-760x520.png) |
| `size-900x650.png` | Tamaño ideal intermedio (900 x 650 pt); proporción áurea de espacio y respiración visual | DISCONNECTED | 1800x1300 (900x650 @2x) | [Ver captura](round-2/size-900x650.png) |
| `size-1200x800.png` | Tamaño grande / expandido (1200 x 800 pt); centrado simétrico equilibrado sin vacíos asimétricos | DISCONNECTED | 2400x1600 (1200x800 @2x) | [Ver captura](round-2/size-1200x800.png) |

---
*Generado automáticamente durante la sesión de auditoría visual de TankControl.*
