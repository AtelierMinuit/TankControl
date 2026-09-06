# Corpus diferencial PCL3GUI — Ejecución y decodificación offline

Fecha de actualización: 2026-09-02 / 2026-09-03.
Entorno: macOS Apple Silicon (ARM64). Ejecución 100% offline sin envío al hardware.

## Estado de reproducibilidad actual

La tabla conserva resultados de una ejecución anterior, pero los archivos binarios de salida (`.pcl`, `.pcl3`, `.stream` o `.bin`) no están presentes actualmente en `research/` ni `scratch/`. Los dos ejecutables de referencia siguen presentes (`research/builds/hpcups_arm64` y `research/builds/hpcups_instrumented_arm64`), pero eso no permite reconstruir por sí solo cada hash de la tabla. En consecuencia, esta tabla se clasifica como **EVIDENCIA HISTÓRICA / NO REPRODUCIDA EN EL ESTADO ACTUAL** hasta regenerar y conservar el corpus con sus manifiestos SHA-256.

La ausencia de los streams no invalida el análisis de código ya documentado, pero impide afirmar que cada comparación byte a byte pueda repetirse hoy.

## Regeneración mínima reproducida — 2026-09-04 07:06

Se regeneró un caso desde `scratch/05-black-square.rgb.raster` y se conservaron los artefactos en `research/builds/audit-clean/re-corpus-20260904-070649/`. La invocación HPLIP requiere `PPD=<ruta>`; sin esa variable el filtro devuelve código 2 y no produce stream. Con el PPD correcto, ambos filtros terminaron correctamente:

| Salida | Bytes | SHA-256 | Estado |
|---|---:|---|---|
| HPLIP `hpcups_instrumented_arm64` | 6.996 | `0cc4697afa1e4648281a2a91171a25f8606b39161bfdf17e518789f10db1f2b5` | reproducido |
| Filtro nativo `rastertopcl3gui` | 7.840 | `59a1492f6998e2301c72f808eb1b51295d5b774ce7805a052da5a6774eebcfb4` | reproducido |

El comparador independiente encontró diferencias en PJL, inicialización y bloques raster; ambos streams contienen 593 bloques `W`, pero no son byte a byte equivalentes. El decoder reconoce ambos y reporta 518 bloques `W` de longitud cero. Esto demuestra compatibilidad estructural offline, no equivalencia completa ni aceptación física del firmware. El trace HPLIP registra `crd=color_only`, `mode10=1` y `mode9=0`, evidencia directa del camino seleccionado por esa build.

## Método

1. Insumos PDF generados con figuras vectoriales calibradas (`01-white` a `14-trace`).
2. Rasterización mediante `cupsfilter -m application/vnd.cups-raster` usando el PPD de la HP Smart Tank 500 series (`ColorModel=RGB`, espacio `CUPS_CSPACE_RGBW = 17` a 600/1200 dpi).
3. Conversión a PCL3GUI mediante `research/builds/hpcups_arm64` y la versión instrumentada `research/builds/hpcups_instrumented_arm64`.
4. Decodificación semántica e inversa mediante `tools/pcl3gui-decode.py`.

## Inventario y Resultados del Decoder

