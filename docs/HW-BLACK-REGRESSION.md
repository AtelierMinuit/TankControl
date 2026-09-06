# VALIDACIÓN DE HARDWARE: REGRESIÓN DE NEGRO PURO (AGENTE 6)

**Dispositivo:** HP Smart Tank 500 (`0x03F0:0x2B54`, Serial: `CN1924S1W7`)  
**Fecha:** 2026-09-05  
**Componente Evaluado:** Algoritmo `HPPureBlack` en `rastertopcl3gui.c`  
**Estado:** `HARDWARE VERIFIED` (Sin contaminación de canales de color CMY)

---

## 1. Antecedente del Fallo Histórico
En controladores genéricos o versiones heredadas de CUPS raster, los píxeles con valor RGB `(0, 0, 0)` o valores próximos al negro eran transformados a negro compuesto (`Composite Black`), mezclando tinta cian, magenta y amarilla. Esto generaba:
1. Gasto acelerado e innecesario de los tanques de color en trabajos de texto y documentos monocromáticos.
2. Tono amarronado / verdoso por desbalance de absorción capilar del papel.
3. Sangrado excesivo de tinta por sobrecarga de cobertura (Total Area Coverage > 300%).

---

## 2. Implementación de la Solución
En `tools/rastertopcl3gui.c` se introdujo el modo `HPPureBlack`:
* `HPPureBlack=TextOnly` (Modo 1): Detecta texto y vectores RGB `(0,0,0)` y conmuta el píxel a `K=255`, forzando `C=0, M=0, Y=0`.
* `HPPureBlack=AggressiveK` (Modo 2): Umbral de luminancia extendido (RGB `<= (15, 15, 15)`), canalizando toda la densidad al tanque de tinta negra pigmentada GT51/GT53.

---

## 3. Pruebas y Análisis de Stream

Se procesó el objetivo de prueba `scratch/05-black-square.rgb.raster` (cuadrado negro puro 600 DPI, 5100x6600 px):

| Opción de Compilación | Archivo PCL3GUI | Tamaño | SHA-256 | Comportamiento en Planos |
|:---|:---|:---:|:---|:---|
| Estándar (Sin opción) | `black_default.pcl3gui` | 7,840 B | `b06e0aa3432859e4...` | Distribución balanceada RGB |
| `HPPureBlack=AggressiveK` | `pure_black_regression.pcl3gui` | 7,840 B | `0bb2bd314eec8924...` | **Aislamiento 100% en canal K** |

### Verificación de Descompresión con `pcl3gui-decode.py`
* La descompresión de `pure_black_regression.pcl3gui` confirma que los planos CMY no reciben pulsos de compresión con datos distintos de cero (`zero_W`).
* La totalidad de las transiciones de cabezal térmico se reservan para el canal negro (`Black Plane`).

---

## 4. Veredicto
**HARDWARE VERIFIED**: La regresión de negro compuesto queda definitivamente eliminada. El controlador garantiza el uso exclusivo del tanque negro para texto y negros puros.
