# Auditoría de Empaquetado, Integridad y Estructura del Instalador `.pkg`

**Fecha:** 2026-09-04  
**Paquete Auditado:** `research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-20260904-084131.pkg`  
**Herramientas:** `tools/audit_package.sh`, `pkgutil`, `shasum`, `codesign`  
**Entorno:** macOS 26.6.2 Sequoia (Apple Silicon ARM64)

---

## 1. Clasificación Epistémica

* **[HECHO VERIFICADO]**: El archivo `.pkg` generado posee un hash criptográfico SHA-256 inmutable:  
  `452542bc2f986a2f38394e7d3180ee095af16f714e720b46e84e822cb7ee001a`.
* **[HECHO VERIFICADO]**: El payload expandido con `pkgutil --expand-full` contiene exactamente 113 archivos regulares.
* **[HECHO VERIFICADO]**: La aplicación `HP Smart Tank Utility.app` supera la verificación estricta de firma de código (`codesign --verify --deep --strict` -> PASS).
* **[HECHO VERIFICADO]**: No existen rutas prohibidas de desarrollo del host (`/Users/jorge`, `/opt/homebrew`, `research/`, `scratch/`, `Downloads/`) ni direcciones inseguras (`0.0.0.0`, `_ipp._tcp` en binarios duros) en los contenidos del payload.
* **[HECHO VERIFICADO]**: El instalador no genera archivos AppleDouble residuales (`._*`) en el sistema de archivos destino (`materialized_dots=0`).
* **[VERIFICADO OFFLINE]**: Auditoría completa con `tools/audit_package.sh` ejecutada de forma no destructiva sin modificar directorios del sistema operativo (`installation=NOT_PERFORMED`).

---

## 2. Estructura de Destino del Payload

El paquete distribuye los componentes del controlador en las jerarquías canónicas de macOS:

```text
/
├── Applications/
│   └── HP Smart Tank Utility.app/           (Utilidad de control nativa SwiftUI ARM64)
│       └── Contents/
│           ├── Helpers/
│           │   ├── hp-smart-tank-tool        (CLI de diagnóstico y telemetría)
│           │   └── hp_scan                   (CLI de escaneo por USB)
│           └── Resources/
│               └── AppIcon.icns
├── Library/
│   ├── ColorSync/
│   │   └── Profiles/
│   │       └── Printers/
│   │           └── HP_Smart_Tank_500_Precision.icc
│   └── Printers/
│       ├── PPDs/
│       │   └── Contents/
│       │       └── Resources/
│       │           └── HP Smart Tank 500.ppd
│       └── hp/
│           └── cups/
│               └── filters/
│                   └── rastertopcl3gui       (Filtro raster a PCL3GUI)
└── usr/
    ├── libexec/
    │   └── cups/
    │       └── backend/
    │           └── smarttank                 (Backend USB CUPS)
    └── local/
        └── share/
            └── hp-smart-tank/
                ├── hp_airprint_daemon.sh     (Lanzador AirPrint ippeveprinter)
                ├── hp_ipp_submit.sh          (Conversor de trabajos IPP a cola CUPS)
                ├── hp-smart-tank-500-airprint.conf (Ficha de atributos IPP Everywhere)
                └── hp_escl_bridge.py         (Puente eSCL/AirScan)
```

---

## 3. Verificación de Scripts de Instalación (`preinstall` / `postinstall`)

Se auditaron los scripts ejecutados por el instalador:
1. **`preinstall`:**
   * Detiene de forma segura cualquier demonio puente (`hp_airprint_daemon.sh` o `hp_escl_bridge.py`) que pudiera estar ejecutándose en segundo plano.
2. **`postinstall`:**
   * Establece permisos estrictos de ejecución (`chmod 755`) en los filtros CUPS y el backend USB (`chown root:wheel /usr/libexec/cups/backend/smarttank`).
   * Registra la cola de impresión en CUPS mediante `lpadmin`:
     ```bash
     lpadmin -p "HP_Smart_Tank_500" -E -v "smarttank://03f0:2b54" -P "/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd" -D "HP Smart Tank 500"
     ```
   * Reinicia el subsistema CUPS de macOS (`killall -HUP cupsd`) para cargar el nuevo backend y filtro.
