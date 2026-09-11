# TankControl v1.1.0 — Native macOS Apple Silicon Driver & Utility

Release oficial de **TankControl** (v1.1.0), solución integral y de código abierto para impresoras y escáneres multifunción **HP Smart Tank 500 Series** en macOS sobre arquitectura ARM64 (Apple Silicon M1/M2/M3/M4).

---

## 🚀 Novedades Principales en v1.1.0

### 1. Bundle 100% Autónomo (Zero Dependencias)
- `TankControl.app` incluye `Contents/Frameworks/libusb-1.0.0.dylib` vinculado vía `@rpath`.
- Funciona inmediatamente en cualquier Mac con macOS 12+ sin necesidad de tener instalado Homebrew ni bibliotecas externas.

### 2. Soporte Multilingüe Completo (i18n)
- **5 idiomas integrados**: Español (`es`), English (`en`), Português (`pt`), Français (`fr`) y Deutsch (`de`), además de detección automática del idioma del sistema operativo.
- Disponible en la app nativa, en el instalador `.pkg` (mediante `productbuild`), en los diálogos de impresión de CUPS PPD y en las guías del `.dmg`.

### 3. Motor InkSaver Continuo (0% a 75%)
- Control deslizante continuo para graduación fina del ahorro de tinta.
- Tecnología **EdgePreserve™**: preserva los bordes tipográficos y el texto negro 100% nítidos mientras reduce el consumo en fondos y rellenos.
- Conmutador de 1 clic para **Modo Rápido Borrador (Fast Draft)** a 300 DPI.

### 4. Robustez y Manejo Amigable de Primer Uso
- Si el usuario ejecuta la aplicación antes de instalar los controladores del sistema, la app proporciona orientación educativa en lugar de errores crudos de terminal.
- 205 pruebas unitarias automatizadas con **100% PASS**.

---

## 📦 Descarga de Artefactos Oficiales

| Archivo | Tamaño | Checksum SHA-256 |
| :--- | :--- | :--- |
| **`HP_Smart_Tank_500_macOS_Instalador.dmg`** | 7.0 MB | `51a2562a803a427f544c2577b0c2e50db33015db8c96550092a22618d41f3c3e` |
| **`HP_Smart_Tank_500_macOS_Installer-20260910-194312.pkg`** | 4.5 MB | `a52b7fe0ae08efac05730808f5684df9292a288f55839a86e5572cd93b2c827e` |

---

## 💻 Instrucciones de Instalación

1. Descarga y abre **`HP_Smart_Tank_500_macOS_Instalador.dmg`**.
2. Haz doble clic en **`Instalador HP Smart Tank 500.pkg`** para configurar el filtro RIP ARM64, backend y perfiles ColorSync.
3. Arrastra **`TankControl.app`** a la carpeta **Aplicaciones**.

> **Nota sobre macOS Gatekeeper:**  
> Al abrir por primera vez en macOS Sonoma o Sequoia, haz clic derecho (o Control-clic) en `TankControl.app` y selecciona **Abrir**, o ejecuta en Terminal:
> ```bash
> xattr -cr /Applications/TankControl.app
> ```
