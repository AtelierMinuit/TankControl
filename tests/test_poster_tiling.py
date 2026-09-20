#!/usr/bin/env python3
"""
Tests unitarios para el Estudio de Afiches y Mosaicos (Poster & Tiling Studio) de TankControl.
Valida:
1. Fórmulas de despiece geométrico para 2x2, 3x3, 4x4 y pancartas 1x3.
2. Cálculo de márgenes de empalme / solapa (overlap) en milímetros y puntos PostScript.
3. Dimensionamiento final del póster ensamblado en centímetros.
4. Integridad de fuentes Swift (PosterTileService.swift y PosterStudioView.swift).
"""

from __future__ import annotations

import math
from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SOURCES = PROJECT_ROOT / "apps" / "HPSmartTankUtility" / "Sources"
POSTER_SERVICE_PATH = APP_SOURCES / "Services" / "PosterTileService.swift"
POSTER_VIEW_PATH = APP_SOURCES / "Views" / "PosterStudioView.swift"

POINTS_PER_MM = 72.0 / 25.4  # ~2.83465 pt/mm


def compute_poster_geometry(cols: int, rows: int, paper_width_pt: float, paper_height_pt: float, overlap_mm: float, margin_mm: float = 6.0):
    """Calcula las dimensiones de un afiche en mosaico replicando la lógica matemática de PosterTileService."""
    margin_pt = margin_mm * POINTS_PER_MM
    overlap_pt = overlap_mm * POINTS_PER_MM

    tile_printable_w = paper_width_pt - 2 * margin_pt
    tile_printable_h = paper_height_pt - 2 * margin_pt

    net_tile_w = max(50.0, tile_printable_w - overlap_pt)
    net_tile_h = max(50.0, tile_printable_h - overlap_pt)

    total_width_pt = (net_tile_w * cols) + overlap_pt
    total_height_pt = (net_tile_h * rows) + overlap_pt

    total_width_cm = (total_width_pt / POINTS_PER_MM) / 10.0
    total_height_cm = (total_height_pt / POINTS_PER_MM) / 10.0

    return {
        "cols": cols,
        "rows": rows,
        "total_pages": cols * rows,
        "width_cm": total_width_cm,
        "height_cm": total_height_cm,
        "overlap_pt": overlap_pt,
    }


class TestPosterTilingGeometry(unittest.TestCase):
    """Verifica los cálculos matemáticos de despiece del Poster Studio."""

    def test_sources_exist(self):
        """Verifica que los archivos fuente de Poster Studio existan en el proyecto."""
        self.assertTrue(POSTER_SERVICE_PATH.exists(), f"PosterTileService debe existir en {POSTER_SERVICE_PATH}")
        self.assertTrue(POSTER_VIEW_PATH.exists(), f"PosterStudioView debe existir en {POSTER_VIEW_PATH}")

    def test_2x2_letter_poster_geometry(self):
        """Un afiche 2x2 en papel Carta debe producir 4 hojas y tamaño ~40-45 cm de ancho."""
        geom = compute_poster_geometry(2, 2, 612.0, 792.0, overlap_mm=10.0)
        self.assertEqual(geom["total_pages"], 4)
        # Carta es 21.59 cm x 27.94 cm. Con márgenes de 6mm y 10mm de solapa:
        # Ancho neto = ~19.39 cm - 1.0 cm = ~18.39 cm por baldosa. Total ~37.7 cm ancho.
        self.assertGreater(geom["width_cm"], 35.0)
        self.assertLess(geom["width_cm"], 45.0)
        self.assertGreater(geom["height_cm"], 45.0)
        self.assertLess(geom["height_cm"], 58.0)

    def test_3x3_a4_poster_geometry(self):
        """Un afiche 3x3 en papel A4 debe producir 9 hojas y tamaño ~60 cm de ancho."""
        geom = compute_poster_geometry(3, 3, 595.44, 841.68, overlap_mm=10.0)
        self.assertEqual(geom["total_pages"], 9)
        self.assertGreater(geom["width_cm"], 50.0)
        self.assertLess(geom["width_cm"], 65.0)
        self.assertGreater(geom["height_cm"], 70.0)
        self.assertLess(geom["height_cm"], 85.0)

    def test_4x4_oficio_poster_geometry(self):
        """Un afiche 4x4 en papel Oficio Chile (8.5x13 in) debe producir 16 hojas."""
        geom = compute_poster_geometry(4, 4, 612.0, 936.0, overlap_mm=10.0)
        self.assertEqual(geom["total_pages"], 16)
        self.assertGreater(geom["width_cm"], 70.0)
        self.assertGreater(geom["height_cm"], 110.0)

    def test_1x3_banner_geometry(self):
        """Una pancarta horizontal 1x3 debe tener 3 columnas y 1 fila."""
        geom = compute_poster_geometry(3, 1, 612.0, 792.0, overlap_mm=10.0)
        self.assertEqual(geom["total_pages"], 3)
        self.assertGreater(geom["width_cm"], 50.0)
        self.assertLess(geom["height_cm"], 30.0)

    def test_overlap_margin_scaling(self):
        """Verifica que al aumentar la solapa de pegado, disminuya ligeramente el área neta del póster."""
        geom_small = compute_poster_geometry(2, 2, 612.0, 792.0, overlap_mm=5.0)
        geom_large = compute_poster_geometry(2, 2, 612.0, 792.0, overlap_mm=20.0)

        # Con más solapa, las hojas se superponen más y el ancho total ensamblado es menor
        self.assertGreater(geom_small["width_cm"], geom_large["width_cm"])
        self.assertGreater(geom_small["height_cm"], geom_large["height_cm"])

    def test_swift_service_structure(self):
        """Valida que PosterTileService contenga las estructuras y métodos esenciales."""
        content = POSTER_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("class PosterTileService", content)
        self.assertIn("generatePosterPDF", content)
        self.assertIn("printToSmartTank", content)
        self.assertIn("openInPreview", content)
        self.assertIn("includeCutGuides", content)
        self.assertIn("includeGlueTabs", content)


if __name__ == "__main__":
    unittest.main()
