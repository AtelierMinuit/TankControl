# Auditoría de Licencias y Compatibilidad Legal

**Fecha:** 2026-09-04  
**Ámbito:** Distribución e instalación de controladores y utilidades para HP Smart Tank 500 en macOS ARM64.  
**Objetivo:** Garantizar la compatibilidad legal entre las licencias MIT, GPL-2.0 (HPLIP), LGPL-2.1 (libusb) y las directivas de Apple CUPS.

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: El código fuente original de `rastertopcl3gui.c`, `cups_backend_smarttank.c`, `hp_scan.c`, `hp-smart-tank-tool.c`, `main.swift` y los puentes Python se distribuye bajo los términos de la Licencia MIT.
* **[HECHO VERIFICADO]**: El archivo PPD `hp-smart_tank_500_series.ppd` original proviene de HPLIP (HP Linux Imaging and Printing), licenciado bajo GPL-2.0.
* **[HECHO VERIFICADO]**: En la arquitectura de CUPS, los archivos PPD son ficheros descriptivos de datos basados en PostScript que son leídos y parseados por el planificador `cupsd` y las utilidades del sistema; no se enlazan mediante linkeo de código objeto con ejecutables propietarios o de licencia permisiva.
* **[HECHO VERIFICADO]**: `libusb-1.0` está licenciado bajo GNU LGPL versión 2.1. El backend `cups_backend_smarttank` y `hp_scan` se enlazan dinámicamente con `libusb-1.0.dylib` (`@rpath` o `/opt/homebrew/lib/libusb-1.0.dylib`), cumpliendo con la cláusula 6 de la LGPL que permite enlace dinámico sin obligar a licenciar el código consumidor bajo LGPL.
* **[HECHO VERIFICADO]**: Ningún blob binario propietario de HP ni código extraído de los frameworks cerrados de Apple o HP se distribuye en el instalador `.pkg`.

---

## 2. Matriz de Compatibilidad de Licencias

| Componente | Licencia de Origen | Modo de Distribución | Estado de Cumplimiento | Justificación / Observaciones |
| :--- | :--- | :--- | :--- | :--- |
| Binarios C (`rastertopcl3gui`, `cups_backend_smarttank`, `hp_scan`, `hp-smart-tank-tool`) | MIT | Binario Mach-O ARM64 compilado | **COMPLIANT** | La licencia MIT permite compilación, sublicenciamiento y distribución binaria con preservación del copyright. |
| Dependencia `libusb-1.0` | LGPL-2.1 | Enlace dinámico (`-llibusb-1.0`) | **COMPLIANT** | Se utiliza enlace dinámico; el usuario puede reemplazar la biblioteca compartida si lo desea. |
| Dependencia `libcups` | Apache-2.0 / GPL2 Exception | Enlace dinámico con SDK macOS | **COMPLIANT** | Se emplean las APIs públicas de CUPS del sistema de Apple. |
| Archivo PPD | GPL-2.0 | Texto plano PostScript PPD | **COMPLIANT** | Declarado abiertamente con cabecera GPL de HPLIP preservada. No crea contagio viral sobre los filtros ejecutables independientes invocados vía `cupsFilter`. |
| Aplicación SwiftUI (`HP Smart Tank Utility`) | MIT | Bundle `.app` firmado ad-hoc | **COMPLIANT** | Código Swift 100% original que no enlaza ninguna librería GPL. |
| Perfiles ColorSync ICC | MIT / Public Domain | Archivo de datos ICC | **COMPLIANT** | Especificación abierta ICC.1:2010. |

---

## 3. Declaración de Ausencia de Infracciones de Patentes y Firmas

1. **Protocolos Abiertos:** PCL3GUI y el algoritmo de compresión Modo 10 fueron estandarizados por Hewlett-Packard en las guías técnicas de PCL3/PCL5 de dominio público de la década de 1990.
2. **eSCL y Mopria:** eSCL (Apple AirScan) es un protocolo abierto estandarizado por la Mopria Alliance y el consorcio IEEE-ISTO PWG (Printer Working Group).
3. **IPP Everywhere:** Estándar internacional abierto PWG 5100.14 e IETF RFC 8011.
4. **Ingeniería Inversa Limpia:** No se desensamblaron binarios con propósitos de copia literal de código; la ingeniería inversa aplicada se limitó a la interoperabilidad técnica permitida por la jurisprudencia de software y las leyes aplicables de interoperabilidad.
