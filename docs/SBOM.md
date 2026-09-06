# Software Bill of Materials (SBOM) — HP Smart Tank 500 macOS Driver Suite

**Fecha:** 2026-09-04  
**Versión:** 0.1.0-alpha  
**Arquitectura:** ARM64 (Apple Silicon, macOS 12.0+)  
**Formato de Referencia:** Estilo CycloneDX / SPDX Lite estructurado

---

## 1. Componentes Propios del Proyecto

| Nombre del Componente | Tipo | Lenguaje | Ruta en el Paquete | Licencia | Propósito |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `rastertopcl3gui` | Filtro CUPS | C99 | `/Library/Printers/hp/cups/filters/rastertopcl3gui` | MIT | Conversión de CUPS raster a flujo PCL3GUI (Modo 10). |
| `cups_backend_smarttank` | Backend CUPS | C99 | `/usr/libexec/cups/backend/smarttank` | MIT | Envío de datos de impresión a la interfaz USB mediante libusb. |
| `hp_scan` | CLI Escáner | C99 | `/Library/Printers/hp/bin/hp_scan` | MIT | Captura de imágenes del cristal plano sobre USB `ff/04/01`. |
| `hp-smart-tank-tool` | Herramienta CLI | C99 | `/Library/Printers/hp/bin/hp-smart-tank-tool` | MIT | Diagnóstico, telemetría LEDM, limpieza y estado de tinta. |
| `hp_escl_bridge.py` | Puente Local | Python 3 | `/usr/local/share/hp-smart-tank/hp_escl_bridge.py` | MIT | Servidor HTTP eSCL / AirScan para Image Capture. |
| `hp_airprint_daemon.sh`| Demonio IPP | Bash | `/usr/local/share/hp-smart-tank/hp_airprint_daemon.sh` | MIT | Lanzador del servidor IPP Everywhere local con ippeveprinter. |
| `hp_ipp_submit.sh` | Filtro IPP | Bash | `/usr/local/share/hp-smart-tank/hp_ipp_submit.sh` | MIT | Conversión de documentos IPP a la cola local CUPS. |
| `HP Smart Tank Utility.app` | App GUI | Swift 6 / SwiftUI | `/Applications/HP Smart Tank Utility.app` | MIT | Interfaz de monitor de consumibles, odómetro y mantenimiento. |
| `hp-smart_tank_500_series_mac.ppd` | Archivo PPD | PostScript PPD | `/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd` | GPL-2.0 / MIT | Ficha de capacidades de página, resolución y filtros CUPS. |
| `HP_Smart_Tank_500_Precision.icc` | Perfil de Color | Binario ICC 4.3 | `/Library/ColorSync/Profiles/Printers/HP_Smart_Tank_500_Precision.icc` | MIT / Public Domain | Perfil de gestión cromática ColorSync. |

---

## 2. Dependencias Externas de Terceros

| Biblioteca / Herramienta | Versión | Proveedor / Origen | Licencia | Mecanismo de Enlace |
| :--- | :--- | :--- | :--- | :--- |
| `libusb-1.0` | 1.0.27+ | libusb.info / macOS | LGPL-2.1 | Enlace dinámico (`-llibusb-1.0`). No se estática en binario propietario. |
| `libcups` | 2.3.4 | Apple Open Source / CUPS | Apache-2.0 con excepción GPL2 | Enlace dinámico con SDK nativo de macOS (`-lcups`). |
| `ippeveprinter` | 2.3.4 | Apple macOS (`/usr/bin/ippeveprinter`) | Propietario / Apple OS | Binario del sistema operativo de Apple (no redistribuido). |
| `ippeveps` | 2.3.4 | Apple macOS (`/usr/libexec/cups/command/ippeveps`) | Propietario / Apple OS | Binario del sistema operativo de Apple (no redistribuido). |
| `sips` | macOS nativo | Apple macOS (`/usr/bin/sips`) | Propietario / Apple OS | Utilidad de sistema utilizada para manipulación de imágenes/ICC. |
