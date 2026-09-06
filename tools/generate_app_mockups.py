#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tools/generate_app_mockups.py
Generador de mockups de alta fidelidad para la aplicación TankControl en macOS Apple Silicon.
Invoca el renderizador nativo Cocoa/CoreGraphics tools/generate_mockups.swift.
"""

import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.abspath(os.path.join(SCRIPT_DIR, ".."))
SWIFT_RENDERER = os.path.join(SCRIPT_DIR, "generate_mockups.swift")
OUTPUT_DIR = os.path.join(ROOT_DIR, "Brand/screenshots")


def main():
    print("[*] Iniciando generación de mockups nativos de TankControl...")
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    cmd = ["swift", SWIFT_RENDERER, OUTPUT_DIR]
    res = subprocess.run(cmd, capture_output=True, text=True)

    if res.returncode != 0:
        print(f"[-] Error al compilar/ejecutar generador de mockups:\n{res.stderr}", file=sys.stderr)
        sys.exit(res.returncode)

    print(res.stdout.strip())
    print("[+] ¡Todos los mockups visuales fueron generados exitosamente en Brand/screenshots/!")


if __name__ == "__main__":
    main()
