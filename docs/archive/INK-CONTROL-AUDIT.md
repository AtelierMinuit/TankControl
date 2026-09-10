# Auditoría de control de tinta

Fecha: 2026-09-04. Alcance: código actual y pruebas offline; sin medición física.

El código del filtro fue revisado para que los comentarios de `InkSaver` describan atenuación raster nominal, no “volumen de tinta”, y para que `GrayscaleSeq` no se presente como control de inyectores de hardware.

Benchmark offline adicional sobre el mismo raster de prueba (`05-black-square.rgb.raster`): `Off`, `Eco25`, `Eco50` y `Eco75` produjeron 7.840 bytes PCL3GUI; `EdgePreserve` produjo 1.057.455 bytes y `DotGainGrid` 1.078.205 bytes. Los porcentajes informados por el filtro son reducción raster estimada, no mililitros de tinta ni ahorro físico medido.

Las opciones `HPDensity`, `HPInkSaver`, `DotGainGrid`, `EdgePreserve`, `HPTACLimit`, `HPPureBlack`, `CMYGray` y `KGray` modifican bytes RGB/gray/CMYK del CUPS Raster antes de codificar el plano PCL3GUI. No se demostró que seleccionen un volumen físico de tinta ni una separación firmware específica. En el camino activo observado en HPLIP, `Pcl3Gui2` usa CRD `color_only`; la existencia de una transformación K en el filtro no prueba emisión exclusiva por el inyector negro.

| opción | hecho verificable | clasificación |
|---|---|---|
| HPDensity | LUT sobre bytes raster | reducción/aumento raster; no medido físicamente |
| HPInkSaver Eco25/50/75 | atenuación aritmética por píxel | heurística offline; porcentajes físicos no demostrados |
| EdgePreserve | vecinos izquierda/derecha/arriba | heurística offline; no validada en papel |
| DotGainGrid | atenuación alternada por paridad | simulación heurística; riesgo de patrón visible |
| HPTACLimit | límite sobre CMY derivado de RGB | modelo incompleto; RGB no equivale a TAC CMYK |
| HPPureBlack/KGray/CMYGray | reescritura de valores de entrada | no prueba selección física de canales |

Las frases “ahorro real”, “50% de tinta”, “100% K” y equivalentes deben tratarse como no demostradas. La telemetría de ml/coste del CLI es estimación o mock, no medición gravimétrica ni contador firmware validado.
