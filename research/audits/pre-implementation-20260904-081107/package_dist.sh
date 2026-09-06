#!/usr/bin/env bash
# ==============================================================================
# package_dist.sh
# Construcción del instalador oficial `.pkg` para HP Smart Tank 500 en macOS Apple Silicon
# ==============================================================================

set -Eeuo pipefail
export COPYFILE_DISABLE=1

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${HP_AUDIT_BUILD_DIR:-${DIR}/research/builds/audit-clean/night-20260904}"
STAGE_TAG="$(date '+%Y%m%d-%H%M%S')"
PKG_ROOT="${DIR}/research/staging/package_root-${STAGE_TAG}"
PKG_SCRIPTS="${DIR}/research/staging/package_scripts-${STAGE_TAG}"
OUT_PKG="${DIR}/research/builds/HP_Smart_Tank_500_Native_Apple_Silicon-${STAGE_TAG}.pkg"

echo "=== Construyendo Paquete Instalador .pkg Oficial ==="

# No empaquetar artefactos parciales ni caer silenciosamente en una build vieja.
if [ ! -d "${BUILD_DIR}/HP Smart Tank Utility.app/Contents" ] ||
   [ ! -x "${BUILD_DIR}/HP Smart Tank Utility.app/Contents/MacOS/HP Smart Tank Utility" ]; then
    echo "ERROR: bundle SwiftUI ausente o incompleto en BUILD_DIR=${BUILD_DIR}" >&2
    exit 2
fi
for helper in hp_scan hp-smart-tank-tool; do
    if [ ! -x "${BUILD_DIR}/HP Smart Tank Utility.app/Contents/Helpers/${helper}" ]; then
        echo "ERROR: helper requerido ausente o no ejecutable en el bundle: ${helper}" >&2
        exit 2
    fi
done
if ! codesign --verify --deep --strict "${BUILD_DIR}/HP Smart Tank Utility.app" >/dev/null 2>&1; then
    echo "ERROR: la firma/integridad del bundle SwiftUI no es válida" >&2
    exit 2
fi
for required in rastertopcl3gui smarttank hp_scan hp-smart-tank-tool; do
    if [ ! -x "${BUILD_DIR}/${required}" ]; then
        echo "ERROR: binario requerido ausente o no ejecutable: ${BUILD_DIR}/${required}" >&2
        exit 2
    fi
done

# 1. Crear staging nuevo; nunca borrar snapshots o staging anteriores.
mkdir -p "${PKG_ROOT}" "${PKG_SCRIPTS}"
mkdir -p "${PKG_ROOT}/Applications"
mkdir -p "${PKG_ROOT}/Library/Printers/hp/cups/filters"
mkdir -p "${PKG_ROOT}/Library/Printers/hp/cups/backend"
mkdir -p "${PKG_ROOT}/Library/Printers/hp/Icons"
mkdir -p "${PKG_ROOT}/Library/Printers/PPDs/Contents/Resources"
mkdir -p "${PKG_ROOT}/Library/ColorSync/Profiles"
mkdir -p "${PKG_ROOT}/Library/LaunchAgents"
mkdir -p "${PKG_ROOT}/usr/local/bin"
mkdir -p "${PKG_ROOT}/usr/local/lib"
mkdir -p "${PKG_ROOT}/usr/local/share/hp-smart-tank"
mkdir -p "${PKG_SCRIPTS}"

# 2. Copiar aplicación GUI SwiftUI nativa
echo "[pkg] Copiando HP Smart Tank Utility.app..."
cp -RX "${BUILD_DIR}/HP Smart Tank Utility.app" "${PKG_ROOT}/Applications/"
for helper in "${PKG_ROOT}/Applications/HP Smart Tank Utility.app/Contents/Helpers/hp_scan" "${PKG_ROOT}/Applications/HP Smart Tank Utility.app/Contents/Helpers/hp-smart-tank-tool"; do
    if [ -f "$helper" ]; then
        install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "$helper"
        install_name_tool -add_rpath /usr/local/lib "$helper"
    fi
