# Ingeniería inversa USB — HP Smart Tank 500 series

Estado de esta ficha: evidencia reproducida en macOS Apple Silicon el 2026-09-04. Describe descriptores y correlaciones con HPLIP; no inventa comandos ni respuestas que no hayan sido capturados.

## Identificación

| Campo | Valor | Estado |
|---|---|---|
| Vendor ID | `0x03f0` (HP) | VERIFICADO en enumeración USB |
| Product ID | `0x2b54` (Smart Tank 500 series) | VERIFICADO en enumeración USB |
| USB | 2.0, Full Speed | VERIFICADO en snapshot de descriptores |
| Configuración | 1, `bConfigurationValue=1` | VERIFICADO |
| IEEE-1284 | `MFG:HP;MDL:Smart Tank 500 series;` | VERIFICADO en referencia HPLIP; no recapturado en esta sesión |

## Interfaces y endpoints observados

Los endpoints siguientes proceden del inventario USB reproducido y se correlacionan con las tuplas usadas por `io/hpmud/musb.c`. La dirección `IN`/`OUT` es relativa al host.

| Interfaz | Clase/subclase/protocolo | Endpoints observados | Correlación HPLIP | Función respaldada |
|---:|---|---|---|---|
| 0 | `ff/cc/00` | `0x81 IN`, `0x02 OUT`, `0x83 IN` | `FD_ff_cc_0`, `HPMUD_LEDM_SCAN_CHANNEL` / `HPMUD_ESCL_SCAN_CHANNEL` | Transporte de escaneo LEDM/eSCL sobre USB |
| 1 | `07/01/02` | `0x84 IN`, `0x05 OUT` | `FD_7_1_2`, `HPMUD_S_PRINT_CHANNEL` | Impresión USB Printer Class / PCL3GUI |
| 2 | `ff/04/01` | `0x86 IN`, `0x07 OUT` | `FD_ff_4_1`, `HPMUD_EWS_LEDM_CHANNEL` | EWS/LEDM; respuesta física no establecida |
| 3 | `ff/04/01` | `0x88 IN`, `0x09 OUT` | misma tupla | Interfaz adicional; no demostrada como canal independiente |

No se ha obtenido en el snapshot una captura fiable de `wMaxPacketSize`, alternates, strings completas ni transferencias de control. Esos campos quedan como VACÍO, no como “compatibles por defecto”.

## Pruebas físicas seguras reproducidas

- La enumeración y `info` identifican el dispositivo.
- Discovery del backend produce `smarttank://HP/Smart%20Tank%20500%20series`.
- `status`, `supplies`, `odometer`, `scan-caps` y `scan-status` terminan en `LIBUSB_ERROR_TIMEOUT` sin XML válido.
- No se ejecutaron limpieza, alineación, reset de waste-ink, firmware, RFU/FUL ni escrituras experimentales.

Por tanto, el mapa USB está **VERIFICADO a nivel de descriptores**, mientras que la bidireccionalidad de estado y escaneo está **PARCIAL**. Un timeout no prueba que el endpoint sea incorrecto; tampoco prueba que el protocolo esté implementado correctamente.

## Correlación con HPLIP

La fuente local `research/hplip/hplip-3.26.4/io/hpmud/musb.c` asocia `ff/cc/00` con LEDM/eSCL, `07/01/02` con impresión y `ff/04/01` con EWS/LEDM. Esta es una referencia de implementación, no una captura de bytes de la Smart Tank 500.

## Próxima captura necesaria

Para convertir esta ficha en una especificación independiente hacen falta capturas byte a byte, fuera del flujo normal de producción y con autorización específica: descriptor completo, una consulta segura LEDM, una respuesta de estado y un trabajo mínimo de impresión. Hasta entonces, los comandos, framing y respuestas se clasifican como IMPLEMENTADOS/REFERENCIA o SIMULACIÓN según el documento que los cite, no como protocolo físico probado.
