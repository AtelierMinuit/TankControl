# Comparación cruzada de modelos HP — auditoría 2026

Fecha de inspección local: 2026-09-04. Esta comparación no transfiere capacidades de un modelo a otro sin evidencia específica.

| Familia/modelo | Evidencia disponible | Arquitectura/alcance | Aplicabilidad a Smart Tank 500 |
|---|---|---|---|
| Smart Tank 500 series | USB local VID/PID `03f0:2b54`; cuatro interfaces enumeradas; backend discovery `smarttank://`; HPLIP 3.26.4 contiene PPD y entrada de modelo coincidentes | evidencia directa del dispositivo y fuente HPLIP local | alta para identificación; impresión/escaneo de nuestro controlador aún no probado |
| Smart Tank 510/515/530 | referencias de búsqueda HPLIP y PPD históricos; no se encontró payload local verificable en esta auditoría | comparación documental, no hardware | no demostrada |
| Ink Tank 310/410 | PPD históricos disponibles en repositorios de terceros; sin equivalencia binaria local demostrada | familias ink-tank relacionadas | no demostrada |
| ENVY/DeskJet 7100 | referencia externa a PPD/familias HPLIP; sin código compartido local demostrado | otros modelos HP | no demostrada |
| HP Easy Scan instalado | `/Applications/HP Easy Scan.app` contiene ejecutables Mach-O `x86_64`; no se observaron cadenas verificables `Smart Tank 500`, `P15_CISS`, `LEDM`, `eSCL` o `HPMUD` en los ejecutables inspeccionados | software HP existente, no parte del paquete del proyecto | sólo evidencia de dependencia/compatibilidad potencial; no reutilizado |
| PPD HP instalados | No hay coincidencia instalada en macOS, pero sí existe PPD HPLIP local para Smart Tank 500 en `research/hplip/hplip-3.26.4/ppd/hpcups/` | comparación directa disponible en fuente HPLIP, no instalada en macOS | alta para PPD HPLIP; no prueba nuestra integración |
| HPLIP Printer Application | [OpenPrinting HPLIP Printer Application](https://github.com/OpenPrinting/hplip-printer-app) documenta uso de recursos HPLIP/PPD y capa IPP/PAPPL | fuente externa arquitectónica | no prueba capacidades específicas del modelo |

## Conclusiones

- No se encontró un driver HP local ARM64 que pueda servir como base directa para este paquete.
- Se encontró un PPD HPLIP local coincidente para Smart Tank 500, además de una entrada de modelo con VID/PID y clase `P15_CISS`; esto fortalece la identificación, pero no prueba equivalencia de nuestro filtro ni de las rutas físicas.
- La presencia de un PPD o de un modelo cercano no demuestra que el firmware Smart Tank 500 acepte las mismas longitudes, medios, modos de tinta o comandos de mantenimiento.
- `Mode10`, `P15_CISS`, la separación K/CMY, los límites TAC y los comandos PML permanecen sujetos a evidencia específica del modelo o validación física.

## Evidencia HPLIP específica reproducida

El PPD HPLIP declara `hpPrinterLanguage: pcl3gui2`, `ColorDevice: True`, `1284DeviceID: MFG:HP;MDL:smart tank 500 series;` y `cupsFilter: application/vnd.cups-raster 0 hpcups`. La entrada `smart_tank_500_series` de `data/models/models.dat` declara USB `03f0:2b54`, `tech-class=P15_CISS`, `scan-type=7`, `status-type=10`, `align-type=15` y `clean-type=1`. Son datos de HPLIP 3.26.4: no autorizan ejecutar mantenimiento ni copiar `hpcups` al paquete propio.

## Inventario binario local reproducido — 2026-09-04

| Componente | Arquitectura observada | SHA-256 | Dependencias relevantes | Aplicabilidad |
|---|---|---|---|---|
| `/Library/Printers/hp/cups/filters/hpcups` | arm64 | `38999b321448a54498c80ab8efdc104daaa5c010a945ef81b6c1fce03b4afdf3` | `libjpeg.8.dylib`, libcups, libcupsimage, libc++, libSystem | Evidencia del filtro HP instalado; no se reutiliza como código fuente del controlador propio |
| `HPDeviceModel.framework/Versions/4.0/HPDeviceModel` | i386 + x86_64 | `da0664041d8a38c70899e2209efeda74d2523525fa7f4084458126345b2afe18` | HTTP, IPP, Core, DataStore y frameworks HP | Binario heredado; no nativo arm64 |
| `HPDM.framework/Versions/5.0/HPDM` | x86_64 | `0474c03dd4c86eba54603fe9dcb58d42a48cc10e71dcd1439b7c7c64d852ca48` | Axis2, `libnetsnmp`, IOBluetooth | Binario heredado; no nativo arm64 |
| `HP Easy Scan.app/Contents/MacOS/HP Easy Scan` | x86_64 | `03fe9ed77409ca340dbf3c4a134d38a49cc84641081feb67c7afd602c23f6ee2` | ImageCaptureCore, HPScanCaptureMgr | Aplicación auxiliar instalada; capacidad específica Smart Tank no establecida |

`ghidra`, `analyzeHeadless` y Hopper no están disponibles en el host auditado. Esta pasada documenta arquitectura, hashes y dependencias observables, pero no afirma descompilación ni equivalencia de código entre modelos. La evidencia heredada tampoco autoriza copiar frameworks HP al paquete propio.
- El ejecutable HP Easy Scan local es `x86_64`; no se instala ni se enlaza desde este proyecto y no se asume compatibilidad nativa Apple Silicon.

## Límites y trazabilidad

Las fuentes externas y sus fechas están registradas en `docs/EXTERNAL-SOURCES-2026.md`. Los artefactos locales no se modificaron durante esta inspección; los hashes completos y números de serie se omiten de esta documentación para minimizar exposición innecesaria.
