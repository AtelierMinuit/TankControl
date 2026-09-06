# Matriz de pruebas profesional — auditoría 2026

Regla: `PASS` sólo significa que la prueba indicada se observó con la evidencia correspondiente. Un mock, una respuesta HTTP o un job CUPS completado no equivale a `PASS` de hardware.

Actualización 2026-09-04 06:10: la ejecución vigente terminó en **133/133 PASS**; el cliente HTTP USB también rechaza respuestas truncadas.

Última ejecución de suite: `python3 -m unittest discover -s tests`: **131/131 PASS**. También pasó contra la build explícita `research/builds/audit-clean/20260904-061000` mediante `HP_AUDIT_BUILD_DIR`. Incluye 2.000 round-trips property-based Mode10 con seed `20260904`, pruebas eSCL fragmentadas/chunked y regresiones de seguridad de locks USB, temporales privados, salida explícita del scanner, bridge local, confirmación de hardware, propagación de errores LEDM, sanitización de logs, ausencia de XML eSCL completo en logs, temporales ICC privados, wrapper, icono, calibración, gemelo digital HTTP y cliente HTTP USB; la suite no sustituye los casos físicos marcados `NOT TESTED` o `FAIL`.

Actualización 2026-09-04: `hp_scan` recompiló tras ajustar el encuadre LEDM de HP (`0\r\n\r\n` y cabeceras de sesión). La reproducción física segura más reciente confirma discovery e inventario USB, pero `status`, `supplies` y `odometer` devuelven `LIBUSB_ERROR_TIMEOUT` (código 1); no se creó trabajo ni se ejecutó mantenimiento.

Actualización adicional 2026-09-04: el backend CUPS enumeró físicamente el dispositivo y devolvió una URI `smarttank://`. Las lecturas seguras `status`, `supplies` y `odometer` siguieron fallando con respuesta ausente o timeout; el discovery no eleva ninguna prueba física a `PASS`.

## Impresión

| Caso | Offline | Integración CUPS | Hardware | Estado | Evidencia |
|---|---:|---:|---:|---|---|
| A4 negro | PASS | PASS | NOT TESTED | PARCIAL | filtro y job A4 62; hoja no observada |
| A4 color | PASS | NOT TESTED | NOT TESTED | NOT TESTED | sin trabajo físico específico |
| Letter | PASS | NOT TESTED | NOT TESTED | NOT TESTED | sin trabajo físico específico |
| Legal | PASS | NOT TESTED | NOT TESTED | NOT TESTED | PPD lo declara; firmware no validado |
| 4×6 foto | PASS | NOT TESTED | NOT TESTED | NOT TESTED | PPD lo declara; sin impresión física |
| 5×7 foto | PASS | NOT TESTED | NOT TESTED | NOT TESTED | PPD lo declara; sin impresión física |
| grayscale / black-only | PASS | NOT TESTED | NOT TESTED | EXPERIMENTAL | separación física no demostrada |
| normal / best / photo | PASS | NOT TESTED | NOT TESTED | EXPERIMENTAL | parámetros raster; firmware no validado |
| borderless | PASS | NOT TESTED | NOT TESTED | EXPERIMENTAL | PPD/filtro; sin confirmación física |

## Documentos y raster

| Caso | Offline | Integración | Hardware | Estado | Evidencia |
|---|---:|---:|---:|---|---|
| PDF/texto/foto | PASS | NOT TESTED | NOT TESTED | PARCIAL | corpus offline |
| gradientes/transparencia | PASS | NOT TESTED | NOT TESTED | PARCIAL | corpus offline |
| 100 páginas | PASS | PASS | NOT TESTED | PARCIAL | corpus CUPS Raster sintético de 100 páginas; filtro informó 100 páginas y mantuvo memoria máxima ~5,8 MiB |
| Mode10 encode/decode | PASS | PASS | NOT TESTED | VERIFICADO | decoder y corpus |
| Mode10 sanitizer mutation | PASS | n/a | n/a | VERIFICADO | 100.000 rondas ASan/UBSan |

## Escáner / eSCL

| Caso | Offline/mock | Hardware | Estado | Evidencia |
|---|---:|---:|---|---|
| capacidades | PASS | PASS | PARCIAL | XML real, 75–1200 DPI |
| estado Idle | PASS | PASS | PARCIAL | XML real; no captura |
| captura 75 DPI 100×100 gris | PASS | FAIL | ROTO | respuesta USB desincronizada |
| 150/300/600/1200 DPI | PASS | NOT TESTED | NOT TESTED | sin capturas válidas |
| preview/crop/color | PASS | NOT TESTED | NOT TESTED | bridge mock |
| jobs concurrentes | PASS | NOT TESTED | PARCIAL | 24 jobs locales, IDs únicos; 7/7 pruebas eSCL |
| DELETE y limpieza temporal | PASS | NOT TESTED | PARCIAL | mock y código inspeccionados |

| auditoría waste-ink | PASS (mock explícito) | FAIL/NOT AVAILABLE | PARCIAL | modo real sin contador físico devuelve código 1 |

## Fallos y recuperación

| Caso | Test offline/mock | Hardware | Estado |
|---|---:|---:|---|
| impresora apagada | PASS | NOT TESTED | NOT TESTED |
| cable desconectado | PASS | NOT TESTED | NOT TESTED |
| papel agotado / tapa abierta | PASS | NOT TESTED | NOT TESTED |
| cancelación CUPS | NOT TESTED | NOT TESTED | NOT TESTED |
| reconexión USB | NOT TESTED | NOT TESTED | NOT TESTED |
| dos trabajos consecutivos | PASS | NOT TESTED | NOT TESTED |
| impresión + status simultáneos | PARCIAL | NOT TESTED | PARCIAL |

## Criterio de cierre

Esta matriz no autoriza `RC1`: quedan pendientes pruebas físicas de salida, captura, fallos USB, cancelación, reconexión, consumibles y concurrencia de transporte.

Ejecución física nocturna adicional (2026-09-04): `status`, `supplies` y `odometer` no recibieron datos del dispositivo y devolvieron código 1. Resultado: `FAIL/NOT TESTED`, no `PASS`.

Lectura física posterior: `hp_smart_tank.py scan-caps` y `scan-status` devolvieron código 1 con `Error leyendo respuesta HTTP USB (-7)`; `hp-smart-tank-tool info` sí enumeró la impresora y las cuatro interfaces. No se creó ningún trabajo de escaneo.
