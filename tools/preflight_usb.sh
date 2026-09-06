#!/usr/bin/env bash
# ==============================================================================
# preflight_usb.sh — Diagnóstico Rápido de Conexión USB para HP Smart Tank 500
# Diseñado para verificar el hardware en 3 segundos al conectar el cable físico.
# ==============================================================================

set -u

DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="${DIR}/research/builds/audit-clean/night-20260904"
TOOL="${BIN_DIR}/hp-smart-tank-tool"

# Códigos ANSI para salida en terminal
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_RED="\033[31m"
C_CYAN="\033[36m"

echo -e "${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_BOLD}  PREVUELO USB — HP SMART TANK 500 SERIES (macOS Apple Silicon)${C_RESET}"
echo -e "${C_BOLD}======================================================================${C_RESET}"
echo -e "Fecha: $(date "+%Y-%m-%d %H:%M:%S")"
echo ""

PASSED=0
WARNINGS=0
ERRORS=0

# ------------------------------------------------------------------------------
# 1. Detección en Bus USB de macOS (IOKit)
# ------------------------------------------------------------------------------
echo -e "${C_BOLD}[1/5] Inspeccionando Bus USB (IOKit)...${C_RESET}"
USB_INFO=$(ioreg -p IOUSB -l 2>/dev/null | grep -E "idVendor|idProduct|USB Product Name" | grep -B2 -A2 "Smart Tank 500" || true)

if [ -z "$USB_INFO" ]; then
    # Fallback por VID (0x03F0) y PID (0x1454)
    USB_INFO=$(ioreg -p IOUSB -l 2>/dev/null | grep -E ""idVendor" = 1008" -A1 | grep ""idProduct" = 5204" || true)
fi

if [ -n "$USB_INFO" ]; then
    echo -e "  ${C_GREEN}✔ DETECTADA:${C_RESET} Dispositivo HP Smart Tank 500 presente en el bus USB."
    PASSED=$((PASSED + 1))
else
    echo -e "  ${C_YELLOW}⚠ NO DETECTADA EN USB:${C_RESET} No se encontró un dispositivo con VID 0x03F0 y PID 0x1454."
    echo -e "    ${C_CYAN}Sugerencia:${C_RESET} Conecte el cable USB tipo B a la impresora y asegúrese de que esté encendida."
    WARNINGS=$((WARNINGS + 1))
fi

# ------------------------------------------------------------------------------
# 2. Comunicación de Bajo Nivel (Canal EWS / LEDM)
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_BOLD}[2/5] Comprobando comunicación con firmware EWS/LEDM...${C_RESET}"
if [ -x "$TOOL" ]; then
    TOOL_STATUS=$("$TOOL" status 2>&1 || true)
    if echo "$TOOL_STATUS" | grep -q "No se pudo abrir"; then
        echo -e "  ${C_YELLOW}⚠ CANAL EWS CERRADO:${C_RESET} La impresora no responde en la interfaz USB 2."
        echo -e "    Detalle: ${TOOL_STATUS}"
        WARNINGS=$((WARNINGS + 1))
    else
        echo -e "  ${C_GREEN}✔ RESPUESTA EWS:${C_RESET} Comunicación de lectura bidireccional activa."
        echo "    ${TOOL_STATUS}"
        PASSED=$((PASSED + 1))
    fi
else
    echo -e "  ${C_RED}✖ ERROR:${C_RESET} Herramienta ${TOOL} no encontrada o sin permisos de ejecución."
    ERRORS=$((ERRORS + 1))
fi

# ------------------------------------------------------------------------------
# 3. Niveles de Tinta y Diagnóstico de Cabezales
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_BOLD}[3/5] Consultando niveles de tinta y cabezales...${C_RESET}"
if [ -x "$TOOL" ]; then
    SUPPLIES_STATUS=$("$TOOL" supplies 2>&1 || true)
    if echo "$SUPPLIES_STATUS" | grep -q "No se pudo abrir"; then
        echo -e "  ${C_YELLOW}⚠ LECTURA DE TINTA NO DISPONIBLE${C_RESET} (Hardware en reposo o desconectado)."
    else
        echo -e "  ${C_GREEN}✔ CONSUMIBLES LEÍDOS:${C_RESET}"
        echo "    ${SUPPLIES_STATUS}"
        PASSED=$((PASSED + 1))
    fi
fi

# ------------------------------------------------------------------------------
# 4. Estado de la Cola de Impresión CUPS
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_BOLD}[4/5] Verificando subsistema de impresión CUPS...${C_RESET}"
if lpstat -p "HP_Smart_Tank_500" >/dev/null 2>&1; then
    CUPS_STATUS=$(lpstat -p "HP_Smart_Tank_500" 2>&1)
    DEVICE_URI=$(lpstat -v "HP_Smart_Tank_500" 2>&1 | awk '{print $NF}')
    echo -e "  ${C_GREEN}✔ COLA CUPS CONFIGURADA:${C_RESET} ${CUPS_STATUS}"
    echo -e "    URI de Destino: ${C_CYAN}${DEVICE_URI}${C_RESET}"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${C_YELLOW}⚠ COLA CUPS AUSENTE:${C_RESET} La cola "HP_Smart_Tank_500" no está registrada en macOS."
    echo -e "    ${C_CYAN}Sugerencia:${C_RESET} Ejecute ./install_native.sh o instale el .pkg para registrar la cola."
    WARNINGS=$((WARNINGS + 1))
fi

# ------------------------------------------------------------------------------
# 5. Aplicación GUI TankControl
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_BOLD}[5/5] Verificando utilidad gráfica TankControl...${C_RESET}"
APP_PID=$(pgrep -f "TankControl" | head -n1 || true)
if [ -n "$APP_PID" ]; then
    echo -e "  ${C_GREEN}✔ APLICACIÓN ACTIVA:${C_RESET} TankControl ejecutándose (PID: ${APP_PID})."
    PASSED=$((PASSED + 1))
else
    echo -e "  ${C_YELLOW}ℹ APLICACIÓN NO INICIADA:${C_RESET} TankControl no está abierta actualmente."
    echo -e "    Para abrirla: open -a "${BIN_DIR}/TankControl.app""
fi

# ------------------------------------------------------------------------------
# Resumen de Diagnóstico
# ------------------------------------------------------------------------------
echo ""
echo -e "${C_BOLD}======================================================================${C_RESET}"
echo -e "${C_BOLD}  RESUMEN DEL DIAGNÓSTICO${C_RESET}"
echo -e "${C_BOLD}======================================================================${C_RESET}"
echo -e "Pruebas superadas: ${C_GREEN}${PASSED}${C_RESET} | Advertencias: ${C_YELLOW}${WARNINGS}${C_RESET} | Errores: ${C_RED}${ERRORS}${C_RESET}"

if [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${C_GREEN}${C_BOLD}✔ ESTADO: EXCELENTE. Hardware conectado y 100% operativo.${C_RESET}"
    exit 0
elif [ "$ERRORS" -eq 0 ] && [ "$WARNINGS" -gt 0 ]; then
    echo -e "${C_YELLOW}${C_BOLD}ℹ ESTADO: ESPERANDO CONEXIÓN USB FÍSICA.${C_RESET}"
    echo -e "El software del controlador y la app están listos. En cuanto conectes el cable,"
    echo -e "vuelve a ejecutar este script para validar la comunicación en caliente."
    exit 0
else
    echo -e "${C_RED}${C_BOLD}✖ ESTADO: REQUIERE REVISIÓN.${C_RESET}"
    exit 1
fi
