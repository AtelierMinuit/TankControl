#!/usr/bin/env bash
# Comando de trabajo para ippeveprinter: normaliza formatos driverless y
# entrega el documento a la cola CUPS local de la HP Smart Tank 500.

set -Eeuo pipefail
umask 077

QUEUE_NAME="${HP_SMART_TANK_QUEUE:-HP_Smart_Tank_500}"
CONVERTER="/usr/libexec/cups/command/ippeveps"
LP_BIN="/usr/bin/lp"
MAX_JOB_BYTES=$((1024 * 1024 * 1024))

if [[ ! "${QUEUE_NAME}" =~ ^[A-Za-z0-9_.-]{1,127}$ ]]; then
    echo "ERROR: nombre de cola no válido" >&2
    exit 2
fi

if [[ "$#" -ne 1 ]]; then
    echo "ERROR: uso: hp_ipp_submit.sh archivo" >&2
    exit 2
fi

INPUT_FILE="$1"
if [[ ! -f "${INPUT_FILE}" || -L "${INPUT_FILE}" ]]; then
    echo "ERROR: el trabajo no es un archivo regular seguro" >&2
    exit 2
fi

JOB_BYTES="$(stat -f '%z' "${INPUT_FILE}")"
if [[ ! "${JOB_BYTES}" =~ ^[0-9]+$ ]] || (( JOB_BYTES < 1 || JOB_BYTES > MAX_JOB_BYTES )); then
    echo "ERROR: tamaño de trabajo fuera de rango" >&2
    exit 2
fi

JOB_CONTENT_TYPE="${CONTENT_TYPE:-}"
case "${JOB_CONTENT_TYPE}" in
    application/pdf|application/postscript|image/jpeg|image/pwg-raster|image/urf)
        ;;
    *)
        echo "ERROR: formato no soportado: ${JOB_CONTENT_TYPE:-desconocido}" >&2
        exit 2
        ;;
esac
export CONTENT_TYPE="${JOB_CONTENT_TYPE}"

if [[ ! -x "${CONVERTER}" ]]; then
    echo "ERROR: conversor IPP Everywhere de macOS no disponible" >&2
    exit 1
fi

JOB_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hp-airprint-job.XXXXXX")"
OUTPUT_PS="${JOB_DIR}/document.ps"
cleanup() {
    rm -f -- "${OUTPUT_PS}"
    rmdir -- "${JOB_DIR}" 2>/dev/null || true
}
trap cleanup EXIT HUP INT TERM

"${CONVERTER}" "${INPUT_FILE}" > "${OUTPUT_PS}"
if [[ ! -s "${OUTPUT_PS}" || -L "${OUTPUT_PS}" ]]; then
    echo "ERROR: conversión IPP sin salida válida" >&2
    exit 1
fi

# Modo de aceptación offline. El directorio debe crearlo el test/operador y no
# se permite que sea un enlace simbólico.
if [[ -n "${HP_IPP_TEST_OUTPUT_DIR:-}" ]]; then
    if [[ ! -d "${HP_IPP_TEST_OUTPUT_DIR}" || -L "${HP_IPP_TEST_OUTPUT_DIR}" ]]; then
        echo "ERROR: directorio de prueba no válido" >&2
        exit 2
    fi
    TEST_COPY="${HP_IPP_TEST_OUTPUT_DIR}/job-${IPP_JOB_ID:-0}.ps"
    if [[ -e "${TEST_COPY}" || -L "${TEST_COPY}" ]]; then
        echo "ERROR: salida de prueba ya existe" >&2
        exit 2
    fi
    /usr/bin/install -m 0600 "${OUTPUT_PS}" "${TEST_COPY}"
    echo "INFO: trabajo convertido en modo offline (${JOB_BYTES} bytes)" >&2
    exit 0
fi

if ! /usr/bin/lpstat -p "${QUEUE_NAME}" >/dev/null 2>&1; then
    echo "STATE: +offline-report" >&2
    echo "ERROR: cola CUPS ${QUEUE_NAME} no disponible" >&2
    exit 1
fi

JOB_TITLE="${IPP_JOB_NAME:-Trabajo AirPrint}"
JOB_TITLE="$(printf '%s' "${JOB_TITLE}" | tr '\r\n\t' '   ' | cut -c1-128)"
LP_RESULT="$("${LP_BIN}" -d "${QUEUE_NAME}" -t "${JOB_TITLE}" "${OUTPUT_PS}")"
echo "STATE: -offline-report" >&2
echo "INFO: ${LP_RESULT}" >&2
