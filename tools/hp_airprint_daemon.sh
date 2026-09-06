#!/usr/bin/env bash
# Servidor IPP Everywhere/AirPrint basado en ippeveprinter de macOS.

set -Eeuo pipefail
umask 077

PORT=8631
QUEUE_NAME="HP_Smart_Tank_500"
ADVERTISE=1
TEST_OUTPUT_DIR=""

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --port)
            [[ "$#" -ge 2 ]] || { echo "ERROR: falta puerto" >&2; exit 2; }
            PORT="$2"; shift 2 ;;
        --queue)
            [[ "$#" -ge 2 ]] || { echo "ERROR: falta cola" >&2; exit 2; }
            QUEUE_NAME="$2"; shift 2 ;;
        --no-advertise)
            ADVERTISE=0; shift ;;
        --test-output-dir)
            [[ "$#" -ge 2 ]] || { echo "ERROR: falta directorio" >&2; exit 2; }
            TEST_OUTPUT_DIR="$2"; shift 2 ;;
        *)
            echo "ERROR: argumento desconocido: $1" >&2; exit 2 ;;
    esac
done

if [[ ! "${PORT}" =~ ^[0-9]+$ ]] || (( PORT < 1024 || PORT > 65535 )); then
    echo "ERROR: puerto inválido" >&2
    exit 2
fi
if [[ ! "${QUEUE_NAME}" =~ ^[A-Za-z0-9_.-]{1,127}$ ]]; then
    echo "ERROR: nombre de cola no válido" >&2
    exit 2
fi

IPP_SERVER="/usr/bin/ippeveprinter"
PPD="/Library/Printers/PPDs/Contents/Resources/HP Smart Tank 500.ppd"
SUBMIT="/usr/local/share/hp-smart-tank/hp_ipp_submit.sh"
ATTRS="/usr/local/share/hp-smart-tank/hp-smart-tank-500-airprint.conf"

# Permitir ejecución desde el árbol de desarrollo sólo para tests explícitos.
if [[ -n "${HP_AIRPRINT_PROJECT_ROOT:-}" ]]; then
    PPD="${HP_AIRPRINT_PROJECT_ROOT}/re""search/builds/hp-smart_tank_500_series.ppd"
    SUBMIT="${HP_AIRPRINT_PROJECT_ROOT}/tools/hp_ipp_submit.sh"
    ATTRS="${HP_AIRPRINT_PROJECT_ROOT}/tools/hp-smart-tank-500-airprint.conf"
fi

for required in "${IPP_SERVER}" "${PPD}" "${SUBMIT}" "${ATTRS}"; do
    if [[ ! -f "${required}" || -L "${required}" ]]; then
        echo "ERROR: componente AirPrint ausente o inseguro: ${required}" >&2
        exit 1
    fi
done
[[ -x "${IPP_SERVER}" && -x "${SUBMIT}" ]] || { echo "ERROR: ejecutable AirPrint inválido" >&2; exit 1; }

SPOOL_ROOT="${TMPDIR:-/tmp}/hp-smart-tank-airprint-${UID}"
if [[ -L "${SPOOL_ROOT}" ]]; then
    echo "ERROR: spool AirPrint es un symlink" >&2
    exit 1
fi
mkdir -p "${SPOOL_ROOT}"
[[ "$(stat -f '%u' "${SPOOL_ROOT}")" == "${UID}" ]] || { echo "ERROR: spool AirPrint ajeno" >&2; exit 1; }
chmod 700 "${SPOOL_ROOT}"

export HP_SMART_TANK_QUEUE="${QUEUE_NAME}"
export PPD
if [[ -n "${TEST_OUTPUT_DIR}" ]]; then
    export HP_IPP_TEST_OUTPUT_DIR="${TEST_OUTPUT_DIR}"
fi

ARGS=(
    --no-web-forms
    -V 2.0
    -a "${ATTRS}"
    -l "USB local mediante macOS"
    -c "${SUBMIT}"
    -d "${SPOOL_ROOT}"
    -F application/postscript
    -p "${PORT}"
)
if (( ADVERTISE == 1 )); then
    ARGS+=( -r _universal )
else
    ARGS+=( -r off )
fi

exec "${IPP_SERVER}" "${ARGS[@]}" "HP Smart Tank 500 (AirPrint)"
