# Documentación Técnica de TankControl

Índice central de la documentación técnica, especificaciones de arquitectura, ingeniería de controladores y protocolos de comunicación de **TankControl** para impresoras y escáneres multifunción HP Smart Tank 500 Series en macOS Apple Silicon.

---

## 1. Diseño, UX y Arquitectura de la Aplicación

* [`BRAND-GUIDE.md`](BRAND-GUIDE.md): Guía canónica de marca, paleta de colores cromática, iconografía SF Symbols y tipografía San Francisco.
* [`APP-DESIGN-SYSTEM.md`](APP-DESIGN-SYSTEM.md): Especificación exhaustiva del sistema de diseño en SwiftUI, tokens, componentes accesibles y soporte de Dark Mode.
* [`APP-INFORMATION-ARCHITECTURE.md`](APP-INFORMATION-ARCHITECTURE.md): Árbol de navegación jerárquico, máquina de estados de conexión y flujos de usuario.
* [`APP-UX-AUDIT.md`](APP-UX-AUDIT.md): Auditoría de ergonomía visual y transformaciones frente a las aplicaciones propietarias heredadas.
* [`APP-SANDBOX-ASSESSMENT.md`](APP-SANDBOX-ASSESSMENT.md): Evaluación de seguridad del sistema, aislamiento de privilegios y acceso a sockets CUPS / USB.

---

## 2. Ingeniería de Impresión y Motores RIP

* [`PRINT-PIPELINE.md`](PRINT-PIPELINE.md): Pipeline completo de procesamiento desde la cola CUPS hasta el spooler de hardware USB.
* [`PCL3GUI-STRUCTURAL-ANALYSIS.md`](PCL3GUI-STRUCTURAL-ANALYSIS.md): Análisis estructural del formato raster PCL3GUI Mode 10, compresión run-length y comandos de control.
* [`INKSAVER-ENGINEERING-AUDIT.md`](INKSAVER-ENGINEERING-AUDIT.md): Algoritmos de ahorro continuo de tinta (0% a 75%), tecnología EdgePreserve™ y micro-perforación dot gain.
* [`AIRPRINT-STATUS.md`](AIRPRINT-STATUS.md): Arquitectura de emulación AirPrint e IPP Everywhere para compatibilidad local y de red.

---

## 3. Protocolos de Hardware y Escaneo

* [`USB-INTERFACE-MAP.md`](USB-INTERFACE-MAP.md): Mapeo canónico de descriptores USB, interfaces vendor-specific y asignación de endpoints para impresión y escaneo.
* [`HARDWARE-USB.md`](HARDWARE-USB.md): Guía de transporte y topología física de conexión USB.
* [`SMART-TANK-500-PROTOCOL.md`](SMART-TANK-500-PROTOCOL.md): Especificación del protocolo de telemetría XML LEDM (`/DevMgmt/ProductStatusDyn.xml`) y canal óptico.
* [`SCANNER.md`](SCANNER.md): Arquitectura del driver nativo de escaneo óptico USB y puente eSCL / AirScan.

---

## 4. Gobernanza, Auditoría y Empaquetado

* [`CAPABILITIES-MATRIX.md`](CAPABILITIES-MATRIX.md): Matriz de capacidades por subsistema y grado de soporte nativo.
* [`LICENSING-AUDIT.md`](LICENSING-AUDIT.md): Auditoría de licencias de software (MIT, LGPL-2.1 para libusb) y clasificación de código.
* [`PACKAGE-MANIFEST.md`](PACKAGE-MANIFEST.md): Manifiesto de artefactos de distribución oficial (DMG y PKG) con tamaños y hashes SHA-256.
* [`SBOM.md`](SBOM.md): Lista de materiales de software (*Software Bill of Materials*).
* [`TROUBLESHOOTING-TREE.md`](TROUBLESHOOTING-TREE.md): Árbol determinista de diagnóstico y solución de incidencias offline.
* [`archive/`](archive/): Archivo histórico de actas de auditoría y pruebas de regresión intermedias.
