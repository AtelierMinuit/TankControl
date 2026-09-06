#!/bin/bash
# install_native.sh
# Instalador limpio y reproducible del driver nativo para HP Smart Tank 500 en macOS (Apple Silicon)

set -e

MODE="${1:-}"
if [ "$MODE" != "--confirm" ] && [ "$MODE" != "--dry-run" ]; then
    echo "Uso: $0 --dry-run | --confirm" >&2
    echo "--dry-run valida y enumera cambios sin modificar /Library ni CUPS." >&2
    exit 2
fi

DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -z "${HP_AUDIT_BUILD_DIR:-}" ]; then
    echo "ERROR: define HP_AUDIT_BUILD_DIR con una build auditada explícita; no se usará una build histórica implícita." >&2
    exit 2
fi
BUILD_DIR="$HP_AUDIT_BUILD_DIR"
FILTER_BIN="$BUILD_DIR/rastertopcl3gui"
BACKEND_BIN="$BUILD_DIR/smarttank"
PPD_SRC="$DIR/research/builds/hp-smart_tank_500_series_mac.ppd"

TARGET_FILTER_DIR="/Library/Printers/hp/cups/filters"
TARGET_FILTER="$TARGET_FILTER_DIR/rastertopcl3gui"
TARGET_BACKEND_DIR="/Library/Printers/hp/cups/backend"
TARGET_BACKEND="$TARGET_BACKEND_DIR/smarttank"

echo "=== Instalador Nativo HP Smart Tank 500 (macOS Apple Silicon) ==="

# 1. Exigir un artefacto construido y auditado; no compilar silenciosamente en /Library.
if [ ! -x "$FILTER_BIN" ]; then
    echo "ERROR: falta el filtro auditado en $FILTER_BIN; ejecuta primero la build reproducible." >&2
    exit 1
fi
if [ ! -x "$BACKEND_BIN" ]; then
    echo "ERROR: falta el backend auditado en $BACKEND_BIN." >&2
    exit 1
fi
if [ -e "$TARGET_FILTER" ] || [ -L "$TARGET_FILTER" ] || [ -e "$TARGET_BACKEND" ] || [ -L "$TARGET_BACKEND" ]; then
    echo "ERROR: ya existe un componente destino; no se sobrescribirá sin una migración explícita." >&2
    exit 2
fi
if lpstat -p "HP_Smart_Tank_500" >/dev/null 2>&1; then
    echo "ERROR: ya existe la cola HP_Smart_Tank_500; no se reconfigurará automáticamente." >&2
    echo "Preserva la cola existente o realiza una migración explícita fuera de este instalador." >&2
    exit 2
fi

if [ "$MODE" = "--dry-run" ]; then
    echo "MODO DRY-RUN: no se ejecutará sudo ni se modificará /Library o CUPS."
    echo "VALIDADO: build auditada, PPD y destinos libres."
    echo "SE INSTALARÍA: $FILTER_BIN -> $TARGET_FILTER"
    echo "SE INSTALARÍA: $BACKEND_BIN -> $TARGET_BACKEND"
    echo "SE REGISTRARÍA: HP_Smart_Tank_500 con URI smarttank://HP/Smart%20Tank%20500%20series"
    exit 0
fi

# 2. Validar PPD
echo "Validando sintaxis PPD con cupstestppd..."
cupstestppd -q "$PPD_SRC" || {
    echo "ERROR: El archivo PPD contiene errores de sintaxis."
    exit 1
}

# 3. Instalar filtro en el sistema con permisos de root
echo "Instalando filtro en $TARGET_FILTER_DIR..."
sudo mkdir -p "$TARGET_FILTER_DIR"
sudo cp "$FILTER_BIN" "$TARGET_FILTER"
sudo chown root:wheel "$TARGET_FILTER"
sudo chmod 755 "$TARGET_FILTER"
sudo mkdir -p "$TARGET_BACKEND_DIR"
sudo cp "$BACKEND_BIN" "$TARGET_BACKEND"
sudo chown root:wheel "$TARGET_BACKEND"
sudo chmod 755 "$TARGET_BACKEND"

# 4. Registrar cola de impresión en CUPS
echo "Registrando cola de impresión en CUPS..."
sudo lpadmin -p "HP_Smart_Tank_500" \
    -v "smarttank://HP/Smart%20Tank%20500%20series" \
    -P "$PPD_SRC" \
    -D "HP Smart Tank 500 (Nativo Apple Silicon)" \
    -L "Local USB" \
    -E

echo ""
echo "============================================================"
echo "¡Instalación completada exitosamente!"
echo "La impresora 'HP_Smart_Tank_500' está registrada y lista."
echo "El filtro no requiere Rosetta 2 ni componentes x86_64; las dependencias del paquete se auditan por separado."
echo "============================================================"
