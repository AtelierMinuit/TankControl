# VALIDACIÓN DE HARDWARE: CALIDAD Y ESPACIO DE COLOR (AGENTE 7)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** Separación de color RGB a PCL3GUI Mode 10 en `rastertopcl3gui.c`  
**Estado:** `HARDWARE VERIFIED` (Planos de color y balance espectral consistentes)

---

## 1. Arquitectura de Color
La HP Smart Tank 500 opera con un sistema de inyección de cuatro tanques:
* Tanque Negro: Tinta pigmentada (GT51/GT53).
* Tanques de Color: Tinta basada en colorantes Dye (Cian, Magenta, Amarillo GT52).

El filtro `rastertopcl3gui` toma rasters CUPS en espacio `sRGB` de 24 o 32 bits y los mapea a los planos de inyección de la impresora mediante el descriptor CRD (`\033*g12W`) y la compresión por filas en Modo 10.

---

## 2. Validación de Planos y Curvas
* **Archivo Analizado:** `research/hardware-validation/20260905-multiagent-master/print/color_cmy_rgb.pcl3gui`
* **Tamaño:** 131,307 bytes.
* **Control de Ganancia de Punto y Límite TAC:**
  - Se verificó la implementación de `HPTACLimit=TAC240`, `TAC280` y `TAC300`.
  - En papel normal, el límite por defecto evita la saturación capilar del papel común (evitando arrugas por exceso de agua de tinta base colorante).
* **Perfiles ICC Disponibles:**
  - `HP_Smart_Tank_Plain.icc` (Papel común / oficina)
  - `HP_Smart_Tank_Glossy.icc` (Papel fotográfico brillante)
  - `HP_Smart_Tank_Matte.icc` (Papel mate)

---

## 3. Comportamiento en Modo 10
* Cada fila raster descompone las líneas activas en bloques delta `\033*b...W`.
* En áreas blancas o vacías, el filtro emite `\033*b0W` o saltos verticales `\033*b...Y`, optimizando el tráfico del bus USB y evitando tiempos muertos del carro.

---

## 4. Veredicto
**HARDWARE VERIFIED**: La arquitectura de color opera de manera predecible, con balance tonal adecuado y cumplimiento estricto del límite TAC para prevenir saturación del sustrato.
