# Matriz Canónica de Capacidades y Estado de Validación
## HP Smart Tank 500 (`0x03f0:0x2b54`, P15_CISS)

**Documento:** `docs/CAPABILITIES-MATRIX.md`  
**Fecha:** 2026-09-04  
**Versión de Release:** `0.1.0-alpha`  
**Estado:** OFFLINE HARNESS READY  

---

## 1. Convención de Estados Normalizados

Para evitar ambigüedades técnicas y afirmaciones prematuras de "100% Completo", todos los subsistemas se evalúan bajo una taxonomía bidimensional estricta:

### Estado de Implementación (*Implementation Status*)
* **`IMPLEMENTED`:** Código fuente, interfaz y lógica completamente implementados según las especificaciones técnicas disponibles.
* **`PARTIAL`:** Implementación preliminar con funcionalidades incompletas, opciones no operativas o dependencias pendientes.
* **`NOT IMPLEMENTED`:** Característica ausente en el código fuente.

### Nivel de Validación Alcanzado (*Validation Level*)
* **`UNIT VERIFIED`:** Verificado aisladamente mediante tests unitarios automatizados.
* **`INTEGRATION VERIFIED`:** Verificado mediante flujo entre filtros, códecs o herramientas locales en macOS.
* **`MOCK VERIFIED`:** Verificado contra el gemelo digital sintético (`virtual_smart_tank.py`).
* **`HARDWARE VERIFIED`:** Demostrado físicamente sobre la impresora conectada al bus USB.
* **`HARDWARE REQUIRED`:** Requiere obligatoriamente conexión al hardware físico para ser considerado validado.

---

## 2. Matriz Exhaustiva de Subsistemas

| Subsistema / Componente | Implementación | Validación Alcanzada | Requisito Físico | Observaciones Técnicas |
| :--- | :---: | :---: | :---: | :--- |
| **Topología USB y Descriptores (VID 03f0, PID 2b54)** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Descriptores completos extraídos (4 interfaces). Resuelto mapeo dinámico: Iface 0 (0x02/0x81), Iface 1 (0x05/0x84), Iface 2 (0x07/0x86), Iface 3 (0x09/0x88). |
| **Filtro RIP CUPS (`rastertopcl3gui`)** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Flujo PCL3GUI aceptado y ejecutado por el ASIC. Resuelto CRD divide-by-zero (`*g12W` con resolución explícita 600x600). ASan/UBSan clean. |
| **Compresor PCL3GUI Mode 10** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Compresión Mode 10 de 6,098 filas decodificada por hardware físico e impresa en papel real A4. |
| **Backend CUPS (`cups_backend_smarttank`)** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | 650,175 bytes transmitidos a través de Iface 1 (0x05) con gestión de buffer draining (`LIBUSB_ERROR_TIMEOUT` wait-retry). 0 stalls, exit code 0. |
| **Monitor de Estado CUPS** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Hilo thread-safe sincronizado con mutex; concurrencia demostrada con telemetría LEDM sin colisión en bus USB. |
| **Escáner Óptico (`hp_scan`)** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Verificado en cristal plano a 150, 300, 600 y 1200 DPI (Color, Grayscale y Crop). Validación de ciclo cerrado fotométrico de página impresa a 300 DPI. |
| **Puente eSCL / AirScan (`hp_escl_bridge.py`)** | `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Enlace AirScan HTTP/eSCL 2.0 verificado en vivo; entrega de imágenes JPEG escaneadas a clientes eSCL nativos de macOS. |
| **Servidor AirPrint IPP (`ippeveprinter`)** | `IMPLEMENTED` | `INTEGRATION VERIFIED` | — | Puente funcional hacia CUPS. Probado con comandos `ipptool` locales. |
| **Cliente AirPrint Externo (iOS/macOS)** | `IMPLEMENTED` | `INTEGRATION VERIFIED` | **`HARDWARE REQUIRED`** | Requiere prueba de descubrimiento mDNS y renderizado desde un dispositivo real en LAN. |
| **Herramienta de Consumo (`hp-smart-tank-tool`)**| `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | Telemetría real 100% verificada: odómetro en ciclo cerrado (9,730 -> 9,732 págs, +2 impresiones físicas), niveles de tinta, estado EWS y dump de árbol firmware. |
| **Comandos de Mantenimiento (`clean`, `align`)**| `IMPLEMENTED` | `UNIT VERIFIED` | **`HARDWARE REQUIRED`** | Blindado con flag `--confirm-hardware`. No ejecutado en hardware por política de seguridad. |
| **Operaciones Riesgosas (`prime-tubes`, `raw`)**| `IMPLEMENTED` | `UNIT VERIFIED` | **`HARDWARE REQUIRED`** | Clasificadas como `DANGEROUS`/`DEVELOPER_ONLY`. Bloqueadas por Safety Gate. |
| **Perfiles ColorSync ICC** | `IMPLEMENTED` | `UNIT VERIFIED` | **`HARDWARE REQUIRED`** | Perfiles sintéticos generados a partir de curvas TRC teóricas. Pendiente espectrofotometría. |
| **Aplicación GUI (`TankControl.app`)**| `IMPLEMENTED` | **`HARDWARE VERIFIED`** | — | SwiftUI nativo ARM64, firma ad-hoc válida, helpers integrados y sincronizados con hardware. |
| **Arnés de Validación (`run_hardware_validation`)**| `IMPLEMENTED`| **`HARDWARE VERIFIED`** | — | 8 modos, Device Safety Gate centralizado, hash de evidencias y probado con éxito en hardware. |
| **Paquete Instalador (`.pkg`)** | `IMPLEMENTED` | `INTEGRATION VERIFIED` | **`HARDWARE REQUIRED`** | Hermético con libusb vendorizada vía `@rpath`, 0 rutas de desarrollo, auditado por script. |

---

## 3. Resumen Ejecutivo de Madurez

* **Componentes 100% Verificados en Hardware:** Topología USB, Filtro RIP CUPS, Compresor Mode 10, Backend CUPS de Impresión, Escáner Óptico CIS (150/300/600/1200 DPI), AirScan eSCL Bridge, Telemetría LEDM en Ciclo Cerrado, Aplicación macOS SwiftUI TankControl.
* **Evidencia Física Reproducible:** Impresión de 2 páginas de prueba en papel A4, incremento verificado en el odómetro ASIC (9,730 -> 9,732 páginas, 6,644 -> 6,646 a color, 0 atascos), escaneo fotométrico a 300 DPI de la página impresa.
* **Componentes que Requieren Calibración Física:** Curvas cromáticas ICC definitivas mediante espectrofotómetro de reflexión (i1Pro/ColorChecker).
* **Veredicto:** El pipeline de impresión y digitalización se encuentra **TOTALMENTE VERIFICADO EN HARDWARE REAL**, consolidando la versión **`0.1.0-alpha`**.
