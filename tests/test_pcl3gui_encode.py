#!/usr/bin/env python3
"""Tests unitarios para el codificador nativo PCL3GUI Mode 10."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import random
import sys
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Cargar decoder y encoder
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SPEC_DEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
DECODER = importlib.util.module_from_spec(SPEC_DEC)
sys.modules[SPEC_DEC.name] = DECODER
SPEC_DEC.loader.exec_module(DECODER)

import tools.pcl3gui_encode as encoder


class Pcl3GuiEncoderTests(unittest.TestCase):
    def test_blank_page_produces_compact_stream(self) -> None:
        width, height = 500, 300
        white_row = bytes([255] * (width * 3))
        rows = [white_row] * height
        stream = encoder.encode_page(rows, width, height, dpi=600, media="a4")
        # El stream debe tener únicamente cabeceras y cierre, sin comandos W
        self.assertNotIn(b"\x1b*b", stream)
        self.assertIn(b"\x1b*r1A", stream)
        self.assertIn(b"\x1b*rC", stream)
        self.assertLess(len(stream), 300)

    def test_pure_black_preservation(self) -> None:
        width, height = 100, 50
        black_row = bytes([0] * (width * 3))
        rows = [black_row] * height
        stream = encoder.encode_page(rows, width, height, dpi=600, media="a4")

        dec_rows, _, stats, _ = DECODER.decode_stream_mode10(stream, width, height)
        self.assertEqual(len(dec_rows), height)
        for y in range(height):
            self.assertEqual(dec_rows[y], black_row, f"Fila {y} debe ser negro puro")

    def test_multi_color_roundtrip(self) -> None:
        width, height = 200, 100
        rows = []
        for y in range(height):
            row = bytearray([255] * (width * 3))
            if 10 <= y < 40:
                for x in range(10, 40):  # Rojo
                    row[x * 3 : x * 3 + 3] = [254, 0, 0]
                for x in range(60, 90):  # Verde
                    row[x * 3 : x * 3 + 3] = [0, 255, 0]
                for x in range(110, 140):  # Azul (par)
                    row[x * 3 : x * 3 + 3] = [0, 0, 254]
                for x in range(160, 190):  # Negro
                    row[x * 3 : x * 3 + 3] = [0, 0, 0]
            rows.append(bytes(row))

        stream = encoder.encode_page(rows, width, height, dpi=600, media="a4")
        dec_rows, _, stats, _ = DECODER.decode_stream_mode10(stream, width, height)
        bbox, colors = DECODER.content_summary(dec_rows, width)

        self.assertEqual(bbox, (10, 10, 190, 40))
        self.assertEqual(colors[(254, 0, 0)], 900)
        self.assertEqual(colors[(0, 255, 0)], 900)
        self.assertEqual(colors[(0, 0, 254)], 900)
        self.assertEqual(colors[(0, 0, 0)], 900)

    def test_property_roundtrip_reproducible_small_images(self) -> None:
        """Cubre 2.000 imágenes pequeñas con seed fija y cuantización azul conocida."""
        rng = random.Random(20260904)
        for case in range(2000):
            width = rng.randint(1, 32)
            height = rng.randint(1, 16)
            rows = [bytes(rng.randrange(256) for _ in range(width * 3)) for _ in range(height)]
            stream = encoder.encode_page(rows, width, height, dpi=600, media="a4")
            decoded, _, _, _ = DECODER.decode_stream_mode10(stream, width, height)
            expected = [
                bytes(value if index % 3 != 2 else value & 0xFE
                      for index, value in enumerate(row))
                for row in rows
            ]
            actual = [decoded[index] for index in range(height)]
            self.assertEqual(len(actual), height, f"filas faltantes en caso={case}")
            for actual_row, expected_row in zip(actual, expected):
                self.assertEqual(len(actual_row), len(expected_row))
                self.assertLessEqual(
                    max(abs(left - right) for left, right in zip(actual_row, expected_row)),
                    1,
                    f"cuantización fuera de límite en seed=20260904 caso={case}",
                )
if __name__ == "__main__":
    unittest.main()
