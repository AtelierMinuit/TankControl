#!/usr/bin/env python3
"""
generate_app_icon.py
Script envoltorio en Python para compilar y ejecutar el generador de icono nativo CoreGraphics.
Produce:
- Brand/AppIcon/AppIcon_1024x1024.png
- Brand/AppIcon/AppIcon.appiconset/
- Brand/AppIcon/AppIcon.icns
"""

import os
from pathlib import Path
import subprocess
import sys

PROJECT_ROOT = Path(__file__).resolve().parents[1]
SWIFT_SOURCE = PROJECT_ROOT / "tools" / "generate_app_icon.swift"

def main():
    print("[*] Iniciando generación de icono oficial TankControl...")
    if not SWIFT_SOURCE.exists():
        print(f"[ERROR] Archivo fuente no encontrado: {SWIFT_SOURCE}", file=sys.stderr)
        sys.exit(1)

    cmd = ["swift", str(SWIFT_SOURCE)]
    proc = subprocess.run(cmd, cwd=str(PROJECT_ROOT))
    if proc.returncode != 0:
        print(f"[ERROR] Generación de icono falló con código {proc.returncode}", file=sys.stderr)
        sys.exit(proc.returncode)

    icns = PROJECT_ROOT / "Brand" / "AppIcon" / "AppIcon.icns"
    if icns.exists():
        size = icns.stat().st_size
        print(f"[+] Icono .icns listo y verificado ({size} bytes).")
    else:
        print("[WARN] AppIcon.icns no fue creado.", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
