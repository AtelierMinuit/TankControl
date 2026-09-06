#!/usr/bin/env python3
"""Pruebas metamórficas y de propiedades para el pipeline PCL3GUI Mode 10."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Cargar decoder
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SPEC_DEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
DECODER = importlib.util.module_from_spec(SPEC_DEC)
sys.modules[SPEC_DEC.name] = DECODER
SPEC_DEC.loader.exec_module(DECODER)

import tools.pcl3gui_encode as encoder


def make_cups_raster(width: int, height: int, rows: list[bytes]) -> bytes:
    sync_word = struct.pack("<I", 0x52615333)
    header = bytearray(1796)
    struct.pack_into("<II", header, 276, 600, 600)
    struct.pack_into("<II", header, 352, 612, 792)
    struct.pack_into("<I", header, 372, width)
    struct.pack_into("<I", header, 376, height)
    struct.pack_into("<I", header, 384, 8)
    struct.pack_into("<I", header, 388, 24)
    struct.pack_into("<I", header, 392, width * 3)
    struct.pack_into("<I", header, 396, 0)
    struct.pack_into("<I", header, 400, 1)  # RGB
    struct.pack_into("<I", header, 420, 3)
    return sync_word + bytes(header) + b"".join(rows)


class Pcl3GuiMetamorphicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.c_filter = str(PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "rastertopcl3gui")

    def test_property_5000_differential_roundtrips(self) -> None:
        """Prueba 5.000 casos deterministas generados con seed fija."""
        rng = random.Random(424242)
        for i in range(5000):
            w = rng.randint(1, 48)
            h = rng.randint(1, 8)
            mode = i % 5
            if mode == 0:  # Blanco puro
                rows = [bytes([255] * (w * 3)) for _ in range(h)]
            elif mode == 1:  # Negro puro
                rows = [bytes([0] * (w * 3)) for _ in range(h)]
            elif mode == 2:  # Filas repetidas
                sample = bytes(rng.randrange(256) for _ in range(w * 3))
                rows = [sample] * h
            elif mode == 3:  # Degradado horizontal
                rows = [bytes((x * 255 // max(1, w - 1)) for x in range(w) for _ in range(3)) for _ in range(h)]
            else:  # Ruido pseudoaleatorio
                rows = [bytes(rng.randrange(256) for _ in range(w * 3)) for _ in range(h)]

            stream = encoder.encode_page(rows, w, h, dpi=600, media="a4")
            dec_rows, _, _, _ = DECODER.decode_stream_mode10(stream, w, h)
            if not dec_rows and all(all(b == 255 for b in r) for r in rows):
                continue  # Optimización PCL3GUI estándar: páginas en blanco no emiten filas de raster
            self.assertEqual(len(dec_rows), h, f"Altura incorrecta en caso {i}")

            for y in range(h):
                orig = rows[y]
                dec = dec_rows[y]
                for x in range(w):
                    # R y G deben ser idénticos
                    self.assertEqual(orig[x * 3], dec[x * 3], f"R mismatch caso {i} en ({x},{y})")
                    self.assertEqual(orig[x * 3 + 1], dec[x * 3 + 1], f"G mismatch caso {i} en ({x},{y})")
                    # B se cuantiza al bit 0 en Mode 10
                    self.assertLessEqual(abs(orig[x * 3 + 2] - dec[x * 3 + 2]), 1, f"B mismatch caso {i} en ({x},{y})")

    def test_metamorphic_identical_rows_compression(self) -> None:
        """Propiedad metamórfica: N filas idénticas consecutivas producen compresión delta creciente."""
        w, h = 64, 10
        row = bytes([100, 150, 200] * w)
        stream_1 = encoder.encode_page([row] * 1, w, 1, dpi=600, media="a4")
        stream_10 = encoder.encode_page([row] * 10, w, 10, dpi=600, media="a4")
        # El stream de 10 filas repetidas debe ser significativamente menor que 10x stream_1
        self.assertLess(len(stream_10), len(stream_1) * 3)

    def test_metamorphic_c_filter_vs_python_encoder_equivalence(self) -> None:
        """Propiedad metamórfica: El filtro C nativo y el encoder Python decodifican la misma imagen."""
        w, h = 32, 16
        rows = [bytes((x + y * 7) % 256 for x in range(w * 3)) for y in range(h)]
        raster_data = make_cups_raster(w, h, rows)

        with tempfile.TemporaryDirectory() as td:
            ras_path = Path(td) / "test.raster"
            ras_path.write_bytes(raster_data)

            # 1. Salida de C
            res = subprocess.run([self.c_filter, "1", "u", "t", "1", "", str(ras_path)], capture_output=True, check=True)
            c_pcl = res.stdout

            # 2. Salida de Python
            py_pcl = encoder.encode_page(rows, w, h, dpi=600, media="a4")

            # Decodificar ambos
            c_dec, _, _, _ = DECODER.decode_stream_mode10(c_pcl, w, h)
            py_dec, _, _, _ = DECODER.decode_stream_mode10(py_pcl, w, h)

            self.assertEqual(len(c_dec), len(py_dec))
            for y in range(h):
                self.assertEqual(c_dec[y], py_dec[y], f"Fila {y} difiere entre C y Python")


if __name__ == "__main__":
    unittest.main()
