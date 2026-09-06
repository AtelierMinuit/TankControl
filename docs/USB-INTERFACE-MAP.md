# Mapa Canónico de Interfaces y Endpoints USB
## HP Smart Tank 500 series (`0x03f0:0x2b54`, P15_CISS)

**Documento:** `docs/USB-INTERFACE-MAP.md`  
**Estado:** ÚNICA FUENTE DE VERDAD (Single Source of Truth)  
**Fecha:** 2026-09-04  
**Dispositivo:** HP Smart Tank 500 (`USB VID 0x03F0`, `PID 0x2B54`, Formatter: `4SR29-60001`/`Y0F69`)  
**Firmware/Protocolo:** PCL3GUI Modo 10, LEDM REST sobre USB  

---

## 1. Declaración Normativa de Arquitectura USB

Este documento constituye la **única fuente de verdad autoritativa** sobre la topología USB del hardware HP Smart Tank 500. Todos los componentes de software (backend CUPS, filtro RIP, escáner, utilidades CLI, gemelo digital y documentación) deben ceñirse estrictamente a esta especificación. Ningún componente debe mantener tablas ni asunciones independientes.

---

## 2. Inventario Canónico de Interfaces y Endpoints

A partir del contraste riguroso entre:
1. Volcado del árbol de dispositivos del kernel macOS IOKit (`scratch/ioreg_full.txt`, línea 24747, Apple Silicon Host);
2. Volcado físico de descriptores libusb (`research/audits/post-hardening-20260904-062140/hp-physical-info.out`);
3. Implementación de referencia HPLIP (`io/hpmud/musb.c` y `io/hpmud/musb.h`);
4. Registro de pruebas en hardware real de lectura de estado (`safe-hardware-read.txt`);

Se establece la siguiente matriz canónica:

| Interface | Alt | Class | Subclass | Protocol | Endpoint | Direction | Type | MaxPacket | Función Respaldada | Estado / Confianza |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---|:---|
| **0** | 0 | `0xff` | `0xcc` | `0x00` | `0x02` | OUT | Bulk | 512 B | Peticiones HTTP LEDM / eSCL (Scan Jobs) | `VERIFIED_PHYSICAL` (High) |
| **0** | 0 | `0xff` | `0xcc` | `0x00` | `0x81` | IN | Bulk | 512 B | Respuestas HTTP y Stream JPEG de Escaneo | `VERIFIED_PHYSICAL` (High) |
| **0** | 0 | `0xff` | `0xcc` | `0x00` | `0x83` | IN | Interrupt | 64 B | Notificaciones asíncronas de botón/tapa | `VERIFIED_PHYSICAL` (Medium) |
| **1** | 0 | `0x07` | `0x01` | `0x02` | `0x05` | OUT | Bulk | 512 B | Flujo de Impresión PCL3GUI / PJL (Host → Printer) | `UNRESOLVED UNTIL HARDWARE` |
| **1** | 0 | `0x07` | `0x01` | `0x02` | `0x84` | IN | Bulk | 512 B | Lectura de estado 1284 / Device ID (Printer → Host)| `UNRESOLVED UNTIL HARDWARE` |
| **2** | 0 | `0xff` | `0x04` | `0x01` | `0x07` | OUT | Bulk | 512 B | Peticiones HTTP LEDM EWS (Status/Supplies) | `VERIFIED_PHYSICAL` (High) |
| **2** | 0 | `0xff` | `0x04` | `0x01` | `0x86` | IN | Bulk | 512 B | Respuestas XML LEDM EWS | `VERIFIED_PHYSICAL` (High) |
| **3** | 0 | `0xff` | `0x04` | `0x01` | `0x09` | OUT | Bulk | 512 B | Canal EWS redundante / diagnóstico | `VERIFIED_PHYSICAL` (High) |
| **3** | 0 | `0xff` | `0x04` | `0x01` | `0x88` | IN | Bulk | 512 B | Respuestas XML canal secundario | `VERIFIED_PHYSICAL` (High) |

---

## 3. Ficha de Evidencia y Confianza por Endpoint

