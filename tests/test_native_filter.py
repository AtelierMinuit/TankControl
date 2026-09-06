#!/usr/bin/env python3
"""Tests para el filtro binario nativo rastertopcl3gui (Apple Silicon)."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import subprocess
import sys
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
AUDIT_BUILD = Path(os.environ.get("HP_AUDIT_BUILD_DIR", str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904")))
BINARY_PATH = AUDIT_BUILD / "rastertopcl3gui"
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SAMPLE_RASTER = PROJECT_ROOT / "scratch" / "05-black-square.rgb.raster"

# Cargar decodificador
SPEC_DEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
DECODER = importlib.util.module_from_spec(SPEC_DEC)
sys.modules[SPEC_DEC.name] = DECODER
SPEC_DEC.loader.exec_module(DECODER)


class NativeFilterTests(unittest.TestCase):
    def test_binary_exists_and_is_arm64(self) -> None:
        self.assertTrue(BINARY_PATH.exists(), "rastertopcl3gui debe existir en research/builds/")
        proc = subprocess.run(["file", str(BINARY_PATH)], capture_output=True, text=True, check=True)
        self.assertIn("arm64", proc.stdout)

    def test_binary_links_only_system_libraries(self) -> None:
        proc = subprocess.run(["otool", "-L", str(BINARY_PATH)], capture_output=True, text=True, check=True)
        lines = [line.strip().split()[0] for line in proc.stdout.splitlines()[1:]]
        for lib in lines:
            self.assertTrue(
                lib.startswith("/usr/lib/"),
                f"La biblioteca {lib} debe ser de sistema (/usr/lib/), sin dependencias externas"
            )

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_raster_conversion_preserves_black(self) -> None:
        cmd = [str(BINARY_PATH), "1", "testuser", "testdoc", "1", "", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        pcl_bytes = proc.stdout

        self.assertGreater(len(pcl_bytes), 1000)
        self.assertTrue(pcl_bytes.startswith(b"\x1b%-12345X"))
        self.assertTrue(pcl_bytes.endswith(b"\x1b%-12345X"))

        # Decodificar el flujo resultante
        dec_rows, _, stats, _ = DECODER.decode_stream_mode10(pcl_bytes, 5100, 6600)
        bbox, colors = DECODER.content_summary(dec_rows, 5100)

        # Debe contener negro puro
        self.assertIn((0, 0, 0), colors)
        self.assertGreater(colors[(0, 0, 0)], 250000, "Debe preservar al menos 250,000 pixeles negros")


if __name__ == "__main__":
    unittest.main()
