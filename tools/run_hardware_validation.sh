#!/usr/bin/env bash
# shellcheck disable=SC2329
# Script y Arnés de Validación de Hardware para HP Smart Tank 500 (macOS Apple Silicon).
#
# Controla la ejecución rigurosa de pruebas diagnósticas, telemetría, impresión y escaneo.
# Por defecto opera en modo --dry-run (100% offline y seguro).
#
# Convención de Códigos de Salida:
#   0 = PASS / DRY-RUN / MOCK (todas las verificaciones superadas exitosamente)
#   1 = FAIL (uno o más pasos fallaron o arrojaron error)
#   2 = BLOCKED / PARTIAL (dispositivo ausente, o acción cancelada por el operador)

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Constantes de Hardware
TARGET_VID="03f0"
TARGET_PID="2b54"
TARGET_MODEL="HP Smart Tank 500"

# Opciones de línea de comandos por omisión
MODE="dry-run"
TIMEOUT_SEC=30
SESSION_BASE_DIR=""
ASSUME_YES=0
IS_LIVE=0

usage() {
    cat << 'EOF'
Uso: tools/run_hardware_validation.sh [MODO] [OPCIONES]

Modos de Ejecución (mutuamente excluyentes, por omisión --dry-run):
  --dry-run      Operación 100% offline. No envía tramas USB. Verifica entorno,
                 binarios, PPD y genera el stream de prueba PCL3GUI.
  --probe        Sólo lectura de descriptores USB y colas CUPS. No envía requests LEDM.
  --telemetry    Consultas de estado y consumibles LEDM no destructivas.
  --print        Prueba de impresión física controlada (hardware-smoke-test.pdf).
                 Requiere confirmación explícita previa a la alimentación de papel.
  --scan         Prueba de escaneo óptico CIS controlado (150 DPI Color región reducida).
  --fault-tests  Batería de pruebas negativas y manejo de errores (aislado, DEVELOPER_ONLY).
  --mock         Ejecución completa simulada contra el gemelo digital (virtual_smart_tank).

Opciones Adicionales:
  --live              Ejecución contra hardware físico real (requiere impresora conectada).
  --session-dir DIR   Directorio de evidencia personalizado (por omisión: research/hardware-validation/YYYYMMDD-HHMMSS).
  --timeout SEC       Tiempo máximo de espera por paso en segundos (por omisión: 30).
  --assume-yes        Acepta automáticamente confirmaciones de pre-flight (sólo tests desatendidos).
  -h, --help          Muestra este mensaje de ayuda y termina.
EOF
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --dry-run|--probe|--telemetry|--print|--scan|--fault-tests|--mock)
            MODE="${1#--}"
            shift ;;
        --live)
            IS_LIVE=1
            shift ;;
        --session-dir)
            [[ "$#" -ge 2 ]] || { echo "ERROR: falta directorio para --session-dir" >&2; exit 2; }
            SESSION_BASE_DIR="$2"
            shift 2 ;;
        --timeout)
            [[ "$#" -ge 2 ]] || { echo "ERROR: falta valor para --timeout" >&2; exit 2; }
            TIMEOUT_SEC="$2"
            shift 2 ;;
        --assume-yes)
            ASSUME_YES=1
            shift ;;
        -h|--help)
            usage
            exit 0 ;;
        *)
            echo "ERROR: Opción desconocida: $1" >&2
            usage >&2
            exit 2 ;;
    esac
done

# Validación de Seguridad: --fault-tests es DEVELOPER_ONLY y está prohibido en hardware real
if [[ "${MODE}" == "fault-tests" && "${IS_LIVE}" -eq 1 ]]; then
    echo "ERROR: --fault-tests es de clase DEVELOPER_ONLY y sólo puede ejecutarse OFFLINE o en --mock. Prohibido contra hardware real (--live)." >&2
    exit 2
fi

# Validar argumento timeout numérico
if [[ ! "${TIMEOUT_SEC}" =~ ^[0-9]+$ ]] || (( TIMEOUT_SEC < 1 || TIMEOUT_SEC > 600 )); then
    echo "ERROR: Parámetro --timeout debe ser un número entero entre 1 y 600." >&2
    exit 2
fi

# Variables de Sesión y Evidencia
SESSION_ID="$(date +%Y%m%d-%H%M%S)"
if [[ -n "${SESSION_BASE_DIR}" ]]; then
    SESSION_DIR="${SESSION_BASE_DIR}"
else
    SESSION_DIR="${ROOT_DIR}/research/hardware-validation/${SESSION_ID}"
fi

mkdir -p "${SESSION_DIR}/logs"
mkdir -p "${SESSION_DIR}/telemetry"
mkdir -p "${SESSION_DIR}/print"
mkdir -p "${SESSION_DIR}/scan"

