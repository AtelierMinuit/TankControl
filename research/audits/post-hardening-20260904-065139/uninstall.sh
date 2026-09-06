#!/bin/bash
# uninstall.sh
# Desinstalador limpio para HP Smart Tank 500 en macOS

set -u

echo "=== Desinstalador HP Smart Tank 500 ==="

DRY_RUN=0
CONFIRM=0
case "${1:-}" in
    --dry-run) DRY_RUN=1 ;;
    --confirm) CONFIRM=1 ;;
    "") ;;
    *) echo "Uso: $0 --dry-run | --confirm" >&2; exit 2 ;;
esac
if [ "$DRY_RUN" -eq 0 ] && [ "$CONFIRM" -eq 0 ]; then
    echo "Refusando cambios: ejecute primero --dry-run y luego use --confirm para desinstalar." >&2
    exit 2
fi
if [ "$DRY_RUN" -eq 1 ]; then
    echo "MODO DRY-RUN: no se eliminará ni modificará ningún archivo o cola."
fi

OWNED_FILES=(
    "/Library/Printers/hp/cups/filters/rastertopcl3gui"
    "/Library/Printers/hp/cups/backend/smarttank"
    "/usr/libexec/cups/backend/smarttank"
    "/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd"
    "/Library/Printers/hp/Icons/HP_Smart_Tank_500.icns"
    "/Library/ColorSync/Profiles/HP_Smart_Tank_Plain.icc"
    "/Library/ColorSync/Profiles/HP_Smart_Tank_Glossy.icc"
    "/Library/ColorSync/Profiles/HP_Smart_Tank_Matte.icc"
    "/Library/ColorSync/Profiles/HP_Smart_Tank_500_Precision.icc"
    "/usr/local/bin/hp-smart-tank"
    "/usr/local/bin/hp-smart-tank-tool"
    "/usr/local/bin/hp_scan"
    "/usr/local/bin/smarttank"
    "/usr/local/lib/libusb-1.0.0.dylib"
    "/usr/local/share/hp-smart-tank/hp_escl_bridge.py"
    "/usr/local/share/hp-smart-tank/hp_smart_tank.py"
    "/usr/local/share/hp-smart-tank/smart_tank_daemon.sh"
    "/usr/local/share/hp-smart-tank/generate_color_target.py"
    "/usr/local/share/hp-smart-tank/calibrate_icc.py"
    "/usr/local/share/hp-smart-tank/uninstall.sh"
    "/Library/LaunchAgents/com.hp.smarttank.airscan.plist"
    "/Applications/HP Smart Tank Utility.app"
)

if [ "$DRY_RUN" -eq 1 ]; then
    if lpstat -v "HP_Smart_Tank_500" 2>/dev/null | grep -q 'smarttank://'; then
        echo "COLA DEL PROYECTO: HP_Smart_Tank_500 (URI smarttank; no se eliminará en dry-run)"
    elif lpstat -p "HP_Smart_Tank_500" >/dev/null 2>&1; then
        echo "COLA CON NOMBRE COINCIDENTE PERO URI AJENA: HP_Smart_Tank_500 (se preservará)"
    else
        echo "COLA DEL PROYECTO: HP_Smart_Tank_500 (ausente)"
    fi
    for path in "${OWNED_FILES[@]}"; do
        if [ -e "$path" ]; then
            echo "PROPIEDAD DEL PROYECTO: PRESENTE $path"
        else
            echo "PROPIEDAD DEL PROYECTO: AUSENTE $path"
        fi
    done
    echo "DRY-RUN completado: no se modificó ningún archivo ni cola."
    exit 0
fi

# 1. Eliminar cola de CUPS
if lpstat -v "HP_Smart_Tank_500" 2>/dev/null | grep -q 'smarttank://'; then
    echo "Eliminando cola de impresión 'HP_Smart_Tank_500'..."
    if [ "$DRY_RUN" -eq 0 ]; then sudo lpadmin -x "HP_Smart_Tank_500"; fi
fi

# 2. Eliminar exclusivamente archivos manifestados como propios
for path in "${OWNED_FILES[@]}"; do
    [ -e "$path" ] || continue
    if [ "$path" = "/Applications/HP Smart Tank Utility.app" ] && \
       ! pkgutil --pkg-info "com.hp.smarttank500.driver.applesilicon" >/dev/null 2>&1; then
        echo "Preservando app: no existe recibo de instalación del paquete propio." >&2
        continue
    fi
    if [ -L "$path" ]; then
        target=$(readlink "$path" 2>/dev/null || true)
        if [ "$path" != "/usr/libexec/cups/backend/smarttank" ] || [ "$target" != "/Library/Printers/hp/cups/backend/smarttank" ]; then
            echo "Preservando symlink ajeno al proyecto: $path -> $target" >&2
            continue
        fi
    fi
    echo "Eliminando $path..."
    if [ -d "$path" ]; then sudo rm -rf -- "$path"; else sudo rm -f -- "$path"; fi
done

if [ "$DRY_RUN" -eq 1 ]; then echo "DRY-RUN completado."; else echo "Desinstalación completada."; fi
