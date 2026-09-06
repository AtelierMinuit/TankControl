# Análisis Estructural y Semántico PCL3GUI

## Herramientas de Análisis

1. `tools/pcl3gui-inspect.py`: Inspección básica de cabeceras ASCII, parámetros PJL y comandos ESC.
2. `tools/pcl3gui-decode.py`: Decodificador semántico independiente completo para PCL3GUI Mode 10. Reconstruye la geometría, colores y bounding box a partir de los bytes comprimidos, y genera imágenes PPM completas.
3. `tools/compare-streams.py`: Comparador de alineación de streams, entropía, regiones de control (PJL, inicialización PCL, raster, tráiler) y bloques coincidentes.

---

## Verificación Semántica de Mode 10

El decodificador independiente `tools/pcl3gui-decode.py` valida rigurosamente las siguientes estructuras:
- **Parseo de bloques**: Localización de `ESC*r1A` (comienzo), comandos `ESC*p<n>Y` (posicionamiento absoluto), `ESC*b<n>Y` (salto de filas vacías), bloques de datos `ESC*b<n>W` (Mode 10), y `ESC*rC` (fin de raster).
- **Decodificación fila por fila**: Mantenimiento de fila semilla (`seedRow`), actualización diferencial con `payload == 0` (fila idéntica a la anterior sin costo en bytes).
- **Mapeo cromático y geométrico**:
  - Cuadrados de 500x500 píxeles a 600 dpi ubicados en `(2300, 3050)` decodificados con precisión absoluta de coordenadas: `x in [2300, 2800)`, `y in [3050, 3550)`.
  - Conteo exacto de 250,000 píxeles para Rojo, Verde, Azul y Gris.
  - Validación de gradiente con 3 niveles reconstruidos.

---

## Pruebas Automatizadas del Decoder

La suite de pruebas en `tests/test_pcl3gui_decode.py` cubre 24 casos automatizados:
1. **Fila individual Mode 10**: Literales con y sin extensión VLI, RLE con extensión, predictores Oeste y Noreste, color en caché, píxeles crudos y Short Delta.
2. **Robustez del parser**: Detección y rechazo de streams incompletos, comandos desconocidos y bloques truncados con excepciones explícitas `DecodeError`.
3. **Integración con corpus**: Verificación de geometría y color en figuras básicas, páginas en blanco y gradientes.
4. **Resoluciones y medios**: Verificación de escalamiento 600 dpi vs 1200 dpi (duplicación exacta de ancho de 4960 a 9920 píxeles) y margen extendido borderless (+140 píxeles en ancho y alto).
5. **Validación inversa**: Comparación bit a bit del raster de entrada vs la reconstrucción del decoder, verificando RMSE = 0.0000 para verde y gris, y un error acotado a 1 bit de cuantización para azul y rojo.