done
codesign --force --deep --sign - "${PKG_ROOT}/Applications/HP Smart Tank Utility.app"

# 3. Copiar filtro binario CUPS nativo, backend bidireccional, icono Retina y PPD
echo "[pkg] Copiando filtro CUPS, backend smarttank, icono Retina y PPD..."
    cp -X "${BUILD_DIR}/rastertopcl3gui" "${PKG_ROOT}/Library/Printers/hp/cups/filters/"
    cp -X "${BUILD_DIR}/smarttank" "${PKG_ROOT}/Library/Printers/hp/cups/backend/"
    cp -X "${BUILD_DIR}/smarttank" "${PKG_ROOT}/usr/local/bin/"
    cp -X "${BUILD_DIR}/hp_scan" "${PKG_ROOT}/usr/local/bin/"
    cp -X "${BUILD_DIR}/hp-smart-tank-tool" "${PKG_ROOT}/usr/local/bin/"
    cp -X "${DIR}/lib/libusb-1.0.0.dylib" "${PKG_ROOT}/usr/local/lib/"
    install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "${PKG_ROOT}/Library/Printers/hp/cups/backend/smarttank"
    install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "${PKG_ROOT}/usr/local/bin/smarttank"
    install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "${PKG_ROOT}/usr/local/bin/hp_scan"
    install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "${PKG_ROOT}/usr/local/bin/hp-smart-tank-tool"
    install_name_tool -add_rpath /usr/local/lib "${PKG_ROOT}/Library/Printers/hp/cups/backend/smarttank"
    install_name_tool -add_rpath /usr/local/lib "${PKG_ROOT}/usr/local/bin/smarttank"
    install_name_tool -add_rpath /usr/local/lib "${PKG_ROOT}/usr/local/bin/hp_scan"
    install_name_tool -add_rpath /usr/local/lib "${PKG_ROOT}/usr/local/bin/hp-smart-tank-tool"
cp -X "${DIR}/research/builds/HP_Smart_Tank_500.icns" "${PKG_ROOT}/Library/Printers/hp/Icons/"
cp -X "${DIR}/research/builds/hp-smart_tank_500_series_mac.ppd" "${PKG_ROOT}/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd"

# 4. Copiar perfiles ColorSync ICC Multi-Soporte (Normal, Brillante, Mate)
echo "[pkg] Copiando perfiles ColorSync ICC..."
for icc in HP_Smart_Tank_Plain.icc HP_Smart_Tank_Glossy.icc HP_Smart_Tank_Matte.icc HP_Smart_Tank_500_Precision.icc; do
    if [ -f "${DIR}/research/builds/${icc}" ]; then
        cp -X "${DIR}/research/builds/${icc}" "${PKG_ROOT}/Library/ColorSync/Profiles/"
    fi
done

# 5. Copiar utilidades de terminal (CLI) y puente eSCL
echo "[pkg] Copiando herramientas CLI y demonio AirScan..."
cp -X "${DIR}/tools/hp-smart-tank" "${PKG_ROOT}/usr/local/bin/"
cp -X "${DIR}/tools/hp_escl_bridge.py" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
cp -X "${DIR}/tools/hp_smart_tank.py" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
cp -X "${DIR}/tools/smart_tank_daemon.sh" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
cp -X "${DIR}/tools/generate_color_target.py" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
cp -X "${DIR}/tools/calibrate_icc.py" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
cp -X "${DIR}/uninstall.sh" "${PKG_ROOT}/usr/local/share/hp-smart-tank/"
chmod 755 "${PKG_ROOT}/usr/local/share/hp-smart-tank/uninstall.sh"

