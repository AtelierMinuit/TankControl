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
LATEST_DIST_PKG="$(ls -t "${DIR}/research/builds"/HP_Smart_Tank_500_macOS_Installer-*.pkg 2>/dev/null | head -n 1 || true)"
if [ -n "${LATEST_DIST_PKG}" ] && [ -f "${LATEST_DIST_PKG}" ]; then
    INSTALLER_PKG_SOURCE="${LATEST_DIST_PKG}"
    echo "[dmg] Utilizando paquete de distribución multilingüe: ${INSTALLER_PKG_SOURCE}"
elif [ -n "${LATEST_PKG}" ] && [ -f "${LATEST_PKG}" ]; then
    INSTALLER_PKG_SOURCE="${LATEST_PKG}"
    echo "[dmg] Utilizando paquete de componente: ${INSTALLER_PKG_SOURCE}"
else
    echo "ERROR: no se encontró ningún paquete .pkg generado" >&2
    exit 2
fi

# 3. Preparar directorio de staging para el DMG
mkdir -p "${DMG_STAGE}"

echo "[dmg] Copiando TankControl.app al staging..."
cp -RX "${BUILD_DIR}/TankControl.app" "${DMG_STAGE}/"

echo "[dmg] Copiando instalador oficial como 'Instalador HP Smart Tank 500.pkg'..."
cp -X "${INSTALLER_PKG_SOURCE}" "${DMG_STAGE}/Instalador HP Smart Tank 500.pkg"

echo "[dmg] Creando acceso directo a la carpeta Aplicaciones..."
ln -s /Applications "${DMG_STAGE}/Aplicaciones"

echo "[dmg] Generando guías multilingües (ES, EN, PT, FR, DE)..."

cat << 'INSTRUCTIONS_ES' > "${DMG_STAGE}/LEEME_ES.txt"
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
   - Selector de idioma en Configuración (Español, English, Português, Français, Deutsch).

Requisitos: macOS 12.0 Monterey o superior (Apple Silicon M1/M2/M3/M4 nativo).
======================================================================
INSTRUCTIONS_ES

cp "${DMG_STAGE}/LEEME_ES.txt" "${DMG_STAGE}/LEEME_PRIMERO.txt"

cat << 'INSTRUCTIONS_EN' > "${DMG_STAGE}/README_EN.txt"
======================================================================
  HP SMART TANK 500 SERIES — OFFICIAL MACOS PACKAGE (APPLE SILICON)
======================================================================

Welcome to the official driver and utility package for macOS:

1. DRIVER INSTALLATION (CUPS DRIVER):
   Double-click "Instalador HP Smart Tank 500.pkg" and follow the macOS
   installer instructions.
   - Configures the native ARM64 RIP engine (rastertopcl3gui).
   - Installs ColorSync ICC profiles for plain, photo, and matte papers.
   - Integrates InkSaver technology with continuous 0% to 75% savings.
   - Enables "Fast Draft Mode" at 300 DPI for high-speed printing.
   - Automatically configures the HP_Smart_Tank_500 CUPS print queue.

2. MONITORING & UTILITY APPLICATION (TANKCONTROL):
   Drag "TankControl.app" into the "Aplicaciones" (Applications) folder.
   - Real physical ink level telemetry (GT51/GT52/GT53).
   - Hardware odometer for lifetime and session page counts.
   - 1-click toggle for Fast Draft / Normal output modes.
   - Interactive InkSaver comparator with typographic edge preservation.
   - Native USB scanning and printhead maintenance.
   - Language picker in Settings (Spanish, English, Portuguese, French, German).

Requirements: macOS 12.0 Monterey or higher (Native Apple Silicon M1/M2/M3/M4).
======================================================================
INSTRUCTIONS_EN

cat << 'INSTRUCTIONS_PT' > "${DMG_STAGE}/LEIA_ME_PT.txt"
======================================================================
  HP SMART TANK 500 SERIES — PACOTE OFICIAL MACOS (APPLE SILICON)
======================================================================

Bem-vindo ao pacote oficial de driver e utilitários para macOS:

1. INSTALAÇÃO DO DRIVER (CUPS):
   Dê um duplo clique em "Instalador HP Smart Tank 500.pkg" e siga as
   instruções do instalador do macOS.
   - Configura o motor RIP nativo ARM64 (rastertopcl3gui).
   - Instala perfis ColorSync ICC para papéis comum, fotográfico e fosco.
   - Integra a tecnologia InkSaver com economia contínua de 0% a 75%.
   - Habilita o "Modo Rascunho Rápido" a 300 DPI para alta velocidade.
   - Configura ou atualiza a fila de impressão HP_Smart_Tank_500.

2. APLICATIVO DE CONTROLE E TELEMETRIA (TANKCONTROL):
   Arraste o "TankControl.app" para a pasta "Aplicaciones" (Aplicativos).
   - Leitura em tempo real dos níveis de tinta CISS (GT51/GT52/GT53).
   - Odômetro e telemetria de páginas físicas impressas.
   - Alternador de 1 clique para Modo Rascunho Rápido / Modo Normal.
   - Comparador visual interativo InkSaver com preservação tipográfica.
   - Digitalização USB nativa e manutenção de cabeçotes.
   - Seletor de idioma nas Configurações (Espanhol, Inglês, Português, Francês, Alemão).

