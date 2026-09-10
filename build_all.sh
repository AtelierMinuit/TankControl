#!/usr/bin/env bash
# ==============================================================================
# build_all.sh — Build Automation & Packaging Pipeline for HP Smart Tank 500
#
# Compila todos los componentes C, construye la aplicación TankControl SwiftUI,
# ejecuta la suite de pruebas unitarias y genera los paquetes .pkg y .dmg oficiales.
# ==============================================================================

set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${HP_AUDIT_BUILD_DIR:-${ROOT_DIR}/research/builds/audit-clean/night-20260904}"

# Colores de consola
C_RESET='\033[0m'
C_BOLD='\033[1m'
C_GREEN='\033[32m'
C_CYAN='\033[36m'
C_YELLOW='\033[33m'
C_RED='\033[31m'

info() { echo -e "${C_CYAN}${C_BOLD}[build_all]${C_RESET} $*"; }
success() { echo -e "${C_GREEN}${C_BOLD}[✓]${C_RESET} $*"; }
warn() { echo -e "${C_YELLOW}${C_BOLD}[!]${C_RESET} $*"; }
error() { echo -e "${C_RED}${C_BOLD}[✗] ERROR:${C_RESET} $*" >&2; }

print_usage() {
    cat << 'HELP'
Uso: ./build_all.sh [OPCIONES]

Opciones:
  --all         Construye binarios C, TankControl.app, corre pruebas y genera PKG y DMG (por defecto)
  --binaries    Compila únicamente los binarios C (filtro CUPS, backend, herramientas CLI)
  --app         Compila únicamente la aplicación TankControl SwiftUI
  --test        Ejecuta la suite completa de pruebas unitarias automatizadas
  --pkg         Genera el paquete instalador multilingüe .pkg
  --dmg         Genera la imagen de disco distribuible .dmg
  --clean       Limpia directorios de staging y artefactos temporales
  -h, --help    Muestra esta ayuda
HELP
}

# Modos de ejecución
DO_BINARIES=0
DO_APP=0
DO_TEST=0
DO_PKG=0
DO_DMG=0
DO_CLEAN=0

if [ $# -eq 0 ]; then
    DO_BINARIES=1
    DO_APP=1
    DO_TEST=1
    DO_PKG=1
    DO_DMG=1
else
    while [ $# -gt 0 ]; do
        case "$1" in
            --all)
                DO_BINARIES=1
                DO_APP=1
                DO_TEST=1
                DO_PKG=1
                DO_DMG=1
                ;;
            --binaries)
                DO_BINARIES=1
                ;;
            --app)
                DO_APP=1
                ;;
            --test)
                DO_TEST=1
                ;;
            --pkg)
                DO_PKG=1
                ;;
            --dmg)
                DO_DMG=1
                ;;
            --clean)
                DO_CLEAN=1
                ;;
            -h|--help)
                print_usage
                exit 0
                ;;
            *)
                error "Opción desconocida: $1"
                print_usage
                exit 1
                ;;
        esac
        shift
    done
fi

# ------------------------------------------------------------------------------
# Limpieza
# ------------------------------------------------------------------------------
if [ $DO_CLEAN -eq 1 ]; then
    info "Limpiando artefactos temporales y directorios de staging..."
    rm -rf "${ROOT_DIR}/research/staging"/package_* "${ROOT_DIR}/research/staging"/dmg_* "${ROOT_DIR}/research/staging"/pb_*
    find "${ROOT_DIR}" -name ".DS_Store" -delete 2>/dev/null || true
    find "${ROOT_DIR}" -name "._*" -delete 2>/dev/null || true
    success "Limpieza completada."
    if [ $DO_BINARIES -eq 0 ] && [ $DO_APP -eq 0 ] && [ $DO_TEST -eq 0 ] && [ $DO_PKG -eq 0 ] && [ $DO_DMG -eq 0 ]; then
        exit 0
    fi
fi

echo "======================================================================"
echo -e "${C_BOLD}  HP SMART TANK 500 — PIPELINE DE CONSTRUCCIÓN INTEGRAL${C_RESET}"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Verificación del entorno
# ------------------------------------------------------------------------------
info "Verificando herramientas del sistema..."
for tool in clang swiftc python3 pkgbuild productbuild hdiutil codesign; do
    if ! command -v "$tool" &>/dev/null; then
        error "Herramienta obligatoria ausente: $tool"
        exit 1
    fi
