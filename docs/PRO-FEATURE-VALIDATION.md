# Validación de funciones profesionales

| característica | implementada | offline | hardware | fuente | riesgo |
|---|---:|---:|---:|---|---|
| A4/Letter/Legal/4x6/5x7 | sí | sí | no | PPD/filtro | IDs de medio no confirmados |
| borderless | sí | sí | no | filtro/PPD | sobrespray y aceptación física sin prueba |
| banner 2.8 m | no expuesto | no | no | PPD auditado | firmware y transporte no confirmados |
| CMYK 32-bit | sí, conversión a RGB | sí | no | rastertopcl3gui.c | no es salida CMYK nativa |
| KGray/CMYGray | parcial | sí | no | filtro/PPD | separación física no probada |
| TAC | parcial | sí | no | filtro | modelo RGB insuficiente |
| dry time | sí, comando PML | sí | no | filtro | comando no validado en este firmware |
| InkSaver | sí, transformación raster | sí | no | filtro | no medir como tinta física |

Auditoría PPD: `cupstestppd -W all` pasa la sintaxis, pero informa advertencias de nombres estándar y recursos ausentes fuera del root de instalación. Se eliminaron del PPD los límites de 8000 puntos (~2,8 m), tanto en `ParamCustomPageSize` como en `MaxMediaHeight`, dejándolos en 1008 puntos; no existe evidencia de banner continuo.
| AirPrint | no | no | no | bridge | se retiró anuncio `_ipp._tcp` sin servidor IPP |
| eSCL/AirScan | bridge parcial | mock | no | hp_escl_bridge.py | Image Capture completo no probado |

El probe `tools/ews-readonly-probe.c` se mantiene como diagnóstico y no se incluye en el paquete; confirmó la necesidad de tratar las interfaces EWS duplicadas como transporte potencialmente compartido.

Estado de release: ninguna función física no probada debe presentarse como profesional o estable.