Requisitos: macOS 12.0 Monterey ou superior (Nativo Apple Silicon M1/M2/M3/M4).
======================================================================
INSTRUCTIONS_PT

cat << 'INSTRUCTIONS_FR' > "${DMG_STAGE}/LISEZ_MOI_FR.txt"
======================================================================
  HP SMART TANK 500 SERIES — PAQUET OFFICIEL MACOS (APPLE SILICON)
======================================================================

Bienvenue dans le paquet officiel de pilote et d'utilitaire pour macOS :

1. INSTALLATION DU PILOTE (PILOTE CUPS) :
   Double-cliquez sur "Instalador HP Smart Tank 500.pkg" et suivez les
   instructions de l'installateur macOS.
   - Configure le moteur RIP natif ARM64 (rastertopcl3gui).
   - Installe les profils ColorSync ICC pour papiers standard, photo et mat.
   - Intègre la technologie InkSaver avec économie continue de 0% à 75%.
   - Active le "Mode Brouillon Rapide" à 300 DPI pour une impression rapide.
   - Configure automatiquement la file d'attente HP_Smart_Tank_500.

2. APPLICATION DE CONTRÔLE ET TÉLÉMÉTRIE (TANKCONTROL) :
   Faites glisser "TankControl.app" dans le dossier "Aplicaciones" (Applications).
   - Lecture en temps réel des niveaux d'encre CISS (GT51/GT52/GT53).
   - Odomètre et télémétrie des pages imprimées.
   - Commutateur 1-clic pour Mode Brouillon Rapide / Mode Normal.
   - Comparateur visuel interactif InkSaver avec préservation des contours.
   - Numérisation USB native et entretien des têtes d'impression.
   - Sélecteur de langue dans les Réglages (Espagnol, Anglais, Portugais, Français, Allemand).

Configuration requise : macOS 12.0 Monterey ou supérieur (Apple Silicon M1/M2/M3/M4).
======================================================================
INSTRUCTIONS_FR

cat << 'INSTRUCTIONS_DE' > "${DMG_STAGE}/LIESMICH_DE.txt"
======================================================================
  HP SMART TANK 500 SERIES — OFFIZIELLES MACOS-PAKET (APPLE SILICON)
======================================================================

Willkommen beim offiziellen Treiber- und Dienstprogramm-Paket für macOS:

1. TREIBERINSTALLATION (CUPS-TREIBER):
   Doppelklicken Sie auf "Instalador HP Smart Tank 500.pkg" und folgen Sie
   den Anweisungen des macOS-Installationsprogramms.
   - Richtet die native ARM64-RIP-Engine (rastertopcl3gui) ein.
   - Installiert ColorSync ICC-Profile für Normal-, Foto- und Mattpapier.
   - Integriert InkSaver-Technologie mit kontinuierlicher Einsparung von 0% bis 75%.
   - Aktiviert den "Schnellentwurf-Modus" mit 300 DPI für schnellen Druck.
   - Konfiguriert die CUPS-Druckwarteschlange HP_Smart_Tank_500.

2. KONTROLL- UND TELEMETRIE-ANWENDUNG (TANKCONTROL):
   Ziehen Sie "TankControl.app" in den Ordner "Aplicaciones" (Programme).
   - Echtzeit-Überwachung der Tintenstände (GT51/GT52/GT53).
   - Hardware-Kilometerzähler für gedruckte Seiten.
   - 1-Klick-Umschaltung für Schnellentwurf / Normalmodus.
   - Interaktiver InkSaver-Vergleich mit Kantenkonturierung.
   - Nativer USB-Scan und Druckkopf-Wartung.
   - Sprachauswahl in den Einstellungen (Spanisch, Englisch, Portugiesisch, Französisch, Deutsch).

Voraussetzungen: macOS 12.0 Monterey oder höher (Natives Apple Silicon M1/M2/M3/M4).
======================================================================
INSTRUCTIONS_DE

cat << 'INSTRUCTIONS_README' > "${DMG_STAGE}/LEEME_README.txt"
======================================================================
  HP SMART TANK 500 SERIES — MACOS INSTALLATION GUIDES / GUÍAS
======================================================================

Select your preferred language / Seleccione su idioma / Selecione seu idioma:

  • Español:      LEEME_ES.txt
  • English:      README_EN.txt
  • Português:    LEIA_ME_PT.txt
  • Français:     LISEZ_MOI_FR.txt
  • Deutsch:      LIESMICH_DE.txt

Quick Start:
1. Double-click "Instalador HP Smart Tank 500.pkg" to install drivers.
2. Drag "TankControl.app" to "Aplicaciones" (Applications).
======================================================================
INSTRUCTIONS_README

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
