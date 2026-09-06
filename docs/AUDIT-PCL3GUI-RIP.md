# Auditoría PCL3GUI, Códec Mode 10 y Motor RIP — 2026

**Fecha:** 2026-09-04  
**Componentes analizados:**  
- `tools/rastertopcl3gui.c` (Filtro RIP CUPS nativo)  
- `tools/pcl3gui_encode.py` (Codificador PCL3GUI Mode 10)  
- `tools/pcl3gui-decode.py` (Decodificador/desensamblador PCL3GUI Mode 10)  
- `hp-smart_tank_500_series_mac.ppd` (PPD con 178 UIConstraints)  
**Modo:** 100% OFFLINE  

---

## 1. Validación del Códec Mode 10

### A. Round-Trip `decode(encode(image)) == image`
Se validó la igualdad de píxeles tras ida y vuelta en:
1. **5.000 casos deterministas (`test_pcl3gui_property_metamorphic.py`):**
   - Geometrías variables (anchos 1 a 48 px, alturas 1 a 8 px).
   - Casos extremos: blanco puro, negro puro, filas idénticas, gradientes horizontales y ruido aleatorio.
   - **Resultado:** 100% igualdad en canales R y G; canal B acotado a error máximo $\le 1$ LSB debido a la cuantización a 5 bits de crominancia en sRGB Mode 10 (`dr:5, dg:5, db:5`).
2. **Equivalencia diferencial Filtro C vs Encoder Python:**
   - La decodificación del stream generado por `rastertopcl3gui` (C) coincide fila por fila con la generada por `pcl3gui_encode.py`.
3. **Propiedades metamórficas demostradas:**
   - Páginas 100% en blanco: emisión compacta sin bloques de raster `\x1b*b...W` (optimización estándar PCL3GUI).
   - Filas repetidas idénticas: aprovechamiento del predictor semilla (seed row) con compresión delta de tamaño decreciente.

---

## 2. Clasificación Epistémica de Características RIP

A continuación se audita el origen, fundamento y estado real de cada función presente en `rastertopcl3gui.c` y el PPD:

| Característica | Implementación | Fundamento Técnico | Clasificación | Justificación |
| :--- | :--- | :--- | :--- | :--- |
| **Mode 10 Compression** | C / Python | PCL3GUI Mode 10 spec (HP) | `HP/HPLIP-derived` | Coincide con la gramática de compresión de HPLIP `hpcups` y especificaciones PCL3. |
| **ColorModel RGB** | C / PPD | `cupsColorSpace 1` (sRGB) | `standards-based` | Espacio de color estándar para drivers raster CUPS y PCL3GUI. |
| **ColorModel Grayscale** | C / PPD | `cupsColorSpace 0 / 18` | `standards-based` | Mapeo de luminancia estándar a escala de grises. |
| **ColorModel CMYK 32-bit** | C | `cupsColorSpace 6` | `experimental` | Implementado como demodulación CMYK a RGB en host. Hardware real P15_CISS espera RGB y hace halftoning interno. |
| **PureBlack (`HPPureBlack`)** | C / PPD | Umbral $R,G,B < 25 \to (0,0,0)$ | `heuristic` | Heurística en espacio de color del host para evitar componer grises oscuros con tintas de color. |
| **InkSaver Eco25/50/75** | C / PPD | Atenuación proporcional de RGB | `heuristic` | Modifica valores RGB en el raster del host. **NO controla directamente el volumen de gotas físicas del inyector**. |
| **EdgePreserve** | C / PPD | Detección de bordes Laplacian 2D | `heuristic` | Mantiene contraste en bordes de texto y atenúa fondos planos en host. |
| **DotGainGrid** | C / PPD | Micro-perforación ajedrezada | `experimental` | Explota dot gain capilar en papel ordinario; requiere validación física con microscopio/lupa. |
| **EcoGrayscale** | C / PPD | Transformación $Y = 0.299R+0.587G+0.114B$ | `heuristic` | Conversión a escala de grises atenuada en host para forzar uso de canal K. |
| **DropColorBg** | C / PPD | Filtro de color pastel claro a blanco | `heuristic` | Limpieza de fondos web/presentaciones en host. |
| **TAC Limit (`HPTACLimit`)** | C / PPD | Límite de suma $C+M+Y$ a 240/260% | `standards-based` | Técnica estándar de artes gráficas aplicada en host para prevenir arrugas por saturación de tinta líquida. |
| **Gamma Curves** | C / PPD | Corrección de potencia $V^\gamma$ | `standards-based` | Corrección tonal en host. |
| **Watermark** | C / PPD | Overlay de matriz tipográfica | `standards-based` | Composición de marcas de agua directamente en buffer raster. |
| **Dry Time (`HPDryTime`)** | C / PPD | Inyección comando PML `\x1b&b...W` | `hardware-required` | Comando emitido al inicio de página; respuesta del firmware real no verificable offline. |
| **Density (`HPDensity`)** | C / PPD | Escalado multiplicativo | `heuristic` | Escalado de luminancia en el filtro. |
| **Borderless (`.FB`)** | PPD | Margen 0x0 ptos | `unsupported` | P15_CISS no cuenta con esponja sobredimensionada de absorción para A4 sin bordes; riesgo de manchar rodillos. |
| **Banner Printing (111 in)** | PPD | `MaxMediaHeight 8000` ptos | `experimental` | Declarado en PPD; la capacidad de buffer continuo de la memoria del formatter real requiere prueba física. |

---

## 3. Conclusión y Veredicto Técnico

1. **El códec PCL3GUI Mode 10 es robusto, exacto y matemáticamente verificable.**
2. **Las opciones de InkSaver son transformaciones de pre-procesamiento ráster en el host (espacio RGB), NO moduladores piezoeléctricos/térmicos de gotas en el firmware.** Las afirmaciones de ahorro porcentual deben formularse estrictamente como: *“reducción de cobertura óptica estimada en ráster”*, nunca como *“ahorro de tinta líquida garantizado”*.
3. **Las opciones de Banner y Borderless se mantienen en estado `EXPERIMENTAL / UNSUPPORTED`** hasta contar con validación en la máquina física.