# Estructura de Estado Global
OVERALL_STATUS="PASS"
FINAL_EXIT_CODE=0
STEP_COUNT=0
FAIL_COUNT=0
BLOCKED_COUNT=0

# Listas para rastreo de procesos y temporales
CHILD_PIDS=()
TEMP_FILES=()

# Registro de Pasos: Cada elemento almacena "key|name|status|exit_code|duration|evidence"
STEP_RESULTS=()

cleanup() {
    local sig="${1:-EXIT}"
    if [[ "${sig}" != "EXIT" ]]; then
        log_warn "Capturada señal ${sig} - ejecutando limpieza controlada..."
    fi
    # Terminar subprocesos huérfanos registrados
    if (( ${#CHILD_PIDS[@]} > 0 )); then
        for pid in "${CHILD_PIDS[@]}"; do
            if kill -0 "${pid}" 2>/dev/null; then
                kill -TERM "${pid}" 2>/dev/null || true
            fi
        done
    fi
    # Limpiar temporales marcados
    if (( ${#TEMP_FILES[@]} > 0 )); then
        for tf in "${TEMP_FILES[@]}"; do
            if [[ -f "${tf}" ]]; then
                rm -f -- "${tf}" 2>/dev/null || true
            fi
        done
    fi

    # Generar reportes finales si aún no se generaron
    if [[ ! -f "${SESSION_DIR}/summary.json" ]]; then
        generate_summary_reports
    fi
}
trap 'cleanup INT' INT
trap 'cleanup TERM' TERM
trap 'cleanup EXIT' EXIT

# Helper de ejecución con timeout seguro para comandos externos
run_with_timeout() {
    local t_sec="$1"
    shift
    python3 -c "
import subprocess, sys
try:
    p = subprocess.run(sys.argv[2:], timeout=float(sys.argv[1]))
    sys.exit(p.returncode)
except subprocess.TimeoutExpired:
    sys.stderr.write(f'ERROR: Timeout de {sys.argv[1]}s expirado al ejecutar: {\" \".join(sys.argv[2:])}\n')
    sys.exit(124)
" "${t_sec}" "$@"
}

# Ejecutor estandarizado de pasos
execute_step() {
    local step_key="$1"
    local step_name="$2"
    shift 2

    STEP_COUNT=$((STEP_COUNT + 1))
    local log_file="${SESSION_DIR}/logs/${step_key}.log"
    echo -n "[Paso ${STEP_COUNT}] ${step_name}... "

    local start_ts
    start_ts="$(date +%s)"

    local step_rc=0
    set +e
    ( "$@" ) > "${log_file}" 2>&1 &
    local step_pid=$!
    CHILD_PIDS+=("${step_pid}")

    local elapsed=0
    while kill -0 "${step_pid}" 2>/dev/null; do
        sleep 0.5
        elapsed=$((elapsed + 1))
        if (( elapsed >= TIMEOUT_SEC * 2 )); then
            kill -TERM "${step_pid}" 2>/dev/null || true
            sleep 1
            kill -KILL "${step_pid}" 2>/dev/null || true
            step_rc=124
            break
        fi
    done
    if (( step_rc != 124 )); then
        wait "${step_pid}" 2>/dev/null
        step_rc=$?
    fi
    set -e

    local end_ts
    end_ts="$(date +%s)"
    local duration=$((end_ts - start_ts))
    if (( duration < 1 )); then duration=1; fi

    local step_status="PASS"
    if [[ "${MODE}" == "dry-run" ]]; then
        if (( step_rc == 0 )); then
            step_status="DRY-RUN"
        else
            step_status="FAIL"
        fi
    elif [[ "${MODE}" == "mock" ]]; then
        if (( step_rc == 0 )); then
            step_status="MOCK"
        else
            step_status="FAIL"
        fi
    else
        if (( step_rc == 0 )); then
            step_status="PASS"
        elif (( step_rc == 124 )); then
            step_status="TIMEOUT"
        elif (( step_rc == 2 )); then
            step_status="BLOCKED"
        else
            step_status="FAIL"
        fi
    fi

    # Imprimir resultado en consola
    case "${step_status}" in
        PASS)
            echo "PASS (${duration}s)" ;;
        DRY-RUN)
            echo "DRY-RUN OK (${duration}s)" ;;
        MOCK)
            echo "MOCK OK (${duration}s)" ;;
        BLOCKED)
            echo "BLOCKED (rc=${step_rc}, ${duration}s)"
            BLOCKED_COUNT=$((BLOCKED_COUNT + 1))
            if [[ "${OVERALL_STATUS}" != "FAIL" ]]; then
                OVERALL_STATUS="BLOCKED"
                FINAL_EXIT_CODE=2
            fi
            ;;
        TIMEOUT)
            echo "FAIL: TIMEOUT (${TIMEOUT_SEC}s)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            OVERALL_STATUS="FAIL"
            FINAL_EXIT_CODE=1
            ;;
        FAIL)
            echo "FAIL (rc=${step_rc}, ${duration}s)"
            FAIL_COUNT=$((FAIL_COUNT + 1))
            OVERALL_STATUS="FAIL"
            FINAL_EXIT_CODE=1
            ;;
    esac

    STEP_RESULTS+=("${step_key}|${step_name}|${step_status}|${step_rc}|${duration}|logs/${step_key}.log")
    return 0
}

