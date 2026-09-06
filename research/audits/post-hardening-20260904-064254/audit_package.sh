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
PAYLOAD_FILES=$(pkgutil --payload-files "$PKG")
if printf '%s\n' "$PAYLOAD_FILES" | rg -q '(^|/)\._'; then
    echo "ERROR: el BOM/payload contiene entradas AppleDouble ._" >&2
    printf '%s\n' "$PAYLOAD_FILES" | rg '(^|/)\._' >&2
    exit 1
fi
printf 'payload_files=%s\n' "$(printf '%s\n' "$PAYLOAD_FILES" | wc -l | tr -d ' ')"
printf 'app_signature=PASS\ncontent_exclusions=PASS\ninstallation=NOT_PERFORMED\n'
