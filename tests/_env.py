"""Utilidades de entorno para la suite de pruebas.

Permite saltar de forma limpia las pruebas que dependen de binarios nativos
compilados (rastertopcl3gui, smarttank, hp-smart-tank-tool) o de herramientas
exclusivas de macOS (sips, codesign, otool, cupstestppd, ippeveps), de modo
que la suite pueda ejecutarse en cualquier host sin falsos fallos.
"""
from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
BUILD_DIR = Path(
    os.environ.get(
        "HP_AUDIT_BUILD_DIR",
        str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904"),
    )
)


def _binary_runs(path: Path) -> bool:
    """True si el binario existe y es ejecutable en la plataforma actual."""
    if not (path.is_file() and os.access(path, os.X_OK)):
        return False
    try:
        subprocess.run([str(path)], capture_output=True, timeout=5)
    except subprocess.TimeoutExpired:
        return True
    except OSError:
        return False
    return True


NATIVE_FILTER = _binary_runs(BUILD_DIR / "rastertopcl3gui")
NATIVE_TOOL = _binary_runs(BUILD_DIR / "hp-smart-tank-tool")
NATIVE_BACKEND = _binary_runs(BUILD_DIR / "smarttank")

CUPSTESTPPD_AVAILABLE = shutil.which("cupstestppd") is not None
SIPS_AVAILABLE = shutil.which("sips") is not None
CODESIGN_AVAILABLE = shutil.which("codesign") is not None
OTOOL_AVAILABLE = shutil.which("otool") is not None
IPPEVEPS_AVAILABLE = Path("/usr/libexec/cups/command/ippeveps").is_file()
IPPEVEPRINTER_AVAILABLE = Path("/usr/bin/ippeveprinter").is_file()

import sys

IS_MACOS = sys.platform == "darwin"
