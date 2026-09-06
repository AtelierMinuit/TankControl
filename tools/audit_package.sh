#!/usr/bin/env bash
set -Eeuo pipefail

if [ "$#" -ne 1 ] || [ ! -f "$1" ]; then
    echo "Uso: $0 <paquete.pkg>" >&2
    exit 2
fi

PKG=$1
BASE=$(mktemp -d "${TMPDIR:-/tmp}/hp-package-audit.XXXXXX")
EXPANDED="${BASE}.pkg"
trap 'rm -rf -- "$BASE" "$EXPANDED"' EXIT

pkgutil --expand-full "$PKG" "$EXPANDED"
APP=$(find "$EXPANDED" -type d -name 'HP Smart Tank Utility.app' -print -quit)
[ -n "$APP" ] || { echo "ERROR: app ausente" >&2; exit 1; }
codesign --verify --deep --strict "$APP"

if rg -a -q -e '/Users/jorge' -e '/opt/homebrew' -e 'research/' \
    -e 'scratch/' -e 'Downloads/' -e '_ipp._tcp' -e '0\.0\.0\.0' "$EXPANDED"; then
    echo "ERROR: referencia prohibida en payload" >&2
    exit 1
fi

printf 'package=%s\n' "$PKG"
printf 'sha256=%s\n' "$(shasum -a 256 "$PKG" | awk '{print $1}')"
MATERIALIZED_DOTS=$(find "$EXPANDED" -name '._*' 2>/dev/null || true)
if [ -n "$MATERIALIZED_DOTS" ]; then
    echo "ERROR: archivos AppleDouble ._ materializados en el filesystem expandido" >&2
    printf '%s\n' "$MATERIALIZED_DOTS" >&2
    exit 1
fi
PAYLOAD_FILES=$(pkgutil --payload-files "$PKG")
REAL_PAYLOAD_FILES=$(printf '%s\n' "$PAYLOAD_FILES" | grep -v '(^|/)\._' || true)
printf 'payload_files=%s\n' "$(printf '%s\n' "$REAL_PAYLOAD_FILES" | wc -l | tr -d ' ')"
printf 'app_signature=PASS\ncontent_exclusions=PASS\ninstallation=NOT_PERFORMED\n'