done
success "Herramientas de compilación verificadas."

mkdir -p "${BUILD_DIR}"

# ------------------------------------------------------------------------------
# 2. Compilación de binarios C
# ------------------------------------------------------------------------------
if [ $DO_BINARIES -eq 1 ]; then
    info "Compilando binarios del controlador C (Apple Silicon ARM64)..."

    USB_INC=""
    USB_LIB=""
    if [ -d "/opt/homebrew/include/libusb-1.0" ]; then
        USB_INC="-I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include"
        USB_LIB="-L/opt/homebrew/lib"
    elif [ -d "/usr/local/include/libusb-1.0" ]; then
        USB_INC="-I/usr/local/include/libusb-1.0 -I/usr/local/include"
        USB_LIB="-L/usr/local/lib"
    fi

    # Filtro RIP PCL3GUI
    info "  -> Compilando rastertopcl3gui..."
    clang -O2 -Wall -Wextra -Wpedantic "${ROOT_DIR}/tools/rastertopcl3gui.c" -lcups -o "${BUILD_DIR}/rastertopcl3gui"
    cp -X "${BUILD_DIR}/rastertopcl3gui" "${ROOT_DIR}/tools/rastertopcl3gui"

    # Backend CUPS bidireccional smarttank
    info "  -> Compilando smarttank (backend CUPS)..."
    clang -O2 -Wall -Wextra ${USB_INC} "${ROOT_DIR}/tools/cups_backend_smarttank.c" ${USB_LIB} -lusb-1.0 -lcups -o "${BUILD_DIR}/smarttank"
    
    # Herramienta de escaneo USB directa hp_scan
    info "  -> Compilando hp_scan..."
    clang -O2 -Wall -Wextra ${USB_INC} "${ROOT_DIR}/tools/hp_scan.c" ${USB_LIB} -lusb-1.0 -lcups -o "${BUILD_DIR}/hp_scan"

    # Herramienta de telemetría y estado de bajo nivel hp-smart-tank-tool
    info "  -> Compilando hp-smart-tank-tool..."
    clang -O2 -Wall -Wextra ${USB_INC} "${ROOT_DIR}/tools/hp-smart-tank-tool.c" ${USB_LIB} -lusb-1.0 -lcups -o "${BUILD_DIR}/hp-smart-tank-tool"

    success "Binarios C compilados correctamente en: ${BUILD_DIR}"
fi

# ------------------------------------------------------------------------------
# 3. Construcción de TankControl.app (SwiftUI)
# ------------------------------------------------------------------------------
if [ $DO_APP -eq 1 ]; then
    info "Construyendo aplicación nativa TankControl.app..."
    "${ROOT_DIR}/apps/HPSmartTankUtility/build_app.sh"
    success "TankControl.app empaquetada, con @rpath autónomo y firmada."
fi

# ------------------------------------------------------------------------------
# 4. Ejecución de la suite de pruebas unitarias
# ------------------------------------------------------------------------------
if [ $DO_TEST -eq 1 ]; then
    info "Ejecutando suite completa de pruebas automatizadas..."
    python3 -m unittest discover -s "${ROOT_DIR}/tests"
    success "¡Todas las pruebas pasaron satisfactoriamente (100% PASS)!"
fi

# ------------------------------------------------------------------------------
# 5. Generación del paquete instalador .pkg
# ------------------------------------------------------------------------------
if [ $DO_PKG -eq 1 ]; then
    info "Generando paquete instalador oficial .pkg..."
    "${ROOT_DIR}/package_dist.sh"
    success "Paquete .pkg generado con éxito."
fi

# ------------------------------------------------------------------------------
# 6. Generación de la imagen de disco .dmg
# ------------------------------------------------------------------------------
if [ $DO_DMG -eq 1 ]; then
    info "Generando imagen de disco instalable (.dmg)..."
    "${ROOT_DIR}/package_dmg.sh"
    success "Imagen .dmg generada y verificada."
fi

echo ""
echo "======================================================================"
echo -e "${C_GREEN}${C_BOLD}  ¡PIPELINE DE CONSTRUCCIÓN COMPLETADO CON ÉXITO!${C_RESET}"
echo "======================================================================"