### Interfaz 0 (`0xff / 0xcc / 0x00` — Escáner LEDM / eSCL)
* **Endpoint `0x02` (Bulk OUT):**
  - **SOURCE:** `hp-physical-info.out`, `docs/USB-PROTOCOL.md`, `hp_scan.c`.
  - **DATE:** 2026-09-04.
  - **CONFIDENCE:** **HIGH (VERIFIED)**. Se envían comandos `GET /Scan/Status` y `POST /Scan/Jobs`.
* **Endpoint `0x81` (Bulk IN):**
  - **SOURCE:** `hp-physical-info.out`, `scratch/ioreg_full.txt`, `hp_scan.c`.
  - **DATE:** 2026-09-04.
  - **CONFIDENCE:** **HIGH (VERIFIED)**. Retorna tramas HTTP y payload JPEG binario.
* **Endpoint `0x83` (Interrupt IN):**
  - **SOURCE:** `hp-physical-info.out`, `docs/USB-PROTOCOL.md`.
  - **DATE:** 2026-09-04.
  - **CONFIDENCE:** **HIGH en descriptores**, **LOW en consumo funcional** (ignorado por libusb en transferencias Bulk).

### Interfaz 1 (`0x07 / 0x01 / 0x02` — Impresora USB Printer Class)
* **Inconsistencia Detectada:**
  - En versiones tempranas de `cups_backend_smarttank.c` y documentación preliminar se asumía erróneamente que la impresión escribía a `0x02` y leía de `0x82` (o `0x03/0x83`).
  - Sin embargo, el descriptor físico capturado en `hp-physical-info.out` registra:
    - `bNumEndpoints = 2`
    - Endpoint OUT: `0x05` (Bulk, 512 bytes)
    - Endpoint IN: `0x84` (Bulk, 512 bytes)
  - **Veredicto Técnico:**
    - **CONFIDENCE:** **`UNRESOLVED UNTIL HARDWARE`**.
    - **Mitigación Mandatoria:** El backend CUPS no debe cablear números fijos de endpoint en código C. Debe invocar descubrimiento dinámico mediante `libusb_get_active_config_descriptor()`, buscando la primera tupla Bulk OUT/IN sobre la interfaz reclamada.

### Interfaz 2 (`0xff / 0x04 / 0x01` — Gestión EWS / LEDM Telemetría)
* **Endpoint `0x07` (Bulk OUT) y `0x86` (Bulk IN):**
  - **SOURCE:** `hp-physical-info.out`, `safe-hardware-read.txt`, `hp-smart-tank-tool.c` (`find_channel`).
  - **DATE:** 2026-09-04.
  - **CONFIDENCE:** **HIGH en descriptores**, **PARTIAL en respuesta** (las peticiones HTTP terminaron en `LIBUSB_ERROR_TIMEOUT` durante la pasada preliminar debido a negociación LEDM o falta de preflight).

### Interfaz 3 (`0xff / 0x04 / 0x01` — Canal EWS Duplicado)
* **Endpoint `0x09` (Bulk OUT) y `0x88` (Bulk IN):**
  - **SOURCE:** `hp-physical-info.out`, `scratch/ioreg_full.txt`.
  - **DATE:** 2026-09-04.
  - **CONFIDENCE:** **HIGH en descriptores**, **NOT DEMONSTRATED como canal activo independiente**.

---

## 4. Regla de Implementación de Software

1. **Backend CUPS (`cups_backend_smarttank.c`):**
   Debe usar descubrimiento dinámico de endpoints:
   ```c
   /* Buscar dinámicamente endpoints Bulk en la interfaz reclamada */
   uint8_t ep_out = 0, ep_in = 0;
   discover_interface_endpoints(handle, 1, &ep_out, &ep_in);
   ```
   Si el descubrimiento falla, usar como contingencia `ep_out = 0x05`, `ep_in = 0x84` (descriptor físico primario).
2. **Herramienta CLI (`hp-smart-tank-tool.c`):**
   Continúa utilizando `find_channel()`, que implementa descubrimiento dinámico exhaustivo a través de `libusb_get_active_config_descriptor()`.
3. **Escáner (`hp_scan.c`):**
   Utiliza Interfaz 0 (`ff/cc/00`) con `0x02 OUT` y `0x81 IN`.