# ==============================================================================
# DEVICE SAFETY GATE CENTRALIZADO
# ==============================================================================
# Clasificación de Operaciones:
#   READ_ONLY:           --probe, --telemetry
#   NORMAL_IO:           --print, --scan
#   MAINTENANCE:         clean-heads, align
#   DANGEROUS:           deep-clean, prime-tubes, reset-waste-ink
#   DEVELOPER_ONLY:      --fault-tests, inject-raw
#   OFFLINE_SIMULATION:  --dry-run, --mock

get_operation_class() {
    case "${MODE}" in
        probe|telemetry) echo "READ_ONLY" ;;
        print|scan)      echo "NORMAL_IO" ;;
        fault-tests)     echo "DEVELOPER_ONLY" ;;
        dry-run|mock)    echo "OFFLINE_SIMULATION" ;;
        *)               echo "UNKNOWN" ;;
    esac
}

require_operation_allowed() {
    local op_class
    op_class="$(get_operation_class)"
    if [[ "${op_class}" == "DEVELOPER_ONLY" && "${IS_LIVE}" -eq 1 ]]; then
        echo "Device Safety Gate: La operación ${MODE} (clase ${op_class}) está estrictamente prohibida contra hardware real." >&2
        return 2
    fi
    return 0
}

require_vid_pid() {
    local vid="${1:-${TARGET_VID}}"
    local pid="${2:-${TARGET_PID}}"
    if [[ "${vid}" != "${TARGET_VID}" || "${pid}" != "${TARGET_PID}" ]]; then
        echo "Device Safety Gate: Dispositivo 0x${vid}:0x${pid} no coincide con el objetivo autorizado (0x${TARGET_VID}:0x${TARGET_PID})." >&2
        return 2
    fi
    return 0
}

check_usb_device_connected() {
    local dec_pid
    dec_pid="$((16#${TARGET_PID}))"
    if system_profiler SPUSBDataType 2>/dev/null | grep -i -q "0x${TARGET_PID}"; then
        return 0
    fi
    if ioreg -p IOUSB -l 2>/dev/null | grep -q "\"idProduct\" = ${dec_pid}"; then
        return 0
    fi
    if ioreg -p IOUSB -l 2>/dev/null | grep -i -q "0x${TARGET_PID}"; then
        return 0
    fi
    if /usr/libexec/cups/backend/usb 2>/dev/null | grep -i -q "Smart%20Tank%20500"; then
        return 0
    fi
    return 1
}

require_real_device() {
    local op_class
    op_class="$(get_operation_class)"
    if [[ "${op_class}" == "OFFLINE_SIMULATION" || "${op_class}" == "DEVELOPER_ONLY" ]]; then
        return 0
    fi
    require_vid_pid "${TARGET_VID}" "${TARGET_PID}" || return 2
    if ! check_usb_device_connected; then
        echo "Device Safety Gate: Hardware físico HP Smart Tank 500 (0x${TARGET_VID}:0x${TARGET_PID}) no detectado en bus USB. Operación de clase ${op_class} bloqueada." >&2
        return 2 # BLOCKED
    fi
    return 0
}

# 1. Generación de Manifiesto Inicial
generate_manifest() {
    local manifest="${SESSION_DIR}/manifest.txt"
    {
        echo "======================================================================"
        echo "  HP SMART TANK 500 — SESION DE VALIDACION DE HARDWARE"
        echo "======================================================================"
        echo "timestamp:            $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "session_id:           ${SESSION_ID}"
        echo "mode:                 ${MODE}"
        echo "host_os:              $(sw_vers -productName 2>/dev/null || uname -s) $(sw_vers -productVersion 2>/dev/null || true)"
        echo "host_build:           $(sw_vers -buildVersion 2>/dev/null || true)"
        echo "darwin_kernel:        $(uname -r)"
        echo "architecture:         $(uname -m)"
        echo "project_root:         ${ROOT_DIR}"
        echo "project_version:      0.1.0-alpha"
        echo "target_vid:           0x${TARGET_VID}"
        echo "target_pid:           0x${TARGET_PID}"
        echo "target_model:         ${TARGET_MODEL}"

        # Git status o snapshot
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
            echo "git_commit:           $(git rev-parse HEAD)"
            echo "git_dirty:            $(git status --porcelain | wc -l | tr -d ' ') modified files"
        else
            echo "git_status:           not a git repo (snapshot baseline)"
        fi

        echo "--- Hashes de Binarios Auditados (SHA-256) ---"
        local bins=(
            "${ROOT_DIR}/research/builds/antigravity-offline-audit/rastertopcl3gui"
            "${ROOT_DIR}/research/builds/antigravity-offline-audit/smarttank"
            "${ROOT_DIR}/research/builds/antigravity-offline-audit/hp_scan"
            "${ROOT_DIR}/research/builds/antigravity-offline-audit/hp-smart-tank-tool"
        )
        for b in "${bins[@]}"; do
            if [[ -f "${b}" ]]; then
                echo "$(shasum -a 256 "${b}" | awk '{print $1}')  $(basename "${b}")"
            else
                echo "AUSENTE: $(basename "${b}")"
            fi
        done

        echo "--- Hash de Archivo PPD ---"
        local ppd="${ROOT_DIR}/research/builds/hp-smart_tank_500_series_mac.ppd"
        if [[ -f "${ppd}" ]]; then
            echo "$(shasum -a 256 "${ppd}" | awk '{print $1}')  $(basename "${ppd}")"
        fi
        echo "======================================================================"
    } > "${manifest}"
}

