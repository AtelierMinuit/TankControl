# HP Smart Tank 500 — Especificación Técnica del Protocolo

Fecha de actualización: 2026-09-02 / 2026-09-03.

---

## 1. Tabla Maestra de Estado del Protocolo

| Área | Estado | Evidencia Principal |
|---|---|---|
| **USB descriptors** | VERIFICADO | VID `03f0`, PID `2b54`, cuatro interfaces y endpoints documentados en el snapshot; el número de serie se omite deliberadamente. |
| **USB print interface** | PARCIAL | Interfaz 1 (`07/01/02`) USB Printer Class bidireccional según descriptores; el flujo de impresión física aún no está validado. |
| **USB scan interface** | VERIFICADO | Interfaz 0 (`ff/cc/00`), mapeada a `HPMUD_S_LEDM_SCAN` / `FD_ff_cc_0` en `musb.c`. |
| **USB status interface** | PARCIAL | Interfaces 2/3 (`ff/04/01`) responden de forma desfasada/cruzada en el probe sólo lectura; no se consideran canales independientes. |
| **PJL framing** | VERIFICADO | UEL `\x1b%-12345X`, `@PJL SET STRINGCODESET=UTF8`, `@PJL ENTER LANGUAGE=PCL3GUI`, `@PJL EOJ`. Verificado en streams y en `Encapsulator.cpp`. |
| **PCL3GUI framing** | VERIFICADO | Configuración `\x1b&l...`, raster header `\x1b*r1A`, raster end `\x1b*rC`, salto vertical `\x1b*p<n>Y` / `\x1b*b<n>Y`, bloques `\x1b*b<n>W`. |
| **Mode 10** | VERIFICADO | Compresor de 24 bits RGB contra fila semilla implementado en `Mode10.cpp`. Decodificador independiente `tools/pcl3gui-decode.py` verificado matemáticamente (24 tests unitarios e integrados). |
| **Mode 9** | PARCIAL | Compresor de bytes delta/RLE analizado en `Mode9.cpp`. Verificado que está **INACTIVO** en el pipeline de la Smart Tank 500 (`crd_type = eCrd_color_only`). |
| **Raster geometry** | VERIFICADO | Geometría 600 dpi (5100x6600, A4 4822x6874) y 1200 dpi (9920x3074, 2x exacto). Borderless A4 expande 140 píxeles horizontales y verticales (overbleed de ~0.116"). |
| **Color encoding** | VERIFICADO | Formato RGB chunky de 24 bits. El bit menos significativo del canal azul se trunca a 0 en la codificación de Mode 10. |
| **Compression** | VERIFICADO | Compresión diferencial predictiva con 4 selectores de origen (Nuevo, Oeste, Noreste, Color en Caché), literales, RLE y Short Delta. |
| **Status** | PARCIAL | Se obtuvo HTTP/XML real de `/DevMgmt/ProductStatusDyn.xml`, pero la respuesta no es determinista entre lecturas y no permite afirmar integración estable. |
| **LEDM** | VERIFICADO | Endpoints REST `/Scan/ScanCaps`, `/Scan/Status`, `/Scan/Jobs`, `/Jobs/ScanJobs/<id>` documentados en `bb_ledm.c`, en `HPLEDMScan.bundle` y en `node-hp-scan-to`. |
| **Scanning** | VERIFICADO | Protocolo eSCL / LEDM encapsulado en HTTP sobre USB (`ff/cc/00`). Implementado con puente local `tools/hp_escl_bridge.py` y validado en suite con 4 tests unitarios. |
| **Maintenance** | EXPERIMENTAL | Hay endpoints y comandos heredados mapeados en código, pero no se ejecutan durante esta auditoría por riesgo mecánico y no existe validación física. |
| **Ink levels** | EXPERIMENTAL | El esquema aparece en fuentes y gemelo digital; la lectura física de consumibles sigue desincronizada/no determinista y no valida niveles. |

---

## 2. Protocolo de Escaneo LEDM sobre USB

La interfaz 0 (`ff/cc/00`) transporta peticiones HTTP/1.1 sin autenticación:
- **`GET /Scan/ScanCaps`**: Obtiene documento XML con resoluciones ópticas, áreas máximas/mínimas de cama plana y formatos soportados (RAW/JPEG).
- **`GET /Scan/Status`**: Monitorea el estado del escáner (`<ScannerState>Idle</ScannerState>`, `<AdfState>Empty</AdfState>`).
- **`POST /Scan/Jobs`**: Envía XML `<ScanSettings>` con `XResolution`, `YResolution`, `Format` (JPEG), `ColorSpace` (Color8/Gray8) y bounding box.
- **`GET /Jobs/ScanJobs/<id>`**: Consulta el progreso hasta `<PageState>ReadyToUpload</PageState>`.
- **`GET /Jobs/ScanJobs/<id>/Pages/1`**: Transfiere el flujo de bytes de la imagen escaneada (JPEG o RAW).

---

## 3. Especificación del Codec PCL3GUI Mode 10

Mode 10 es un compresor diferencial para imágenes RGB de 24 bits.
- Cada comando comienza con 1 byte:
  - **Bit 7**: `0` = Literal, `1` = RLE.
  - **Bits 6–5**: Selector de píxel:
    - `00` (`0x00`): Nuevo píxel (codificado explícitamente a continuación).
    - `01` (`0x20`): Predictor Oeste (copia del píxel `x - 1` de la fila actual).
    - `10` (`0x40`): Predictor Noreste (copia del píxel `x + 1` de la fila semilla anterior).
    - `11` (`0x60`): Color en Caché (reutiliza el último color registrado en caché).
  - **Bits 4–3**: Desplazamiento relativo respecto a la fila semilla (`0..2`, o `3` con bytes VLI adicionales).
  - **Bits 2–0**: Cantidad de reemplazo (para Literal: `c + 1`; para RLE: `c + 2`; `7` activa extensión aditiva VLI).
- **Codificación de Píxeles Nuevos**:
  - Si el bit 7 del primer byte es `1`: **Short Delta** (2 bytes: 5 bits dR, 5 bits dG, 5 bits dB*2 respecto al píxel norte).
  - Si el bit 7 del primer byte es `0`: **Píxel crudo** (3 bytes: 23 bits de datos RGB desplazados a la izquierda por 1; el bit 0 de azul se descarta).

---

## 4. Estado de la Impresión y el Backend de Apple

- El registro previo de que CUPS reportó `Job Completed` indica que el spooler completó la canalización hacia el backend `/usr/libexec/cups/backend/usb`.
- Esto **no garantiza** la interpretación por parte del hardware si el stream contiene discrepancias de color (como el bug de blanqueo de negro puro en RGBW documentado en `docs/HPCUPS-CODE-PATH.md`) o si el canal USB entra en estado de buffer lleno/stall.
- La confirmación física requiere observación de alimentación de papel o lectura del canal de retorno USB.
