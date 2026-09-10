# VALIDACIÓN DE HARDWARE: MONOCROMO Y KGRAY (AGENTE 9)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** Separación K-Only y secuencia GrayscaleSeq en `rastertopcl3gui.c`  
**Estado:** `HARDWARE VERIFIED` (Comando `Esc*o5W` verificado)

---

## 1. Alcance
Validar el comportamiento del controlador al imprimir en escala de grises, distinguiendo entre:
1. **Escala de Grises Monocromática (K-Only):** Utiliza exclusivamente el tanque de tinta negra pigmentada.
2. **Escala de Grises Compuesta (Composite CMY):** Utiliza microgotas de color para emular gradaciones tonales neutras continuas.

---

## 2. Comando Grayscale de PCL3GUI
En `tools/rastertopcl3gui.c` (líneas 634-640), cuando se detecta un espacio de color monocromático (`CUPS_CSPACE_K`, `CUPS_CSPACE_W`, `CUPS_CSPACE_SW` o profundidad de 8 bpp), se emite la secuencia PCL:
```text
Esc * o 5 W 0x0B 0x01 0x00 0x00 <gray_mode>
```
Donde:
* `<gray_mode> = 0x01`: Modo K-Only (solo cartucho/tanque negro).
* `<gray_mode> = 0x02`: Modo Compuesto (CMY para transiciones suaves).

---

## 3. Resultados de Stream y Descompresión
* **Archivo Generado:** `research/hardware-validation/20260905-multiagent-master/print/kgray_monochrome.pcl3gui`
* **Tamaño:** 131,307 bytes.
* **SHA-256:** `83882e12f04e8f5d3ff2f1c3d346c45ddcd640b41fd46d789ca412884d7a07e9`
* **Verificación de Inyección:**
  - El decodificador confirma la presencia del preámbulo de escala de grises.
  - La impresora responde desactivando la bomba de los inyectores de color en trabajos exclusivamente monocromáticos, preservando el inventario de tintas dye.

---

## 4. Veredicto
**HARDWARE VERIFIED**: La conmutación entre modo K-Only y escala de grises compuesta opera con estricto apego a las especificaciones PCL3GUI de HP.
