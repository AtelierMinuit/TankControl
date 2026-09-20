#!/usr/bin/env python3
"""
Tests unitarios para la optimización de velocidad, modo borrador ultrarrápido y modo foto maestro
en el motor RIP C rastertopcl3gui de TankControl.
Valida:
1. Detección y salto de líneas en blanco con comando PCL Esc*b#Y.
2. Detección de opciones OutputMode=FastDraft y OutputMode=PhotoMaster.
3. Umbralización acelerada en modo Borrador (Draft) para ignorar ruido en blanco.
"""

from __future__ import annotations

import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
FILTER_PATH = PROJECT_ROOT / "tools" / "rastertopcl3gui"


def create_mock_raster_with_pattern(width_pt: int, height_pt: int, rows_pattern: list[list[int]], dpi: int = 300) -> bytes:
    """
    Crea un raster CUPS sintético donde rows_pattern define los valores de color RGB
    por fila para probar la compresión y el salto de scanlines.
    """
    width_px = int(width_pt * dpi / 72)
    height_px = len(rows_pattern)
    bpp = 24
    bytes_per_line = (width_px * bpp + 7) // 8

    magic = b"3SaR"
    hdr = bytearray(1796)

    struct.pack_into("<II", hdr, 276, dpi, dpi)
    struct.pack_into("<II", hdr, 352, width_pt, height_pt)
    struct.pack_into("<II", hdr, 372, width_px, height_px)
    struct.pack_into("<I", hdr, 384, 8)
    struct.pack_into("<I", hdr, 388, bpp)
    struct.pack_into("<I", hdr, 392, bytes_per_line)
    struct.pack_into("<I", hdr, 400, 1) # RGB

    pixel_data = bytearray()
    for row_val in rows_pattern:
        r, g, b = row_val
        pixel_data.extend(bytes([r, g, b]) * width_px)

    return magic + bytes(hdr) + bytes(pixel_data)


class TestSpeedOptimization(unittest.TestCase):
    """Verifica el salto de scanlines y la optimización de rendimiento en el driver C."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"El binario debe existir en {FILTER_PATH}")

    def test_blank_scanline_skip_command(self):
        """Verifica que un bloque de 5 filas blancas seguidas de una fila con contenido emita Esc*b5Y."""
        # 5 filas blancas (255, 255, 255), 1 fila negra (0, 0, 0)
        pattern = [
            [255, 255, 255],
            [255, 255, 255],
            [255, 255, 255],
            [255, 255, 255],
            [255, 255, 255],
            [0, 0, 0]
        ]
        raster_data = create_mock_raster_with_pattern(612, 792, pattern, dpi=300)

        with tempfile.NamedTemporaryFile(suffix=".raster", delete=False) as f:
            f.write(raster_data)
            tmp_path = f.name

        try:
            cmd = [str(FILTER_PATH), "1", "user", "title", "1", "OutputMode=Normal", tmp_path]
            res = subprocess.run(cmd, capture_output=True)
            self.assertEqual(res.returncode, 0, f"rastertopcl3gui falló:\n{res.stderr.decode('utf-8', errors='ignore')}")

            # En PCL3GUI, Esc*b5Y representa un salto vertical de 5 filas
            expected_skip = b"\x1b*b5Y"
            self.assertIn(expected_skip, res.stdout, "El controlador debe emitir \\033*b5Y para saltar las filas blancas")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_fast_draft_option_and_quality_cmd(self):
        """Verifica que OutputMode=FastDraft emita quality_cmd = 1."""
        pattern = [[0, 0, 0]]
        raster_data = create_mock_raster_with_pattern(612, 792, pattern, dpi=300)

        with tempfile.NamedTemporaryFile(suffix=".raster", delete=False) as f:
            f.write(raster_data)
            tmp_path = f.name

        try:
            cmd = [str(FILTER_PATH), "1", "user", "title", "1", "OutputMode=FastDraft", tmp_path]
            res = subprocess.run(cmd, capture_output=True)
            self.assertEqual(res.returncode, 0)
            # En PCL3GUI: \033*o1M corresponde a Draft
            self.assertIn(b"\x1b*o1M", res.stdout)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_photo_master_option_and_quality_cmd(self):
        """Verifica que OutputMode=PhotoMaster emita quality_cmd = 4."""
        pattern = [[0, 0, 0]]
        raster_data = create_mock_raster_with_pattern(612, 792, pattern, dpi=300)

        with tempfile.NamedTemporaryFile(suffix=".raster", delete=False) as f:
            f.write(raster_data)
            tmp_path = f.name

        try:
            cmd = [str(FILTER_PATH), "1", "user", "title", "1", "OutputMode=PhotoMaster", tmp_path]
            res = subprocess.run(cmd, capture_output=True)
            self.assertEqual(res.returncode, 0)
            # En PCL3GUI: \033*o4M corresponde a Photo / MaxDPI
            self.assertIn(b"\x1b*o4M", res.stdout)
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)

    def test_fast_draft_near_white_noise_filtering(self):
        """Verifica que en FastDraft los píxeles casi blancos (RGB 252) sean tratados como blanco y salten."""
        # 3 filas casi blancas (252, 252, 252), seguidas de 1 negra
        pattern = [
            [252, 252, 252],
            [252, 252, 252],
            [252, 252, 252],
            [0, 0, 0]
        ]
        raster_data = create_mock_raster_with_pattern(612, 792, pattern, dpi=300)

        with tempfile.NamedTemporaryFile(suffix=".raster", delete=False) as f:
            f.write(raster_data)
            tmp_path = f.name

        try:
            cmd = [str(FILTER_PATH), "1", "user", "title", "1", "OutputMode=FastDraft", tmp_path]
            res = subprocess.run(cmd, capture_output=True)
            self.assertEqual(res.returncode, 0)
            # Debe emitir salto vertical de 3 filas (\x1b*b3Y) gracias al umbral de 250
            expected_skip = b"\x1b*b3Y"
            self.assertIn(expected_skip, res.stdout, "En FastDraft las filas con ruido leve deben saltar mecánicamente")
        finally:
            if os.path.exists(tmp_path):
                os.remove(tmp_path)


if __name__ == "__main__":
    unittest.main()