| Test | PDF (B) | Raster (B) | PCL3GUI (B) | SHA256 (PCL3GUI) | Dimensiones | Resolución | Resultado Decoder |
|---|---|---|---|---|---|---|---|
| 01-white | 583 | 134641800 | 1191 | `e313f3499c0c...` | 5100x74 | 600 dpi | Página blanca / 0 comandos |
| 02-black-pixel | 615 | 134641800 | 1363 | `107ed1e9ece6...` | 5100x102 | 600 dpi | Página blanca / 0 comandos (*) |
| 03-black-horizontal | 622 | 134641800 | 1288 | `a55fe3226125...` | 5100x83 | 600 dpi | Página blanca / 0 comandos (*) |
| 04-black-vertical | 620 | 134641800 | 9235 | `a283d61462a1...` | 5100x1674 | 600 dpi | Página blanca / 0 comandos (*) |
| 05-black-square | 618 | 134641800 | 3822 | `4efa480e1926...` | 5100x593 | 600 dpi | Página blanca / 0 comandos (*) |
| 06-red-square | 616 | 134641800 | 3829 | `9373e430f5f9...` | 5100x593 | 600 dpi | BBox 500x500 @ (2300,3050), color=(254, 0, 0) |
| 07-green-square | 618 | 134641800 | 3834 | `a6cdab4f4687...` | 5100x592 | 600 dpi | BBox 500x500 @ (2300,3050), color=(0, 255, 0) |
| 08-blue-square | 617 | 134641800 | 3835 | `86b17a24b25f...` | 5100x593 | 600 dpi | BBox 500x500 @ (2300,3050), color=(0, 0, 254) |
| 09-grayscale | 612 | 134641800 | 3832 | `00b682359294...` | 5100x594 | 600 dpi | BBox 500x500 @ (2300,3050), color=(128, 128, 128) |
| 10-gradient-steps | 716 | 134641800 | 3861 | `ad06a04a6566...` | 5100x594 | 600 dpi | BBox 500x500 @ (2466,3050), 3 niveles reconstruidos |
| 11-a4-borderless | - | 139215672 | 41509 | `add03fcfa56d...` | 4962x7014 | 600 dpi | BBox 4962x7014 @ (0,0), overbleed 140px |
| 11-a4-full | 712 | 132587512 | 40532 | `e2a76520947d...` | 4822x6874 | 600 dpi | BBox 4822x6874 @ (0,-4), estándar A4 |
| 12-normal600 | - | 128168200 | 9600 | `1e240c8eef5e...` | 4960x1538 | 600 dpi | BBox 3900x851 @ (530,1518), 600 dpi |
| 12-photo1200 | - | 512667400 | 20300 | `30703e13965b...` | 9920x3074 | 1200 dpi | BBox 7800x1701 @ (1060,3036), 1200 dpi (2x exacto) |
| 13-best | - | 128168200 | 10369 | `7a65e130a542...` | 4960x1461 | 600 dpi | BBox 2500x1717 @ (1230,2618), calidad Best |
| 13-normal | - | 128168200 | 10377 | `70c9d84c5ce4...` | 4960x1461 | 600 dpi | BBox 2500x1717 @ (1230,2618), calidad Normal |
| 14-trace-black.inst | - | - | 3819 | `3f10114e3aba...` | 5100x593 | 600 dpi | Página blanca / 0 comandos (*) |
| 14-trace-red.inst | - | - | 3828 | `7a70ef0fcd55...` | 5100x593 | 600 dpi | BBox 500x500 @ (2300,3050), idéntico a build ref |

(*) **Descubrimiento crítico sobre negro puro en RGBW:**
En los tests con negro puro (02 a 05 y 14-black), el decoder reporta página blanca porque `HPCupsFilter::extractBlackPixels()` detecta `white == 0` y traslada el píxel a `kRaster`, reemplazando el canal RGB por blanco puro `(0xFF, 0xFF, 0xFF)`. Posteriormente, `Pcl3Gui2` opera con `crd_type = eCrd_color_only`, omitiendo el plano negro por completo.

## Validación Inversa contra CUPS Raster

Se ejecutó la validación inversa comparando el raster de entrada con la reconstrucción generada por el decoder:
- **07-green-square**: RMSE = 0.0000 (coincidencia binaria bit-a-bit exacta).
- **09-grayscale**: RMSE = 0.0000 (coincidencia binaria bit-a-bit exacta).
- **06-red-square**: RMSE = 0.57735 = $1/\sqrt{3}$ (explicado al 100% por cuantización de 1 bit en el canal rojo 255 vs 254).
- **08-blue-square**: RMSE = 0.57735 = $1/\sqrt{3}$ (explicado al 100% por omisión obligatoria del bit menos significativo de azul en Mode 10: $255 \to 254$).
