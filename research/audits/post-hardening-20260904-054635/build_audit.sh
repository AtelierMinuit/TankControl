#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAG="${HP_AUDIT_TAG:-$(date '+%Y%m%d-%H%M%S')}"
if [[ ! "${TAG}" =~ ^[0-9]{8}-[0-9]{6}$ ]]; then
    echo "ERROR: HP_AUDIT_TAG debe tener formato YYYYMMDD-HHMMSS" >&2
    exit 2
fi
OUT_DIR="${ROOT_DIR}/research/builds/audit-clean/${TAG}"
mkdir -p "${OUT_DIR}"

CLANG_FLAGS=(-O2 -Wall -Wextra -Wpedantic -Wconversion -Wshadow -Wformat=2 -Wundef)
USB_FLAGS=(-I/opt/homebrew/include/libusb-1.0 -I/opt/homebrew/include -L/opt/homebrew/lib)

build() {
    local name="$1" source="$2"; shift 2
    echo "[build-audit] ${name}"
    clang "${CLANG_FLAGS[@]}" "${USB_FLAGS[@]}" "${source}" "$@" -o "${OUT_DIR}/${name}"
    file "${OUT_DIR}/${name}" | tee "${OUT_DIR}/${name}.file"
    shasum -a 256 "${OUT_DIR}/${name}" | tee "${OUT_DIR}/${name}.sha256"
    otool -L "${OUT_DIR}/${name}" | tee "${OUT_DIR}/${name}.otool"
}

build rastertopcl3gui "${ROOT_DIR}/tools/rastertopcl3gui.c" -lcups
build smarttank "${ROOT_DIR}/tools/cups_backend_smarttank.c" -lusb-1.0 -lcups
build hp_scan "${ROOT_DIR}/tools/hp_scan.c" -lusb-1.0 -lcups
build hp-smart-tank-tool "${ROOT_DIR}/tools/hp-smart-tank-tool.c" -lusb-1.0 -lcups

echo "Build C auditada en: ${OUT_DIR}"