finalize_manifest() {
    local manifest="${SESSION_DIR}/manifest.txt"
    {
        echo ""
        echo "--- Hashes de Artefactos de Evidencia de Sesión (SHA-256) ---"
        find "${SESSION_DIR}/print" "${SESSION_DIR}/scan" "${SESSION_DIR}/telemetry" "${SESSION_DIR}/logs" -type f 2>/dev/null | sort | while read -r f; do
            if [[ -f "${f}" ]]; then
                echo "$(shasum -a 256 "${f}" | awk '{print $1}')  $(basename "${f}")"
            fi
        done
        echo "======================================================================"
    } >> "${manifest}"
}

# 2. Generación de Reportes Finales
generate_summary_reports() {
    finalize_manifest

    local sum_json="${SESSION_DIR}/summary.json"
    local sum_md="${SESSION_DIR}/summary.md"

    # JSON estructurado conforme a docs/hardware-validation-summary.schema.json
    {
        echo "{"
        echo "  \"schema_version\": \"1.0.0\","
        echo "  \"session_id\": \"${SESSION_ID}\","
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
        echo "  \"mode\": \"${MODE}\","
        echo "  \"host\": {"
        echo "    \"os\": \"macOS\","
        echo "    \"arch\": \"$(uname -m)\","
        echo "    \"kernel\": \"$(uname -r)\""
        echo "  },"
        echo "  \"device\": {"
        echo "    \"vid\": \"0x${TARGET_VID}\","
        echo "    \"pid\": \"0x${TARGET_PID}\","
        echo "    \"model\": \"${TARGET_MODEL}\""
        echo "  },"
        echo "  \"steps\": ["
        local first=1
        if (( ${#STEP_RESULTS[@]} > 0 )); then
            for s in "${STEP_RESULTS[@]}"; do
                IFS='|' read -r skey sname sstat src sdur sevid <<< "${s}"
                if (( first == 1 )); then first=0; else echo ","; fi
                cat << STEP_EOF
    {
      "key": "${skey}",
      "name": "${sname}",
      "status": "${sstat}",
      "exit_code": ${src},
      "duration_ms": $((sdur * 1000)),
      "evidence_files": [
        "${sevid}"
      ]
    }
STEP_EOF
            done
        fi
        echo "  ],"
        echo "  \"result\": {"
        echo "    \"overall_status\": \"${OVERALL_STATUS}\","
        echo "    \"final_exit_code\": ${FINAL_EXIT_CODE},"
        echo "    \"step_count\": ${STEP_COUNT},"
        echo "    \"fail_count\": ${FAIL_COUNT},"
        echo "    \"blocked_count\": ${BLOCKED_COUNT}"
        echo "  },"
        echo "  \"evidence\": {"
        echo "    \"manifest_file\": \"manifest.txt\","
        echo "    \"session_dir\": \"${SESSION_DIR}\""
        echo "  }"
        echo "}"
    } > "${sum_json}"

    # Validación automática de summary.json contra el esquema formal
    local schema_path="${ROOT_DIR}/docs/hardware-validation-summary.schema.json"
    if [[ -f "${schema_path}" ]]; then
        python3 -c "
import json, sys
with open('${sum_json}', 'r') as f:
    d = json.load(f)
req = ['schema_version', 'session_id', 'timestamp', 'mode', 'host', 'device', 'steps', 'result', 'evidence']
for k in req:
    if k not in d:
        sys.stderr.write(f'Validación de Esquema Fallida: falta {k}\n')
        sys.exit(1)
for s in d['steps']:
    for sk in ['key', 'name', 'status', 'exit_code', 'duration_ms', 'evidence_files']:
        if sk not in s:
            sys.stderr.write(f'Validación de Esquema Fallida: falta {sk} en paso {s}\n')
            sys.exit(1)
for rk in ['overall_status', 'final_exit_code', 'step_count', 'fail_count', 'blocked_count']:
    if rk not in d['result']:
        sys.stderr.write(f'Validación de Esquema Fallida: falta {rk} en resultado\n')
        sys.exit(1)
" 2>/dev/null || log_warn "Advertencia: summary.json no pasó la comprobación estricta de esquema"
    fi

    # Markdown legible
    local mode_display
    mode_display="$(printf '%s' "${MODE}" | tr '[:lower:]' '[:upper:]')"
    {
        echo "# Resumen de Sesión de Validación de Hardware — HP Smart Tank 500"
        echo ""
        echo "**ID de Sesión:** \`${SESSION_ID}\`  "
        echo "**Fecha:** $(date)  "
        echo "**Modo:** \`${mode_display}\`  "
        echo "**Estado Global:** **${OVERALL_STATUS}** (Código de salida: \`${FINAL_EXIT_CODE}\`)  "
        echo ""
        echo "## Resultados por Paso"
        echo ""
        echo "| # | Clave | Paso Evaluado | Estado | Código Exit | Duración | Registro de Evidencia |"
        echo "|---|---|---|---|---|---|---|"
        local s_idx=1
        if (( ${#STEP_RESULTS[@]} > 0 )); then
            for s in "${STEP_RESULTS[@]}"; do
                IFS='|' read -r skey sname sstat src sdur sevid <<< "${s}"
                echo "| ${s_idx} | \`${skey}\` | ${sname} | **${sstat}** | \`${src}\` | ${sdur}s | [\`${sevid}\`](${sevid}) |"
                s_idx=$((s_idx + 1))
            done
        fi
        echo ""
        echo "## Convención de Estados y Códigos de Retorno"
        echo "- **PASS (0):** El paso se completó y verificó satisfactoriamente sobre hardware o simulación."
        echo "- **DRY-RUN (0):** Simulación pasiva offline; no se transmitieron bytes al bus USB físico."
        echo "- **MOCK (0):** Ejecución exitosa validada contra el gemelo digital local."
        echo "- **BLOCKED (2):** Dispositivo ausente o acción interactiva cancelada por el operador."
        echo "- **FAIL (1):** Error en compilación, checksum, ejecución o timeout expirado."
    } > "${sum_md}"
}

# --- ACCIONES INDIVIDUALES DE PASO ---

action_environment() {
    {
        echo "=== ENTORNO DEL SISTEMA HOST ==="
        uname -a
        sw_vers 2>/dev/null || true
        clang --version | head -n 2
        swiftc --version 2>/dev/null | head -n 1 || echo "swiftc no disponible"
        python3 --version
        cups-config --version 2>/dev/null || echo "cups-config ausente"
        pkg-config --modversion libusb-1.0 2>/dev/null || echo "libusb no detectado via pkg-config"
    } > "${SESSION_DIR}/environment.txt"
    cat "${SESSION_DIR}/environment.txt"
}

action_binaries() {
    local bins=(
        "${ROOT_DIR}/research/builds/antigravity-offline-audit/rastertopcl3gui"
        "${ROOT_DIR}/research/builds/antigravity-offline-audit/smarttank"
        "${ROOT_DIR}/research/builds/antigravity-offline-audit/hp_scan"
        "${ROOT_DIR}/research/builds/antigravity-offline-audit/hp-smart-tank-tool"
    )
    for b in "${bins[@]}"; do
        if [[ ! -x "${b}" ]]; then
            echo "ERROR: Binario ausente o sin permisos de ejecución: ${b}" >&2
            return 1
        fi
        echo "Binario verificado: $(basename "${b}") [$(shasum -a 256 "${b}" | awk '{print $1}')]"
    done

    local ppd="${ROOT_DIR}/research/builds/hp-smart_tank_500_series_mac.ppd"
    if [[ ! -f "${ppd}" ]]; then
        echo "ERROR: Archivo PPD ausente: ${ppd}" >&2
        return 1
    fi
    cupstestppd -W all "${ppd}"
}

action_usb_probe() {
    {
        echo "=== SONDEO USB (VID 0x${TARGET_VID}, PID 0x${TARGET_PID}) ==="
        echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        if [[ "${MODE}" == "dry-run" || "${MODE}" == "fault-tests" ]]; then
            echo "[OFFLINE] WOULD RUN: Sondeo pasivo de descriptores USB y tabla IOKit"
            echo "[OFFLINE] EXPECTED SOURCE: USB Registry / Interface 0 (ff/cc/00), Interface 1 (07/01/02), Interface 2 (ff/04/01)"
            echo "[OFFLINE] EXPECTED TYPE OF RESPONSE: USB Configuration & Endpoint Descriptors"
            echo "[OFFLINE] NO HARDWARE DATA COLLECTED (Modo estrictamente aislado)"
            return 0
        fi

        if [[ "${MODE}" == "mock" ]]; then
            echo "[MOCK] Consultando endpoints simulados de virtual_smart_tank..."
            echo "[MOCK] Emulando VID:03f0 PID:2b54 (Interface 0: ff/cc/00, Interface 1: 07/01/02, Interface 2: ff/04/01)"
            return 0
        fi

        # Modos Live: Guard centralizado de Hardware
        require_real_device || return $?

        echo "Dispositivo detectado. Extrayendo inventario de descriptores..."
        "${ROOT_DIR}/research/builds/antigravity-offline-audit/usb-descriptor-inventory"
    } > "${SESSION_DIR}/usb.txt"
    cat "${SESSION_DIR}/usb.txt"
}

action_cups_probe() {
    {
        echo "=== ESTADO DE SUBSISTEMA CUPS ==="
        lpstat -r 2>&1 || echo "Planificador CUPS no responde"
        lpstat -s 2>&1 || true

        echo "=== DESCUBRIMIENTO DE BACKEND SMARTECT ==="
        local backend="${ROOT_DIR}/research/builds/antigravity-offline-audit/smarttank"
        if [[ -x "${backend}" ]]; then
            # Invocar backend sin argumentos para probar registro CUPS
            "${backend}" 2>&1 || true
        else
            echo "ERROR: Backend smarttank no ejecutable" >&2
            return 1
        fi
    } > "${SESSION_DIR}/cups.txt"
    cat "${SESSION_DIR}/cups.txt"
}

action_telemetry() {
    local out_dir="${SESSION_DIR}/telemetry"
    if [[ "${MODE}" == "dry-run" ]]; then
        echo "[DRY-RUN] WOULD RUN: hp-smart-tank-tool status / supplies / odometer"
        echo "[DRY-RUN] EXPECTED SOURCE: USB Interface 2 (ff/04/01) -> GET /DevMgmt/ProductStatusDyn.xml, /DevMgmt/ConsumableConfigDyn.xml"
        echo "[DRY-RUN] EXPECTED TYPE OF RESPONSE: XML ProductStatusDyn y ConsumableConfigDyn"
        echo "[DRY-RUN] NO HARDWARE DATA COLLECTED"
        return 0
    fi

    if [[ "${MODE}" == "mock" ]]; then
        echo "[MOCK] Obteniendo telemetría simulada del gemelo digital..."
        python3 -c "
import json
print(json.dumps({'status': 'Ready', 'supplies': {'K': 95, 'C': 85, 'M': 90, 'Y': 80}, 'odometer': {'total_pages': 142}}, indent=2))
" > "${out_dir}/mock_telemetry.json"
        cat "${out_dir}/mock_telemetry.json"
        return 0
    fi

    require_real_device || return $?

    local tool="${ROOT_DIR}/research/builds/antigravity-offline-audit/hp-smart-tank-tool"
    echo "Consultando estado general (LEDM)..."
    "${tool}" status > "${out_dir}/status.txt"
    "${tool}" json-status > "${out_dir}/status.json" 2>/dev/null || true
    echo "Consultando niveles de consumibles (GT51/GT52)..."
    "${tool}" supplies > "${out_dir}/supplies.txt"
    "${tool}" json-supplies > "${out_dir}/supplies.json" 2>/dev/null || true
    echo "Consultando odómetro interno..."
    "${tool}" odometer > "${out_dir}/odometer.txt"
    "${tool}" json-odometer > "${out_dir}/odometer.json" 2>/dev/null || true
    cat "${out_dir}/supplies.txt"
}

action_print_pipeline() {
    local print_dir="${SESSION_DIR}/print"
    local pdf_file="${print_dir}/hardware-smoke-test.pdf"
    local raster_file="${print_dir}/smoke-test.raster"
    local pcl_file="${print_dir}/smoke-test.pcl"
    local manifest="${print_dir}/stream-manifest.txt"

    echo "1. Generando página de prueba estandarizada (hardware-smoke-test.pdf)..."
    python3 "${ROOT_DIR}/tools/generate_smoke_test_page.py" --output "${pdf_file}" --session-id "${SESSION_ID}"

    echo "2. Rasterizando PDF a CUPS Raster mediante /usr/sbin/cupsfilter..."
    local ppd="${ROOT_DIR}/research/builds/hp-smart_tank_500_series_mac.ppd"
    /usr/sbin/cupsfilter -p "${ppd}" -m application/vnd.cups-raster "${pdf_file}" > "${raster_file}" 2>/dev/null

    echo "3. Convirtiendo CUPS Raster a PCL3GUI Modo 10 con rastertopcl3gui..."
    local filter="${ROOT_DIR}/research/builds/antigravity-offline-audit/rastertopcl3gui"
    "${filter}" 1 "Operator" "Smoke Test" 1 "" "${raster_file}" > "${pcl_file}" 2>"${SESSION_DIR}/logs/filter_stderr.log"

    # Registrar integridad del stream antes del backend
    local pdf_size
    pdf_size="$(stat -f '%z' "${pdf_file}")"
    local raster_size
    raster_size="$(stat -f '%z' "${raster_file}")"
    local pcl_size
    pcl_size="$(stat -f '%z' "${pcl_file}")"
    local pcl_sha
    pcl_sha="$(shasum -a 256 "${pcl_file}" | awk '{print $1}')"

    {
        echo "=== MANIFIESTO DE STREAM DE IMPRESION ==="
        echo "input_pdf:       ${pdf_file} (${pdf_size} bytes)"
        echo "cups_raster:     ${raster_file} (${raster_size} bytes)"
        echo "pcl3gui_stream:  ${pcl_file} (${pcl_size} bytes)"
        echo "pcl3gui_sha256:  ${pcl_sha}"
        echo "resolution:      600 DPI Normal (PCL3GUI Modo 10)"
        echo "media_size:      A4 Plain Paper"
    } > "${manifest}"
    cat "${manifest}"

    if [[ "${MODE}" == "dry-run" ]]; then
        echo "[DRY-RUN] Stream PCL3GUI generado y verificado (${pcl_size} bytes). Envío físico omitido."
        return 0
    fi

    if [[ "${MODE}" == "mock" ]]; then
        echo "[MOCK] Verificando decodificación del stream con el emulador digital..."
        python3 "${ROOT_DIR}/tools/pcl3gui-decode.py" "${pcl_file}" > "${print_dir}/mock_decode.txt" 2>&1
        echo "[MOCK] Stream validado sintácticamente. Cero bytes enviados a USB físico."
        return 0
    fi

    # Modo --print físico: Pre-flight interactivo obligatorio
    echo ""
    echo "======================================================================"
    echo "  PRE-FLIGHT DE IMPRESION FISICA CONTROLADA"
    echo "  Dispositivo:        ${TARGET_MODEL} (0x${TARGET_VID}:0x${TARGET_PID})"
    echo "  Documento:          hardware-smoke-test.pdf"
    echo "  Medio Requerido:    1 hoja Papel Común (A4 / Bond 75g)"
    echo "  Resolución:         600 DPI Normal (PCL3GUI Modo 10)"
    echo "  Tamaño de Stream:   ${pcl_size} bytes"
    echo "======================================================================"

    if (( ASSUME_YES == 0 )); then
        local confirm=""
        read -r -p "Escriba 'CONFIRM' para alimentar papel e imprimir físicamente: " confirm
        if [[ "${confirm}" != "CONFIRM" && "${confirm}" != "confirm" ]]; then
            echo "Impresión física cancelada por el operador."
            return 2 # BLOCKED
        fi
    fi

    require_real_device || return $?

    echo "Transmitiendo stream al backend smarttank (Interfaz 1: 07/01/02)..."
    local backend="${ROOT_DIR}/research/builds/antigravity-offline-audit/smarttank"
    "${backend}" 1 "Operator" "Smoke Test" 1 "" "${pcl_file}"
}

action_scan_pipeline() {
    local scan_dir="${SESSION_DIR}/scan"
    local img_out="${scan_dir}/smoke-scan-150.jpg"

    if [[ "${MODE}" == "dry-run" ]]; then
        echo "[DRY-RUN] WOULD RUN: hp_scan --resolution 150 --mode Color --output ${img_out}"
        echo "[DRY-RUN] EXPECTED SOURCE: USB Interface 0 (ff/cc/00) -> POST /Scan/Jobs -> GET /Scan/Jobs/{id}/NextDocument"
        echo "[DRY-RUN] EXPECTED TYPE OF RESPONSE: Flujo binario JPEG delimitado por SOI (FF D8) y EOI (FF D9)"
        echo "[DRY-RUN] NO HARDWARE DATA COLLECTED"
        return 0
    fi

    if [[ "${MODE}" == "mock" ]]; then
        echo "[MOCK] Ejecutando simulación de framing HTTP y extracción JPEG..."
        python3 -m unittest "${ROOT_DIR}/tests/test_ledm_http_framing.py" > "${scan_dir}/mock_scan.log" 2>&1
        echo "[MOCK] Verificación de framing eSCL superada con éxito."
        return 0
    fi

    # Modo --scan físico: Pre-flight interactivo obligatorio
    echo ""
    echo "======================================================================"
    echo "  PRE-FLIGHT DE ESCANEO OPTICO CONTROLADO"
    echo "  Dispositivo:        ${TARGET_MODEL} (0x${TARGET_VID}:0x${TARGET_PID})"
    echo "  Parámetros:         150 DPI, Color, Cristal Plano (Platen)"
    echo "  Ruta de Destino:    ${img_out}"
    echo "  Advertencia:        El carro CIS se desplazará físicamente."
    echo "======================================================================"

    if (( ASSUME_YES == 0 )); then
        local confirm=""
        read -r -p "Escriba 'CONFIRM' para mover el carro óptico y digitalizar: " confirm
        if [[ "${confirm}" != "CONFIRM" && "${confirm}" != "confirm" ]]; then
            echo "Escaneo físico cancelado por el operador."
            return 2 # BLOCKED
        fi
    fi

    require_real_device || return $?

    echo "Iniciando captura con hp_scan (Interfaz 0: ff/cc/00)..."
    local scanner="${ROOT_DIR}/research/builds/antigravity-offline-audit/hp_scan"
    "${scanner}" --resolution 150 --mode Color --output "${img_out}"

    if [[ ! -s "${img_out}" ]]; then
        echo "ERROR: hp_scan no produjo un archivo de imagen válido." >&2
        return 1
    fi

    echo "Inspeccionando archivo JPEG con Apple sips..."
    sips -g all "${img_out}"
}

action_fault_tests() {
    require_operation_allowed || return $?
    echo "=== PRUEBAS NEGATIVAS Y RESILIENCIA DE ARNES (OFFLINE) ==="
    echo "1. Verificando rechazo de archivos corruptos en rastertopcl3gui..."
    local filter="${ROOT_DIR}/research/builds/antigravity-offline-audit/rastertopcl3gui"
    local corrupted_file
    corrupted_file="$(mktemp "${TMPDIR:-/tmp}/corrupt_raster.XXXXXX")"
    TEMP_FILES+=("${corrupted_file}")
    echo "GARBAGE_NOT_A_CUPS_RASTER_STREAM" > "${corrupted_file}"

    local corrupt_rc=0
    set +e
    "${filter}" 1 "Test" "Corrupt" 1 "" "${corrupted_file}" >/dev/null 2>&1
    corrupt_rc=$?
    set -e
    if (( corrupt_rc == 0 )); then
        echo "ERROR: rastertopcl3gui aceptó entrada corrupta sin código de error." >&2
        return 1
    fi
    echo "Rechazo de archivo corrupto verificado (rc=${corrupt_rc})."
}

# --- EJECUCIÓN DEL ARNES SEGÚN EL MODO ---

echo "======================================================================"
echo "  HP SMART TANK 500 — ARNES MAESTRO DE VALIDACION DE HARDWARE"
MODE_UPPER="$(printf '%s' "${MODE}" | tr '[:lower:]' '[:upper:]')"
echo "  Modo de Operación: ${MODE_UPPER}"
echo "  Directorio de Sesión: ${SESSION_DIR}"
echo "======================================================================"

generate_manifest

# Paso 1: Entorno del host
execute_step "01_environment" "Verificación de Entorno macOS y SDK" action_environment

# Paso 2: Binarios y PPD
execute_step "02_binaries" "Integridad de Binarios C y Ficha PPD" action_binaries

# Paso 3: Sondeo USB / Guard de Hardware
execute_step "03_usb_probe" "Sondeo de Bus USB y Descriptores (VID 03f0 PID 2b54)" action_usb_probe

# Paso 4: Colas y Backend CUPS
execute_step "04_cups_backend" "Verificación de CUPS Spooler y Backend smarttank" action_cups_probe

# Pasos condicionales según el modo solicitado:
if [[ "${MODE}" == "dry-run" || "${MODE}" == "mock" || "${MODE}" == "telemetry" ]]; then
    execute_step "05_telemetry" "Telemetría LEDM y Consulta de Consumibles" action_telemetry
fi

if [[ "${MODE}" == "dry-run" || "${MODE}" == "mock" || "${MODE}" == "print" ]]; then
    execute_step "06_print_pipeline" "Pipeline de Impresión PCL3GUI (hardware-smoke-test.pdf)" action_print_pipeline
fi

if [[ "${MODE}" == "dry-run" || "${MODE}" == "mock" || "${MODE}" == "scan" ]]; then
    execute_step "07_scan_pipeline" "Pipeline de Escaneo Óptico CIS (150 DPI Color)" action_scan_pipeline
fi

if [[ "${MODE}" == "fault-tests" ]]; then
    execute_step "08_fault_tests" "Pruebas Negativas y Resiliencia ante Entradas Inválidas" action_fault_tests
fi

# Generar artefactos de resumen
generate_summary_reports

echo ""
echo "======================================================================"
echo "  SESION FINALIZADA: ${OVERALL_STATUS}"
echo "  Código de Salida:   ${FINAL_EXIT_CODE}"
echo "  Resumen JSON:       ${SESSION_DIR}/summary.json"
echo "  Resumen Markdown:   ${SESSION_DIR}/summary.md"
echo "======================================================================"

exit "${FINAL_EXIT_CODE}"
