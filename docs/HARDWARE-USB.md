# Información de Hardware y Mapeo USB — HP Smart Tank 500

## Sistema Operativo y Host
* **OS:** macOS 26.6.2 (Apple Silicon / ARM64)
* **Controlador Host:** `AppleT8132USBXHCI`

## Identificación de Dispositivo USB
* **Fabricante:** HP (Vendor ID: `0x03F0` / 1008)
* **Producto:** Smart Tank 500 series (Product ID: `0x2B54` / 11092)
* **Número de Serie:** omitido deliberadamente en documentación compartida
* **Versión USB:** USB 2.0 (`bcdUSB=512`), Full Speed (12 Mbps)
* **Configuraciones:** 1 (`bConfigurationValue=1`)
* **Interfaces activas:** 4

---

## Mapeo de Interfaces Verificado por Descriptores y Código Fuente

> [!NOTE]
> **Única Fuente de Verdad:** Para la especificación canónica, tabla de endpoints, niveles de confianza y resolución de inconsistencias, consultar [`docs/USB-INTERFACE-MAP.md`](USB-INTERFACE-MAP.md).

A partir de la correlación entre `scratch/ioreg_full.txt` y la tabla de descriptores de transporte HPLIP (`io/hpmud/musb.c` y `io/hpmud/musb.h`):

| Interfaz | Clase | Subclase | Protocolo | Endpoints | Mapeo Interno HPLIP | Función Demostrada |
|---:|---:|---:|---:|---:|---|---|
| **0** | `0xff` | `0xcc` | `0x00` | 3 | `FD_ff_cc_0` (`HPMUD_S_LEDM_SCAN`, `HPMUD_ESCL_SCAN_CHANNEL`) | **Escaneo LEDM / eSCL vía HTTP sobre USB** |
| **1** | `0x07` | `0x01` | `0x02` | 2 | `FD_7_1_2` (`HPMUD_S_PRINT_CHANNEL`) | **Impresión estándar USB Printer Class bidireccional** |
| **2** | `0xff` | `0x04` | `0x01` | 2 | `FD_ff_4_1` (`HPMUD_EWS_LEDM_CHANNEL`) | **EWS REST; respuestas físicas no deterministas** |
| **3** | `0xff` | `0x04` | `0x01` | 2 | `FD_ff_4_1` | **Interfaz duplicada; no demostrada como canal independiente** |

### Evidencia en HPLIP (`io/hpmud/musb.c`):
- Línea 110: Asocia la tupla `(0xff, 0xcc, 0x00)` al descriptor `FD_ff_cc_0`.
- Líneas 1544–1546:
  ```c
  case HPMUD_LEDM_SCAN_CHANNEL:
  case HPMUD_ESCL_SCAN_CHANNEL:
      fd = FD_ff_cc_0;
      break;
  ```
- Línea 1530: Asocia `HPMUD_EWS_LEDM_CHANNEL` con `FD_ff_4_1` (`0xff, 0x04, 0x01`).

---

## Estado Actual de Conexión

Durante el sondeo pasivo con `usb-descriptor-inventory` e `ioreg -p IOUSB` a las 22:54, el dispositivo no respondió en el bus activo (posible estado de reposo profundo, apagado físico o cable desconectado).
