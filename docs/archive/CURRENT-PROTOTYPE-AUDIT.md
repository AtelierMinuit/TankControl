# Auditoría de Binarios hpcups ARM64

Fecha de actualización: 2026-09-02 / 2026-09-03.

## Comparación de Binarios hpcups

| Atributo | 1. Instalado en Sistema | 2. Build de Referencia | 3. Build Instrumentado |
|---|---|---|---|
| **Ruta** | `/Library/Printers/hp/cups/filters/hpcups` | `research/builds/hpcups_arm64` | `research/builds/hpcups_instrumented_arm64` |
| **Arquitectura** | Mach-O 64-bit executable `arm64` | Mach-O 64-bit executable `arm64` | Mach-O 64-bit executable `arm64` |
| **Tamaño (bytes)** | 562,744 | 562,744 | 563,160 |
| **SHA-256** | `38999b321448a54498c80ab8efdc104daaa5c010a945ef81b6c1fce03b4afdf3` | `57c75d6ace7ce31475b601616b9718e50285795310d4154a24f56fb0d35d501b` | `3516e6a4fb72a395b35902d47c7be510e230632645f24b2539460d8087708676` |
| **Propietario / Permisos** | `root:admin`, `-rwxr-xr-x` | `jorge:staff`, `-rwxr-xr-x` | `jorge:staff`, `-rwxr-xr-x` |
| **Firma de código** | Ad-hoc linker-signed (CDHash: `8a9c12...`) | Ad-hoc linker-signed (CDHash: `7f3f7b...`) | Ad-hoc linker-signed (CDHash: `0887b8...`) |
| **Dependencia libjpeg** | `@executable_path/libjpeg.8.dylib` | `/opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib` | `/opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib` |
| **Tracing incorporado** | No | No | Sí (`HPCUPS_RE_TRACE=1` a stderr) |

### Análisis de Equivalencia e Identidad Binaria:
1. **Instalado vs Referencia:** Tienen idéntico tamaño (562,744 bytes). La diferencia en SHA-256 se debe exclusivamente al uso de `install_name_tool` para reubicar la ruta de `libjpeg.8.dylib` a `@executable_path/` con el fin de superar el Sandbox estricto de CUPS en macOS. La lógica de compilación y símbolos son equivalentes.
2. **Build Instrumentado:** Contiene 416 bytes adicionales correspondientes a los hooks de `Pcl3Gui2::StartPage`, `Pcl3Gui2::Encapsulate`, `Pcl3Gui2::encapsulateRaster`, y la clase `SystemServices::Trace` condicional.

---

## Componentes Originales HP para macOS Auditados

### Bundle de Escaneo HP LEDM
* **Ruta:** `/Library/Image Capture/Devices/HP Scanner 3.app/Contents/Frameworks/HPScanServices.framework/Versions/A/PlugIns/HPLEDMScan.bundle`
* **Binario:** `.../HPLEDMScan.bundle/Contents/MacOS/HPLEDMScan`
* **Arquitectura:** Mach-O 64-bit bundle `x86_64`
* **Tamaño:** 154,064 bytes
* **SHA-256:** `99b08e0a825a60ad71699c422ec5d9e9354c0294fa7cd8440322efa40b6086c0`
* **Firma:** Válida, emitida por `HP Inc. (Developer ID: 6HB5Y2QTA3)`
* **Clase Principal:** `CRLEDMScanService`
* **Dependencias Clave:** `@rpath/HPDM.framework/Versions/5.0/HPDM`

### Grafo de Dependencias de Transporte HP en macOS:
```text
HPLEDMScan.bundle (Plugin x86_64)
       ↓
HPScanServices.framework
       ↓
HPDM.framework (/Library/Printers/hp/Frameworks/HPDM.framework)
       ↓
IOUSBHostFamily / libusb (Acceso a interfaces ff/cc/00 y ff/04/01)
```

---

## Auditoría de Frameworks Originales HP en macOS (`/Library/Printers/hp/Frameworks/`)

Se examinaron todos los frameworks binarios instalados por los paquetes oficiales de HP:

| Framework | Arquitecturas (lipo) | Símbolos Clave Identificados |
|---|---|---|
| `Crossbow.framework` | `x86_64` | Subrutinas de renderizado gráfico |
| `HPDM.framework` | `x86_64` | `ADMLEDMRequest`, `ADMHTTPRequest`, `ADMDataChannelFactory`, `ADMScanFactory` |
| `HPDeviceModel.framework` | `i386 x86_64` | Modelos de impresora y diccionarios de capacidades |
| `HPDeviceMonitoring.framework`| `x86_64` | Polling de estado y eventos USB |
| `HPDriverCore.framework` | `i386 x86_64` | Motor de driver y generación de PPD |
| `HPEventStoring.framework` | `x86_64` | Logging y telemetría de eventos |
| `HPSmartPrint.framework` | `i386 x86_64` | Interfaz de usuario y perfiles de impresión |
| `Interlaken.framework` | `x86_64` | Transporte y comunicación bidireccional |
| `Matterhorn.framework` | `x86_64` | Capa de servicio de escaneo y OCR |
| `ResourceManager.framework` | `x86_64` | Cadenas de localización y recursos de interfaz |

**Conclusión acotada a la muestra auditada:** Los binarios y frameworks oficiales de HP inspeccionados en este proyecto fueron compilados para Intel (`x86_64`/`i386`); no se encontró un componente oficial arm64 en esa muestra. Esto no demuestra una afirmación universal sobre toda distribución histórica de HP.

---

## Nuevo Filtro Nativo Standalone: `rastertopcl3gui`

| Característica | `hpcups` (Port HPLIP) | `rastertopcl3gui` (Desarrollo Nativo) |
|---|---|---|
| **Arquitectura** | Mach-O 64-bit `arm64` | Mach-O 64-bit `arm64` |
| **Tamaño en disco** | 562,744 bytes (562 KB) | **34,456 bytes (34 KB)** |
| **Dependencias dinámicas** | 14 (`libjpeg`, `libcupsimage`, `libc++`...) | **2 (`/usr/lib/libcups.2.dylib`, `libSystem.B.dylib`)** |
| **Dependencias de Homebrew** | Sí (`libjpeg-turbo`) | **No requiere Homebrew en runtime del filtro auditado; el backend y herramientas sí enlazan libusb de Homebrew** |
| **Sandbox de CUPS** | Requiere rpath modificado a `@executable_path` | **Compatible out-of-the-box sin modificaciones** |
| **Soporte de Color** | Fallaba en negro puro con RGBW | **sRGB experimental; preservación raster observada offline** |
| **Velocidad de proceso** | ~250 ms por página | **~100 ms por página (5100x6600), medición offline histórica; no validada como throughput actual ni físico** |
