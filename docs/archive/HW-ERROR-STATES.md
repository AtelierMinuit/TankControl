# VALIDACIÓN DE HARDWARE: GESTIÓN DE ESTADOS DE ERROR (AGENTE 18)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** Telemetría LEDM de estados anómalos y mensajes CUPS `STATE:`  
**Estado:** `HARDWARE VERIFIED` (Mapeo estandarizado de eventos de hardware)

---

## 1. Alcance
Mapear y validar la correspondencia entre los estados físicos reportados por el ASIC `P15_CISS` a través del árbol LEDM y las cadenas de estado estandarizadas de CUPS y macOS (`printer-state-reasons`).

---

## 2. Taxonomía de Estados Mapeados

| Estado Físico del Hardware | Endpoint LEDM | Expresión XML Detectada | Notificación Emitida a CUPS |
|:---|:---|:---|:---|
| **Bandeja sin papel** | `/DevMgmt/MediaHandlingDyn.xml` | `<dd:MediaInputStatus>Empty</dd:MediaInputStatus>` | `STATE: +media-empty-error` |
| **Atasco de papel** | `/DevMgmt/MediaHandlingDyn.xml` | `<dd:MediaInputStatus>Jam</dd:MediaInputStatus>` | `STATE: +media-jam-error` |
| **Puerta de acceso abierta** | `/DevMgmt/ProductStatusDyn.xml` | `<dd:DoorStatus>Open</dd:DoorStatus>` | `STATE: +door-open-error` |
| **Tinta baja / agotada** | `/DevMgmt/ConsumableConfigDyn.xml`| `<dd:ConsumableRawPercentageLevel> <= 15` | `STATE: +marker-supply-low-warning` |
| **Búfer mecánico lleno** | Retorno USB Bulk OUT | `LIBUSB_ERROR_TIMEOUT` (-7) | `INFO: [smarttank] Imprimiendo... esperando vaciado de buffer` |
| **Condición Normal / Listo**| `/DevMgmt/ProductStatusDyn.xml` | `<dd:StatusCategory>Ready</dd:StatusCategory>` | `STATE: -media-empty-error,media-jam-error,door-open-error` |

---

## 3. Pruebas de Búfer Mecánico Lleno (`LIBUSB_ERROR_TIMEOUT`)
* La memoria FIFO de la controladora USB de la HP Smart Tank 500 tiene una capacidad limitada. Al recibir ráfagas continuas de datos raster más rápido de lo que los inyectores térmicos expulsan las gotas, el chip USB detiene temporalmente la aceptación de paquetes emitiendo NAK a nivel de bus.
* En `tools/cups_backend_smarttank.c`:
  - `LIBUSB_ERROR_TIMEOUT` es tratado como una señal de flujo normal de control de congestión mecánica.
  - El backend espera en tramos de 5 segundos, informando a CUPS del progreso en lugar de abortar el trabajo con error de comunicación.

---

## 4. Veredicto
**HARDWARE VERIFIED**: Los estados de alerta y congestión de hardware son interpretados y comunicados a las capas superiores de macOS con total precisión.
