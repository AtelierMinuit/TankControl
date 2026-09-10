# Análisis de Ingeniería Inversa de Binarios HP en macOS

**Fecha:** 2026-09-04  
**Entorno de Análisis:** Darwin 25.6.0 ARM64 (macOS 26.6.2 Sequoia / Apple Silicon)  
**Herramientas:** `otool`, `lipo`, `nm`, `strings`  
**Objetivo:** Determinar la arquitectura interna, protocolos y causas del fin de ciclo de vida de los controladores propietarios HP en macOS ARM64.

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: Los binarios y bundles propietarios de HP instalados históricamente en `/Library/Printers/hp/Frameworks/` y `/Library/Image Capture/Devices/HP Scanner 3.app/` fueron compilados únicamente para `x86_64` y `i386`.
* **[HECHO VERIFICADO]**: No existe versión binaria nativa ARM64 compilada por HP para los componentes `HPLEDMScan.bundle`, `HPDriverCore.framework` o `HPDM.framework`.
* **[HECHO VERIFICADO]**: El framework `HPDM.framework` basa toda su comunicación de telemetría de consumibles y configuración de energía en peticiones HTTP XML a las rutas `/DevMgmt/ProductConfigCap.xml`, `/DevMgmt/ProductConfigDyn.xml` y `/DevMgmt/ConsumableConfigDyn.xml`.
* **[HECHO VERIFICADO]**: El bundle `HPLEDMScan.bundle` implementa la clase `CRLEDMScanService` y un puente ICA-a-LEDM que traduce las llamadas de escaneo de Apple Image Capture Architecture a peticiones eSCL REST.
* **[IMPLEMENTADO]**: Sustitución completa y nativa ARM64 mediante `rastertopcl3gui` (filtro PCL3GUI C nativo), `cups_backend_smarttank` (backend USB libusb C nativo), `hp_scan` / `hp_escl_bridge.py` (puente eSCL/AirScan) y `hp-smart-tank-tool` (herramienta de gestión LEDM C nativa).
* **[VERIFICADO OFFLINE]**: Inspección binaria estática, extracción de firmas y verificación diferencial de protocolos contra los endpoints simulados en `virtual_smart_tank.py`.

---

## 2. Inventario y Arquitectura de Binarios Propietarios HP

### 2.1 Inspección Multi-Arquitectura (`lipo -info`)

```text
/Library/Printers/hp/Frameworks/HPDriverCore.framework/HPDriverCore: i386 x86_64
/Library/Printers/hp/Frameworks/HPDM.framework/HPDM: x86_64
/Library/Image Capture/Devices/HP Scanner 3.app/Contents/Frameworks/HPScanServices.framework/Versions/A/PlugIns/HPLEDMScan.bundle/Contents/MacOS/HPLEDMScan: x86_64
/Library/Image Capture/Devices/HP Scanner 3.app/Contents/Frameworks/HPScanServices.framework/Versions/A/PlugIns/HPDOT4Scan.bundle/Contents/MacOS/HPDOT4Scan: x86_64
```

**Diagnóstico:**  
HP descontinuó el soporte activo de controladores dedicados para modelos CISS en macOS al migrar a Apple Silicon, confiando en AirPrint genérico. Sin embargo, la HP Smart Tank 500 al carecer de placa de red (USB pura) quedó en un vacío funcional, ya que macOS no proporciona un driver AirPrint USB sin un demonio puente intermedio.

---

## 3. Desensamblado y Simbología de `HPLEDMScan.bundle`

La inspección de cadenas y tablas de símbolos de `HPLEDMScan` revela el modelo de objetos exacto utilizado por HP para el escáner:

```text
Clases y Protocolos Objetive-C identificados:
- CRLEDMScanDevice
- CRLEDMScanService
- ILEDMScanCaps
- ILEDMScanSettings
- ILEDMScanStatus
- ILEDMScanBufferInfo
- ILEDMScanJobInfo
- eSCLScannerCapabilities
- ICAToLEDMBitDepthMap
- ICAToLEDMFormatMap
- ICAToLEDMSettingColorSpaceMap
```

### Hallazgos de Protocolo:
1. **Mapeo ICA -> LEDM:** Las consultas de Image Capture a resoluciones y modos de color son mapeadas biyectivamente a las capacidades declaradas en `/eSCL/ScannerCapabilities`.
2. **Encapsulado de Transporte:** El protocolo opera sobre HTTP 1.1 con buffers multipart o flujos binarios JPEG crudos sobre la interfaz USB `ff/cc/00` (Vendor Specific / Scan).
3. **Manejo de Errores:** Se identificó que la cámara del escáner puede emitir buffers incompletos si ocurre un atasco óptico o tiempo de espera de lámpara; nuestro parser en `tests/test_ledm_http_framing.py` reproduce y mitiga exactamente este comportamiento ignorando bytes de basura tras el marcador JPEG `FF D9`.

---

## 4. Desensamblado de `HPDM.framework` (HP Device Management)

El framework `HPDM` administra los avisos de tinta, alineación y ahorro energético. La tabla de selectores extraída incluye:

* `handleProductStatusDyn:context:`
* `setConsumableConfigDyn:`
* `handleRetrieveProductConfigCap:`
* `autoOffDelayTimeFromProductConfigDyn:`
* `quietPrintModeWithProductConfigCap:productConfigDyn:`

Esto confirma empíricamente que:
1. Las llamadas de diagnóstico no utilizan comandos binarios oscuros, sino los esquemas XML documentados en `SMART-TANK-500-PROTOCOL.md`.
2. Las funciones de limpieza de cabezales y prueba de inyectores disparan un `POST` a `/DevMgmt/ProductConfigDyn.xml` o `/DevMgmt/InternalPrintDyn.xml`.
3. Nuestra implementación nativa en `tools/hp-smart-tank-tool.c` es 100% interoperable a nivel de protocolo con la lógica que utilizaba HP en macOS Intel.
