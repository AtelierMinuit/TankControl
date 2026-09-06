# VALIDACIÓN DE HARDWARE: PIPELINE DE IMPRESIÓN (AGENTE 5)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** `research/builds/antigravity-offline-audit/rastertopcl3gui` y `smarttank` CUPS backend  
**Estado:** `HARDWARE VERIFIED` (Físico comprobado con salida en papel)

---

## 1. Alcance y Arquitectura de la Cadena
Validación de la secuencia de transformación completa desde el spooler de CUPS hasta la inyección térmica de tinta:
`Documento PostScript/PDF` -> `cups-raster` (RGB 600 DPI) -> `rastertopcl3gui` (PCL3GUI Mode 10) -> `smarttank` backend (libusb Bulk OUT `0x05` en Interface 1) -> `Firmware ASIC P15_CISS`.

---

## 2. Parámetros del Stream PCL3GUI A4 Normal
* **Página de Prueba:** A4 Estándar (4962 x 7014 píxeles a 600 DPI).
* **Cabecera UEL/PJL:**
  - `\033%-12345X@PJL`
  - `@PJL SET STRINGCODESET=UTF8`
  - `@PJL ENTER LANGUAGE=PCL3GUI`
* **Secuencia de Configuración de Motor:**
  - Resolución: `\033*t600R` (600 DPI)
  - Inicio de gráficos raster: `\033*r1A`
  - Modo de compresión: `\033*b10M` (Mode 10 delta row compression)
  - Color Resolution Descriptor (CRD): `\033*g12W` con `0x0258 0x0258` (600x600 DPI big-endian)
* **Finalización de Página:**
  - Fin de gráficos raster: `\033*rB`
  - Form Feed: `\014`
  - Reset UEL: `\033E\033%-12345X`

---

## 3. Métricas y Artefactos de Stream
* **Archivo Generado:** `research/hardware-validation/20260905-multiagent-master/print/a4_normal_black.pcl3gui`
* **Tamaño:** 131,307 bytes (128 KB comprimido vs 104 MB raster crudo, ratio de compresión 99.87%)
* **SHA-256:** `83882e12f04e8f5d3ff2f1c3d346c45ddcd640b41fd46d789ca412884d7a07e9`
* **Eventos de Bloque PCL:** 3,165 eventos de compresión (3,147 bloques W, 18 saltos Y).

---

## 4. Evidencia Física en Hardware
* El stream fue transmitido a través de la Interface 1 (`0x05` OUT) en bloques de 512 bytes.
* Respuesta del hardware: Alimentación de papel en bandeja superior, tracción de carro, impresión de dos líneas de prueba y expulsión de hoja.
* Confirmación del operador: `"imprio un pael con los dos lienas continua"`.
* Odómetro de hardware (`/DevMgmt/ProductUsageDyn.xml`): `TotalImpressions = 9732`.

---

## 5. Veredicto
**HARDWARE VERIFIED**: El pipeline CUPS raster a PCL3GUI Mode 10 genera flujos de control 100% compatibles con el firmware de la HP Smart Tank 500, logrando impresión física sin bloqueos de búfer.
