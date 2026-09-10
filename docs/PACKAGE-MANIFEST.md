# Manifiesto de Paquete Oficial (Release v1.1.0)

**Fecha de Construcción:** 2026-09-10  
**Arquitectura Destino:** Apple Silicon ARM64 (macOS 12.0 Monterey o superior)  
**Versión:** `1.1.0`

---

## 1. Artefactos de Distribución Oficial

| Artefacto | Descripción | Tamaño | Checksum SHA-256 |
| :--- | :--- | :--- | :--- |
| **`HP_Smart_Tank_500_macOS_Instalador.dmg`** | Imagen de disco distribuible (.dmg) con app, instalador y guías multilingües | 7.0 MB | `51a2562a803a427f544c2577b0c2e50db33015db8c96550092a22618d41f3c3e` |
| **`HP_Smart_Tank_500_macOS_Installer-20260910-194312.pkg`** | Instalador de distribución multilingüe (`productbuild`) con bienvenida GUI | 4.5 MB | `a52b7fe0ae08efac05730808f5684df9292a288f55839a86e5572cd93b2c827e` |
| **`HP_Smart_Tank_500_Native_Apple_Silicon-20260910-194312.pkg`** | Componente instalador base (`pkgbuild`) con scripts de post-instalación | 4.5 MB | `a47aca3085d02de32640853447a79275055a4ae2e4151818e1e1242d3e735881` |

---

## 2. Contenido del Paquete y Destinos en el Sistema

* **`/Applications/TankControl.app`**: Utilidad nativa de control en SwiftUI con selector dinámico de idioma (Español, English, Português, Français, Deutsch), comparador InkSaver continuo (0% a 75%), telemetría real y escáner.
  - Incluye `Contents/Frameworks/libusb-1.0.0.dylib` vinculado vía `@rpath`.
  - Helpers auxiliares `Contents/Helpers/hp_scan` y `Contents/Helpers/hp-smart-tank-tool` vinculados autónomamente.
* **`/Library/Printers/hp/cups/filters/rastertopcl3gui`**: Filtro RIP nativo PCL3GUI Mode 10 optimizado para ARM64. Permisos: `root:wheel` (755).
* **`/Library/Printers/hp/cups/backend/smarttank`**: Backend bidireccional CUPS nativo con descriptor dinámico USB.
* **`/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd`**: Archivo PPD con traducciones en 5 idiomas y opciones InkSaver.
* **`/Library/ColorSync/Profiles/`**: Perfiles ICC de calibración fotográfica (Plain, Glossy, Matte, Precision).
* **`/Library/LaunchAgents/com.hp.smarttank.airscan.plist`**: Demonio eSCL para compatibilidad nativa con *Image Capture*.
* **`/usr/local/bin/`**: Herramientas CLI `hp-smart-tank`, `hp_scan`, `hp-smart-tank-tool`, `smarttank`.
* **`/usr/local/lib/libusb-1.0.0.dylib`**: Biblioteca dinámica vendorizada para soporte de las herramientas CLI del sistema.

---

## 3. Verificaciones de Seguridad e Integridad

1. **Aislamiento de Entorno**: Cero referencias dinámicas a `/opt/homebrew`, `/Users/jorge` ni rutas privadas de desarrollo.
2. **Firma de Código**: Bundle firmado ad-hoc con validación estricta (`codesign --verify --deep --strict`).
3. **Limpieza de Metadatos**: Libre de archivos AppleDouble (`._*`) y atributos extendidos (`xattr -cr`).
4. **Desinstalación Limpia**: Incluye `/usr/local/share/hp-smart-tank/uninstall.sh` con opciones `--dry-run` y `--confirm`.
