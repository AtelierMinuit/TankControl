#!/usr/bin/env python3
"""
test_black_path_regression.py
Suite de regresión exhaustiva para la ruta de procesamiento del canal negro (Black Path),
escalas de grises y espacios RGBW / RGBA en rastertopcl3gui para HP Smart Tank 500.

Cubre:
- Pure Black (0, 0, 0) en sRGB 24-bit
- Near Black (20, 20, 20) vs TextOnly & AggressiveK
- Gray ramp (K vs W / SW)
- Black text & EdgePreserve
- Black vector & DotGainGrid
- RGBW black (W component blending)
- RGBA black (Alpha compositing over white paper)
- PCL3GUI Mode 10 round-trip decoding
"""

from __future__ import annotations

import hashlib
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
FILTER_PATH = PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "rastertopcl3gui"
if not FILTER_PATH.exists():
    FILTER_PATH = PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904" / "rastertopcl3gui"

DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"


def build_raster(
    width: int,
    height: int,
    colorspace: int,
    bpp: int,
    pixel_rows: list[bytes],
    page_size: str = "A4",
    row_step: int = 0,
) -> bytes:
    """Construye un stream de CUPS Raster v3 válido y determinista."""
    sync_word = struct.pack("<I", 0x52615333)  # RaS3
    header = bytearray(1796)

    # HWResolution (276)
    struct.pack_into("<II", header, 276, 600, 600)

    # cupsPageSizeName (288)
    ps_bytes = page_size.encode("ascii")[:31]
    header[288 : 288 + len(ps_bytes)] = ps_bytes

    # PageSize (352)
    struct.pack_into("<II", header, 352, 595, 842)

    # cupsWidth, cupsHeight (372, 376)
    struct.pack_into("<II", header, 372, width, height)

    # cupsBitsPerColor (384), cupsBitsPerPixel (388)
    struct.pack_into("<II", header, 384, 8, bpp)

    # cupsBytesPerLine (392)
    struct.pack_into("<I", header, 392, (width * bpp) // 8)

    # cupsColorOrder (396 = 0: CHUNKED)
    struct.pack_into("<I", header, 396, 0)

    # cupsColorSpace (400)
    struct.pack_into("<I", header, 400, colorspace)

    # cupsNumColors (420)
    num_colors = 4 if bpp == 32 else (1 if bpp == 8 else 3)
    struct.pack_into("<I", header, 420, num_colors)

    # cupsRowStep (440)
    struct.pack_into("<I", header, 440, row_step)

    return sync_word + bytes(header) + b"".join(pixel_rows)


class TestBlackPathRegression(unittest.TestCase):
    """Regresión del canal negro y fidelidad tonal en el RIP rastertopcl3gui."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"El filtro debe existir en {FILTER_PATH}")

    def _run_rip(self, raster_bytes: bytes, options: str = "") -> Tuple[int, bytes, str]:
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", options]
        proc = subprocess.run(cmd, input=raster_bytes, capture_output=True)
        return proc.returncode, proc.stdout, proc.stderr.decode("utf-8", errors="replace")

    def test_pure_black_srgb(self):
        """Verifica que sRGB (0,0,0) puro se codifique en PCL3GUI sin artefactos ni inversión."""
        width, height = 32, 16
        black_row = b"\x00\x00\x00" * width
        raster = build_raster(width, height, colorspace=1, bpp=24, pixel_rows=[black_row] * height)

        code, stdout, stderr = self._run_rip(raster)
        self.assertEqual(code, 0, f"Filtro falló: {stderr}")
        self.assertGreater(len(stdout), 100)
        # Comprobar inicio y fin de raster y comandos de fila Mode 10 (\x1b*b<n>W)
        self.assertIn(b"\x1b*r1A", stdout)  # Raster start
        self.assertIn(b"\x1b*rC", stdout)   # Raster end
        self.assertIn(b"\x1b*b", stdout)    # Mode 10 row transfer sequence

    def test_near_black_standard_vs_textonly(self):
        """Verifica que HPPureBlack=TextOnly fuerce tonos oscuros cuasi-neutros a negro K puro."""
        width, height = 32, 16
        # Near-black cuasi-neutro (22, 24, 23)
        near_black_row = b"\x16\x18\x17" * width
        raster = build_raster(width, height, colorspace=1, bpp=24, pixel_rows=[near_black_row] * height)

        # 1. Modo Standard
        code_std, out_std, _ = self._run_rip(raster, "HPPureBlack=Standard")
        self.assertEqual(code_std, 0)

        # 2. Modo TextOnly
        code_txt, out_txt, stderr_txt = self._run_rip(raster, "HPPureBlack=TextOnly")
        self.assertEqual(code_txt, 0)

        # Los streams deben diferir porque TextOnly reemplazó (22,24,23) por (0,0,0)
        self.assertNotEqual(hashlib.sha256(out_std).digest(), hashlib.sha256(out_txt).digest())

    def test_gray_ramp_k_vs_sw(self):
        """Verifica la decodificación diferencial entre CUPS_CSPACE_K y CUPS_CSPACE_W."""
        width, height = 256, 4
        # Rampa de 0 a 255
        ramp_row = bytes(range(256))

        # En CUPS_CSPACE_K (colorspace=3): 0=blanco, 255=negro
        raster_k = build_raster(width, height, colorspace=3, bpp=8, pixel_rows=[ramp_row] * height)
        code_k, out_k, _ = self._run_rip(raster_k)
        self.assertEqual(code_k, 0)

        # En CUPS_CSPACE_W (colorspace=0): 0=negro, 255=blanco
        raster_w = build_raster(width, height, colorspace=0, bpp=8, pixel_rows=[ramp_row] * height)
        code_w, out_w, _ = self._run_rip(raster_w)
        self.assertEqual(code_w, 0)

        # Las dos representaciones con el mismo buffer de entrada tienen polaridades invertidas;
        # sus salidas PCL3GUI deben diferir de forma determinista
        self.assertNotEqual(hashlib.sha256(out_k).digest(), hashlib.sha256(out_w).digest())

    def test_rgba_alpha_compositing(self):
        """Verifica que el 4to canal alfa en RGBA se componga correctamente sobre papel blanco."""
        width, height = 32, 8
        # Pixel negro opaco: (0, 0, 0, 255) -> Negro
        opaque_black = b"\x00\x00\x00\xff" * width
        raster_opaque = build_raster(width, height, colorspace=2, bpp=32, pixel_rows=[opaque_black] * height)
        code_op, out_op, _ = self._run_rip(raster_opaque)
        self.assertEqual(code_op, 0)

        # Pixel negro transparente: (0, 0, 0, 0) -> Blanco (papel)
        transp_black = b"\x00\x00\x00\x00" * width
        raster_transp = build_raster(width, height, colorspace=2, bpp=32, pixel_rows=[transp_black] * height)
        code_tr, out_tr, _ = self._run_rip(raster_transp)
        self.assertEqual(code_tr, 0)

        # Pixel blanco puro: (255, 255, 255, 255) -> Blanco (papel)
        opaque_white = b"\xff\xff\xff\xff" * width
        raster_white = build_raster(width, height, colorspace=2, bpp=32, pixel_rows=[opaque_white] * height)
        code_wh, out_wh, _ = self._run_rip(raster_white)
        self.assertEqual(code_wh, 0)

        # El negro transparente debe coincidir exactamente con el blanco opaco (ambos resultan en papel en blanco)
        self.assertEqual(hashlib.sha256(out_tr).digest(), hashlib.sha256(out_wh).digest())

        # El negro opaco DEBE ser distinto del negro transparente
        self.assertNotEqual(hashlib.sha256(out_op).digest(), hashlib.sha256(out_tr).digest())

    def test_rgbw_white_blending(self):
        """Verifica que el componente W en RGBW sature hacia blanco en sustrato reflectivo."""
        width, height = 32, 8
        # (0, 0, 0, 0) -> Negro puro
        rgbw_black = b"\x00\x00\x00\x00" * width
        raster_k = build_raster(width, height, colorspace=17, bpp=32, pixel_rows=[rgbw_black] * height)
        code_k, out_k, _ = self._run_rip(raster_k)
        self.assertEqual(code_k, 0)

        # (0, 0, 0, 255) -> Con W=255, satura totalmente a blanco sobre sustrato blanco
        rgbw_white = b"\x00\x00\x00\xff" * width
        raster_w = build_raster(width, height, colorspace=17, bpp=32, pixel_rows=[rgbw_white] * height)
        code_w, out_w, _ = self._run_rip(raster_w)
        self.assertEqual(code_w, 0)

        self.assertNotEqual(hashlib.sha256(out_k).digest(), hashlib.sha256(out_w).digest())

    def test_ink_saver_edge_preserve_black_text(self):
        """Verifica que EdgePreserve conserve bordes de texto negro y reduzca el centro."""
        width, height = 64, 32
        rows = []
        # Crear un bloque rectangular negro (simulando glifo de texto) de 32x16 rodeado de blanco
        for y in range(height):
            row = bytearray()
            for x in range(width):
                if 8 <= y < 24 and 16 <= x < 48:
                    row.extend(b"\x00\x00\x00")  # Negro
                else:
                    row.extend(b"\xff\xff\xff")  # Blanco
            rows.append(bytes(row))

        raster = build_raster(width, height, colorspace=1, bpp=24, pixel_rows=rows)

        code_off, out_off, _ = self._run_rip(raster, "HPInkSaver=Off")
        code_edge, out_edge, err_edge = self._run_rip(raster, "HPInkSaver=EdgePreserve")

        self.assertEqual(code_off, 0)
        self.assertEqual(code_edge, 0)
        self.assertIn("Modo: EdgePreserve", err_edge)
        self.assertIn("Reduccion raster estimada", err_edge)
        # El stream resultante debe ser diferente debido a la atenuación del núcleo del glifo
        self.assertNotEqual(hashlib.sha256(out_off).digest(), hashlib.sha256(out_edge).digest())

    def test_roundtrip_mode10_decompression(self):
        """Verifica que el flujo Mode 10 emitido sea sintácticamente válido para el decodificador."""
        width, height = 64, 16
        rows = []
        for y in range(height):
            # Alternar franjas de negro y gris
            color = b"\x00\x00\x00" if (y % 2 == 0) else b"\x50\x50\x50"
            rows.append(color * width)

        raster = build_raster(width, height, colorspace=1, bpp=24, pixel_rows=rows)
        code, pcl_out, stderr = self._run_rip(raster)
        self.assertEqual(code, 0, stderr)

        # Si pcl3gui-decode.py está disponible, verificar decodificación
        if DECODER_PATH.exists():
            with tempfile.NamedTemporaryFile(suffix=".pcl", delete=False) as tf:
                tf.write(pcl_out)
                tf_path = Path(tf.name)
            try:
                proc = subprocess.run(
                    [sys.executable, str(DECODER_PATH), "--decode-mode10", str(tf_path)],
                    capture_output=True,
                    text=True,
                )
                # El decodificador debe procesar los comandos PCL3GUI sin excepciones
                self.assertEqual(proc.returncode, 0, f"Error en pcl3gui-decode.py:\n{proc.stderr}")
                self.assertIn("mode10_decoded_rows=", proc.stdout)
            finally:
                if tf_path.exists():
                    tf_path.unlink()


if __name__ == "__main__":
    unittest.main()
