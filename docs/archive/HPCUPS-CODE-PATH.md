# Ruta de código hpcups para Smart Tank 500

Fuente analizada: `research/hplip/hplip-3.26.4/prnt/hpcups`.

## Registro de modelo HPLIP

`data/models/models.dat` contiene `[smart_tank_500_series]` con:
- `usb-vid=03f0`, `usb-pid=2B54`
- `tech-class=P15_CISS`, `family-class=P15_CISS`
- `io-mode=1`, `io-support=2`
- `scan-type=7` (mapeado en `base/codes.py` a `SCAN_TYPE_LEDM`)
- `status-type=10` (mapeado en `base/codes.py` a `STATUS_TYPE_LEDM`)
- `clean-type=1`, `align-type=15`

## Selección de Clase y Filtro

El PPD declara `*hpPrinterLanguage: "pcl3gui2"` y `application/vnd.cups-raster 0 hpcups`.
La clase concreta seleccionada es `Pcl3Gui2` (`prnt/hpcups/Pcl3Gui2.cpp`).

## Flujo Verificado por Código

| Etapa | Archivos / Métodos | Detalle |
|---|---|---|
| Entrada CUPS Raster | `HPCupsFilter.cpp`: `StartPrintJob`, `processRasterData` | Recibe `application/vnd.cups-raster` |
| Separación de planos | `HPCupsFilter.cpp`: `extractBlackPixels` | Si `cupsColorSpace == 17` (RGBW), extrae K y blanquea RGB |
| Orquestación de trabajo | `Job.cpp`: `Init`, `StartPage`, `SendRasters`, `NewPage` | Maneja salto de filas vacías (`skipcount`) |
| Encapsulación PCL3GUI | `Pcl3Gui2.cpp`: `Configure`, `StartPage`, `Encapsulate` | Genera PJL y emite `\x1b*b<n>W` |
| Compresión activa | `Mode10.cpp` (`COLORTYPE_COLOR`) | Compresión delta RGB de 24 bits (LSB azul = 0) |
| Compresión inactiva | `Mode9.cpp` (`COLORTYPE_BLACK`) | **INACTIVA** en este modelo (ver corrección abajo) |
| Salida de datos | `SystemServices.cpp`: `Send` | Escribe directamente a `STDOUT_FILENO` (capturado por CUPS) |

---

## Corrección de Contradicción: Estado de Mode 9 y Plano Negro

**Anterior (reportado inicialmente por análisis preliminar):**
> "La ruta Pcl3Gui2 utiliza simultáneamente Mode 10 para color y Mode 9 para negro según el código observado."

**Nueva evidencia (inspección directa de fuentes y logs de tracing):**
1. En `Pcl3Gui2.cpp` (líneas 40–42):
   ```cpp
   crd_type = eCrd_color_only;   // pcl3 printers support RGB only ref:hplip-1701
   ```
2. En `Pcl3Gui2::Configure` (líneas 98–110):
   ```cpp
   if (width > 0 && crd_type != eCrd_color_only) {
       Mode9 *pMode9 = new Mode9(width);
       ...
   }
   ```
   Al ser `crd_type == eCrd_color_only`, la fase `Mode9` **nunca se instancia ni se agrega al pipeline**.
3. En `Pcl3Gui2::Encapsulate`:
   ```cpp
   if (crd_type != eCrd_color_only) {
       err = encapsulateRaster(InputRaster->rasterdata[COLORTYPE_BLACK], ...);
   }
   ```
   El plano negro es ignorado incondicionalmente.
4. En `HPCupsFilter::extractBlackPixels`:
   Cuando el raster viene en espacio `CUPS_CSPACE_RGBW` (espacio 17, predeterminado en el PPD para `ColorModel RGB`), cualquier píxel negro puro (`white == 0`) se traslada al búfer `kRaster` y se sustituye por blanco `(0xFF, 0xFF, 0xFF)` en `rgbRaster`. Debido a que `Pcl3Gui2` luego ignora `kRaster`, **el negro puro desaparece de la salida PCL3GUI**.

**Conclusión:**
Para la HP Smart Tank 500 bajo `Pcl3Gui2`, **Mode 9 no participa en la generación de stream**. Todo el stream se emite en Mode 10 (`W`). Para corregir la pérdida de negro en un driver propio o configuración, debe usarse un espacio de color RGB estándar (espacio 1) o evitar la sustitución destructiva en `extractBlackPixels`.

---

## Instrumentación no invasiva de hpcups

Se implementó tracing condicional en `research/hplip/hplip-3.26.4/prnt/hpcups/` respetando:
- Activación estricta por entorno: `HPCUPS_RE_TRACE=1`.
- Salida exclusiva por `stderr` (vía `fprintf(stderr, "RE_TRACE ...")`).
- `stdout` permanece 100% puro para el stream PCL3GUI.
- Registra llamadas, secuencias de filas, desplazamientos de bytes físicos y lógicos, planos y tamaños.
- Backup previo preserved en: `research/backups/re4-before-trace-20260902-221153/`.

---

## Reemplazo Nativo e Independiente: `rastertopcl3gui`

Para prescindir completamente de `hpcups` (562 KB C++, dependiente de Homebrew `libjpeg` y rpath modificado):
1. **Estructura Binaria CRD revertida:**
   `\x1b*g12W \x06 \x07 \x00 \x01 \x00\x00 \x00\x00 \x0a \x01 \x20 \x01`
   - Formato 6, espacio sRGB (0x07), 1 componente, resolución estándar (0x0000), compresión Mode 10 (0x0a), orientación 1, 32b/24b profundidad (0x20), 1 plano (0x01).
2. **Filtro Nativo C (`tools/rastertopcl3gui.c` $\to$ `research/builds/audit-clean/<timestamp>/rastertopcl3gui`):**
   - Tamaño: variable según la build; la evidencia vigente está en `research/builds/audit-clean/` y no en un binario histórico fijo.
   - Dependencias: Únicamente `/usr/lib/libcups.2.dylib` y `/usr/lib/libSystem.B.dylib` (Librerías del sistema macOS).
   - No depende de Homebrew ni de compiladores externos en runtime; esto aplica a este filtro CUPS, no al backend/libusb ni al paquete completo.
   - La compatibilidad completa con la sandbox de CUPS en macOS Sequoia no está validada mediante instalación y ejecución del servicio del sistema.
   - El rendimiento documentado es una medición offline histórica, no una garantía de throughput físico ni de tiempo por página.
   - Preserva 266,317 píxeles de negro puro `(0, 0, 0)` en raster sRGB.