# Evitar archivos AppleDouble/resource forks en la distribución final.
# El staging es nuevo y exclusivo de esta ejecución.
find "${PKG_ROOT}" -depth -name '._*' -delete
# pkgbuild puede materializar resource forks como AppleDouble a partir de
# atributos extendidos; el payload debe quedar libre de ellos.
xattr -cr "${PKG_ROOT}" 2>/dev/null || true
xattr -dr com.apple.provenance "${PKG_ROOT}" 2>/dev/null || true

# 6. Crear LaunchAgent para inicio automático y despertar dinámico por hardware USB IOKit
cat << 'PLIST' > "${PKG_ROOT}/Library/LaunchAgents/com.hp.smarttank.airscan.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.hp.smarttank.airscan</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/python3</string>
        <string>/usr/local/share/hp-smart-tank/hp_escl_bridge.py</string>
        <string>--port</string>
        <string>8089</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>LaunchEvents</key>
    <dict>
        <key>com.apple.iokit.matching</key>
        <dict>
            <key>com.hp.smarttank.usbdevice</key>
            <dict>
                <key>idVendor</key>
                <integer>1008</integer>
                <key>idProduct</key>
                <integer>11092</integer>
                <key>IOProviderClass</key>
                <string>IOUSBDevice</string>
                <key>IOMatchLaunchStream</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
PLIST

# 7. Crear script postinstall
cat << 'POSTINSTALL' > "${PKG_SCRIPTS}/postinstall"
#!/bin/bash
set -e

echo "=== Configurando HP Smart Tank 500 en macOS ==="

FILTER="/Library/Printers/hp/cups/filters/rastertopcl3gui"
BACKEND="/Library/Printers/hp/cups/backend/smarttank"
PPD="/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd"
ICON_DIR="/Library/Printers/hp/Icons"
ICC_DIR="/Library/ColorSync/Profiles"

require_regular_owned_path() {
    local path="$1"
    if [ ! -f "$path" ] || [ -L "$path" ]; then
        echo "ERROR: destino ausente o symlink no permitido: $path" >&2
        exit 1
    fi
}

# Seguridad estricta CUPS: root:wheel y 755
require_regular_owned_path "$FILTER"
chmod 755 "$FILTER"
chown root:wheel "$FILTER"

if [ -f "$BACKEND" ]; then
    require_regular_owned_path "$BACKEND"
    chmod 755 "$BACKEND"
    chown root:wheel "$BACKEND"
    if [ -L /usr/libexec/cups/backend/smarttank ]; then
        LINK_TARGET=$(readlink /usr/libexec/cups/backend/smarttank 2>/dev/null || true)
        if [ "$LINK_TARGET" = "$BACKEND" ]; then
            echo "Backend CUPS ya enlazado al componente del paquete."
        else
            echo "ADVERTENCIA: se preserva un enlace smarttank existente ajeno al paquete." >&2
        fi
    elif [ -e /usr/libexec/cups/backend/smarttank ]; then
        echo "ADVERTENCIA: se preserva un backend smarttank existente ajeno al paquete." >&2
    else
        ln -s "$BACKEND" /usr/libexec/cups/backend/smarttank
    fi
fi

require_regular_owned_path "$PPD"
chmod 644 "$PPD"
chown root:wheel "$PPD"

if [ -d "$ICON_DIR" ]; then
    # No cambiar propiedad ni permisos de iconos HP ajenos al paquete.
    require_regular_owned_path "$ICON_DIR/HP_Smart_Tank_500.icns"
    chown root:wheel "$ICON_DIR/HP_Smart_Tank_500.icns"
    chmod 644 "$ICON_DIR/HP_Smart_Tank_500.icns"
fi

for icc in "$ICC_DIR"/HP_Smart_Tank_*.icc; do
    [ -e "$icc" ] || continue
    require_regular_owned_path "$icc"
    chmod 644 "$icc"
    chown root:wheel "$icc"
done

