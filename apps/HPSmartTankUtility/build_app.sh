#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="${SCRIPT_DIR}/../.."
BUILD_DIR="${HP_AUDIT_BUILD_DIR:-${ROOT_DIR}/research/builds/audit-clean/night-20260904}"

APP_NAME="TankControl"
APP_DIR="${HP_APP_OUTPUT_DIR:-${BUILD_DIR}/${APP_NAME}.app}"
BIN_NAME="${APP_NAME}"

echo "[build_app] Creando estructura de bundle para ${APP_DIR}..."
mkdir -p "${APP_DIR}/Contents/MacOS"
mkdir -p "${APP_DIR}/Contents/Resources"
mkdir -p "${APP_DIR}/Contents/Helpers"
mkdir -p "${APP_DIR}/Contents/Frameworks"

echo "[build_app] Recopilando fuentes modulares Swift..."
SWIFT_FILES=$(find "${SCRIPT_DIR}/Sources" -name "*.swift" | sort)

echo "[build_app] Compilando binario Swift nativo (ARM64 Apple Silicon) para macOS 12.0+..."
swiftc -O \
    -target arm64-apple-macos12.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -framework UserNotifications \
    ${SWIFT_FILES} \
    -o "${APP_DIR}/Contents/MacOS/${BIN_NAME}"

echo "[build_app] Embebiendo libusb dinámico autónomo en Contents/Frameworks..."
if [ -f "${ROOT_DIR}/lib/libusb-1.0.0.dylib" ]; then
    cp -X "${ROOT_DIR}/lib/libusb-1.0.0.dylib" "${APP_DIR}/Contents/Frameworks/"
    chmod 755 "${APP_DIR}/Contents/Frameworks/libusb-1.0.0.dylib"
    install_name_tool -id @rpath/libusb-1.0.0.dylib "${APP_DIR}/Contents/Frameworks/libusb-1.0.0.dylib" 2>/dev/null || true
fi

echo "[build_app] Copiando helpers de hardware y vinculando a @rpath/Frameworks..."
if [ -f "${BUILD_DIR}/hp-smart-tank-tool" ]; then
    cp -X "${BUILD_DIR}/hp-smart-tank-tool" "${APP_DIR}/Contents/Helpers/"
fi
if [ -f "${BUILD_DIR}/hp_scan" ]; then
    cp -X "${BUILD_DIR}/hp_scan" "${APP_DIR}/Contents/Helpers/"
fi

for helper in "${APP_DIR}/Contents/Helpers/hp-smart-tank-tool" "${APP_DIR}/Contents/Helpers/hp_scan"; do
    if [ -f "$helper" ]; then
        chmod 755 "$helper"
        install_name_tool -change /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib @rpath/libusb-1.0.0.dylib "$helper" 2>/dev/null || true
        install_name_tool -add_rpath @executable_path/../Frameworks "$helper" 2>/dev/null || true
        install_name_tool -add_rpath @loader_path/../Frameworks "$helper" 2>/dev/null || true
        install_name_tool -add_rpath /usr/local/lib "$helper" 2>/dev/null || true
    fi
done

# Copiar nuevo icono oficial de marca TankControl
if [ -f "${ROOT_DIR}/Brand/AppIcon/AppIcon.icns" ]; then
    cp "${ROOT_DIR}/Brand/AppIcon/AppIcon.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
elif [ -f "${ROOT_DIR}/research/builds/HP_Smart_Tank_500.icns" ]; then
    cp "${ROOT_DIR}/research/builds/HP_Smart_Tank_500.icns" "${APP_DIR}/Contents/Resources/AppIcon.icns"
fi

echo "[build_app] Generando Info.plist de TankControl..."
cat << 'PLIST' > "${APP_DIR}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>es</string>
    <key>CFBundleExecutable</key>
    <string>TankControl</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>org.openprinting.tankcontrol</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>TankControl</string>
    <key>CFBundleDisplayName</key>
    <string>TankControl</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>2.0.0</string>
    <key>CFBundleVersion</key>
    <string>2.0.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Open Source TankControl Driver for macOS Apple Silicon (Compatible with HP Smart Tank 500 Series)</string>
</dict>
</plist>
PLIST

echo "[build_app] Aplicando firma ad-hoc a componentes internos y bundle..."
if [ -d "${APP_DIR}/Contents/Frameworks" ]; then
    for fw in "${APP_DIR}/Contents/Frameworks"/*; do
        [ -f "$fw" ] || continue
        codesign --force --sign - "$fw"
    done
fi
if [ -d "${APP_DIR}/Contents/Helpers" ]; then
    for helper in "${APP_DIR}/Contents/Helpers"/*; do
        [ -f "$helper" ] || continue
        codesign --force --sign - "$helper"
    done
fi
codesign --force --deep --sign - "${APP_DIR}"

# Mantener compatibilidad retroactiva con la ruta heredada "HP Smart Tank Utility.app"
LEGACY_APP_DIR="${BUILD_DIR}/HP Smart Tank Utility.app"
if [ "${APP_DIR}" != "${LEGACY_APP_DIR}" ]; then
    echo "[build_app] Creando bundle de compatibilidad para ruta heredada: ${LEGACY_APP_DIR}..."
    rm -rf "${LEGACY_APP_DIR}"
    cp -R "${APP_DIR}" "${LEGACY_APP_DIR}"
    ln -sf "TankControl" "${LEGACY_APP_DIR}/Contents/MacOS/HP Smart Tank Utility"
    codesign --force --deep --sign - "${LEGACY_APP_DIR}"
fi

echo "[build_app] ¡Aplicación TankControl construida exitosamente en: ${APP_DIR}!"
