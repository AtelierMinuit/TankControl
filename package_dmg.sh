#!/usr/bin/env bash
# ==============================================================================
# package_dmg.sh
# Construcción de la imagen de disco instalable (.dmg) para HP Smart Tank 500 en macOS
# ==============================================================================

set -Eeuo pipefail
export COPYFILE_DISABLE=1

DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${HP_AUDIT_BUILD_DIR:-${DIR}/research/builds/audit-clean/night-20260904}"
STAGE_TAG="$(date '+%Y%m%d-%H%M%S')"
DMG_STAGE="${DIR}/research/staging/dmg_stage-${STAGE_TAG}"
OUT_DMG="${DIR}/research/builds/HP_Smart_Tank_500_macOS_Instalador.dmg"

echo "=== Construyendo Imagen de Disco Instalable (.DMG) Oficial ==="

# 1. Asegurar que TankControl.app esté compilada y firmada
if [ ! -d "${BUILD_DIR}/TankControl.app" ]; then
    echo "[dmg] Compilando TankControl.app..."
    "${DIR}/apps/HPSmartTankUtility/build_app.sh"
fi

# 2. Generar el paquete instalador .pkg oficial más reciente
echo "[dmg] Generando paquete instalador .pkg oficial..."
"${DIR}/package_dist.sh"

LATEST_PKG="$(ls -t "${DIR}/research/builds"/HP_Smart_Tank_500_Native_Apple_Silicon-*.pkg | head -n 1)"
if [ -z "${LATEST_PKG}" ] || [ ! -f "${LATEST_PKG}" ]; then
    echo "ERROR: no se encontró el paquete .pkg generado" >&2
    exit 2
fi
echo "[dmg] Paquete .pkg localizado: ${LATEST_PKG}"

# 3. Preparar directorio de staging para el DMG
mkdir -p "${DMG_STAGE}"

echo "[dmg] Copiando TankControl.app al staging..."
cp -RX "${BUILD_DIR}/TankControl.app" "${DMG_STAGE}/"

echo "[dmg] Copiando instalador oficial como 'Instalador HP Smart Tank 500.pkg'..."
cp -X "${LATEST_PKG}" "${DMG_STAGE}/Instalador HP Smart Tank 500.pkg"

echo "[dmg] Creando acceso directo a la carpeta Aplicaciones..."
ln -s /Applications "${DMG_STAGE}/Aplicaciones"

echo "[dmg] Generando archivo LEEME_PRIMERO.txt..."
cat << 'INSTRUCTIONS' > "${DMG_STAGE}/LEEME_PRIMERO.txt"
======================================================================
  HP SMART TANK 500 SERIES — PAQUETE OFICIAL MACOS (APPLE SILICON)
======================================================================

Bienvenido al paquete de instalación y utilidad oficial para macOS:

1. INSTALACIÓN DEL CONTROLADOR (DRIVER CUPS):
   Haga doble clic en "Instalador HP Smart Tank 500.pkg" y siga las
   instrucciones del instalador de macOS.
   - Configura el motor RIP nativo ARM64 (rastertopcl3gui).
   - Instala perfiles ColorSync ICC de calibración fotográfica y común.
   - Integra la tecnología InkSaver con ahorro continuo de 0% a 75%.
   - Habilita el "Modo Rápido Borrador (Fast Draft)" a 300 DPI y alta velocidad.
   - Configura o actualiza la cola de impresión HP_Smart_Tank_500.

2. APLICACIÓN DE CONTROL Y TELEMETRÍA (TANKCONTROL):
   Arrastre "TankControl.app" a la carpeta "Aplicaciones".
   - Lectura de niveles reales de tinta CISS (GT51/GT52/GT53).
   - Odómetro y telemetría de páginas físicas procesadas.
   - Conmutador de 1 clic para Modo Rápido Borrador / Modo Normal.
   - Comparador visual interactivo InkSaver con preservación tipográfica.
   - Escaneo nativo por USB y mantenimiento de cabezales.

Requisitos: macOS 12.0 Monterey o superior (Apple Silicon M1/M2/M3/M4 nativo).
======================================================================
INSTRUCTIONS

# 4. Limpieza de metadatos de Apple
dot_clean "${DMG_STAGE}" 2>/dev/null || true
find "${DMG_STAGE}" -name '._*' -delete 2>/dev/null || true
find "${DMG_STAGE}" -name '.DS_Store' -delete 2>/dev/null || true

# 5. Generar imagen de disco DMG comprimida con hdiutil
echo "[dmg] Creando imagen de disco DMG con hdiutil..."
rm -f "${OUT_DMG}"

hdiutil create \
    -volname "HP Smart Tank 500" \
    -srcfolder "${DMG_STAGE}" \
    -ov \
    -format UDZO \
    "${OUT_DMG}"

echo ""
echo "======================================================================"
echo "  ¡IMAGEN DE DISCO (.DMG) CREADA EXITOSAMENTE!"
echo "  Archivo: ${OUT_DMG}"
echo "  Tamaño: $(du -sh "${OUT_DMG}" | cut -f1)"
echo "======================================================================"

# 6. Verificación de montaje y estructura
echo "[dmg] Verificando montaje de la imagen..."
MOUNT_DIR="$(mktemp -d /tmp/hp_dmg_check.XXXXXX)"
hdiutil attach "${OUT_DMG}" -mountpoint "${MOUNT_DIR}" -readonly -nobrowse -quiet
echo "[dmg] Contenido de la imagen montada:"
ls -la "${MOUNT_DIR}"
hdiutil detach "${MOUNT_DIR}" -quiet
rmdir "${MOUNT_DIR}"

echo "[dmg] ¡Verificación completada! La imagen de disco está lista para su distribución."