require_regular_owned_path /usr/local/bin/hp-smart-tank
chmod 755 /usr/local/bin/hp-smart-tank
require_regular_owned_path /usr/local/bin/hp_scan
chmod 755 /usr/local/bin/hp_scan
require_regular_owned_path /usr/local/bin/hp-smart-tank-tool
chmod 755 /usr/local/bin/hp-smart-tank-tool
if [ -e /usr/local/bin/smarttank ]; then
    require_regular_owned_path /usr/local/bin/smarttank
    chmod 755 /usr/local/bin/smarttank
fi

# Determinar URI de dispositivo (backend nativo bidireccional smarttank:// o usb:// estándar)
DEVICE_URI="usb://HP/Smart%20Tank%20500%20series"
if [ -x /usr/libexec/cups/backend/smarttank ]; then
    DEVICE_URI="smarttank://HP/Smart%20Tank%20500%20series"
fi

# Registrar cola en CUPS sólo si no existe; no mutar una cola ajena silenciosamente.
if lpstat -p "HP_Smart_Tank_500" >/dev/null 2>&1; then
    echo "La cola HP_Smart_Tank_500 ya existe; se preserva y no se sobrescribe."
else
    lpadmin -p "HP_Smart_Tank_500" \
        -v "$DEVICE_URI" \
        -P "$PPD" \
        -D "HP Smart Tank 500 (Nativo Apple Silicon)" \
        -L "Local USB" \
        -E
fi

# Cargar LaunchAgent de AirScan para el usuario activo
CURRENT_USER=$(stat -f "%Su" /dev/console 2>/dev/null || echo "$USER")
if [ -n "$CURRENT_USER" ] && [ "$CURRENT_USER" != "root" ]; then
    USER_ID=$(id -u "$CURRENT_USER")
    if ! launchctl asuser "$USER_ID" launchctl load -w /Library/LaunchAgents/com.hp.smarttank.airscan.plist 2>/dev/null; then
        echo "ADVERTENCIA: no se pudo cargar el LaunchAgent; la instalación de archivos continúa, pero AirScan no está activo."
    fi
fi

echo "Archivos del controlador configurados; verifique por separado la cola CUPS y el estado de AirScan."
exit 0
POSTINSTALL
chmod +x "${PKG_SCRIPTS}/postinstall"

# 8. Limpiar archivos ocultos ._ de metadatos de Apple
dot_clean "${PKG_ROOT}" "${PKG_SCRIPTS}" 2>/dev/null || true
find "${PKG_ROOT}" "${PKG_SCRIPTS}" -name '._*' -delete 2>/dev/null || true
find "${PKG_ROOT}" "${PKG_SCRIPTS}" -name '.DS_Store' -delete 2>/dev/null || true
# Eliminar xattrs/AppleDouble heredados de fuentes o bundles antes de pkgbuild.
find "${PKG_ROOT}" "${PKG_SCRIPTS}" -exec xattr -c {} \; 2>/dev/null || true
xattr -cr "${PKG_ROOT}" "${PKG_SCRIPTS}" 2>/dev/null || true
if xattr -lr "${PKG_ROOT}" "${PKG_SCRIPTS}" 2>/dev/null | grep -q .; then
    echo "ERROR: quedaron atributos extendidos en el staging del paquete" >&2
    exit 2
fi

# 9. Empaquetar con pkgbuild
echo "[pkg] Empaquetando con /usr/bin/pkgbuild..."
pkgbuild \
    --root "${PKG_ROOT}" \
    --scripts "${PKG_SCRIPTS}" \
    --filter '(^|/)\._[^/]*$' \
    --filter '(^|/)\.DS_Store$' \
    --filter '(^|/)(\.svn|CVS)(/|$)' \
    --identifier "com.hp.smarttank500.driver.applesilicon" \
    --version "0.1.0-alpha" \
    --install-location "/" \
    "${OUT_PKG}"

echo ""
echo "======================================================================"
echo "  ¡PAQUETE INSTALADOR CREADO EXITOSAMENTE!"
echo "  Archivo: ${OUT_PKG}"
echo "  Tamaño: $(du -sh "${OUT_PKG}" | cut -f1)"
echo "======================================================================"
