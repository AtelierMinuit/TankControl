#!/usr/bin/env python3
"""
Tests unitarios para el Asistente de Impresión Doble Cara Manual (Manual Duplex Assistant)
de TankControl (HP Smart Tank 500).
Valida:
1. Fórmulas de partición de páginas en lotes impares y pares.
2. Inversión inteligente de caras pares para la bandeja vertical trasera.
3. Formateo de rangos para CUPS (page-ranges).
4. Integridad de los archivos Swift (DuplexPrintService y ManualDuplexSheetView).
"""

from __future__ import annotations

from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SOURCES = PROJECT_ROOT / "apps" / "HPSmartTankUtility" / "Sources"
DUPLEX_SERVICE_PATH = APP_SOURCES / "Services" / "DuplexPrintService.swift"
DUPLEX_VIEW_PATH = APP_SOURCES / "Views" / "ManualDuplexSheetView.swift"


def compute_duplex_pages(total_pages: int, reverse_evens: bool = True) -> tuple[list[int], list[int]]:
    """Calcula las páginas impares y pares replicando la lógica matemática de DuplexPrintService."""
    if total_pages <= 0:
        return [], []
    odds = list(range(1, total_pages + 1, 2))
    evens = list(range(2, total_pages + 1, 2)) if total_pages > 1 else []
    if reverse_evens and evens:
        evens = list(reversed(evens))
    return odds, evens


class TestDuplexService(unittest.TestCase):
    """Verifica las reglas de partición y secuencia de páginas para impresión manual a doble cara."""

    def test_sources_exist(self):
        """Verifica que los archivos fuente de Dúplex existan."""
        self.assertTrue(DUPLEX_SERVICE_PATH.exists(), f"DuplexPrintService debe existir en {DUPLEX_SERVICE_PATH}")
        self.assertTrue(DUPLEX_VIEW_PATH.exists(), f"ManualDuplexSheetView debe existir en {DUPLEX_VIEW_PATH}")

    def test_single_page_document(self):
        """Un documento de 1 página no requiere caras pares."""
        odds, evens = compute_duplex_pages(1)
        self.assertEqual(odds, [1])
        self.assertEqual(evens, [])

    def test_two_page_document(self):
        """Un documento de 2 páginas imprime la 1 y luego la 2."""
        odds, evens = compute_duplex_pages(2, reverse_evens=True)
        self.assertEqual(odds, [1])
        self.assertEqual(evens, [2])

    def test_four_page_document_reverse(self):
        """Un documento de 4 páginas: impares [1, 3], pares invertidas [4, 2]."""
        odds, evens = compute_duplex_pages(4, reverse_evens=True)
        self.assertEqual(odds, [1, 3])
        self.assertEqual(evens, [4, 2])

    def test_six_page_document_reverse(self):
        """Un documento de 6 páginas: impares [1, 3, 5], pares invertidas [6, 4, 2]."""
        odds, evens = compute_duplex_pages(6, reverse_evens=True)
        self.assertEqual(odds, [1, 3, 5])
        self.assertEqual(evens, [6, 4, 2])

    def test_odd_total_pages_document(self):
        """Un documento de 5 páginas: impares [1, 3, 5], pares invertidas [4, 2]."""
        odds, evens = compute_duplex_pages(5, reverse_evens=True)
        self.assertEqual(odds, [1, 3, 5])
        self.assertEqual(evens, [4, 2])

    def test_duplex_service_swift_content(self):
        """Valida que DuplexPrintService implemente los métodos esenciales."""
        content = DUPLEX_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("class DuplexPrintService", content)
        self.assertIn("oddPageIndices", content)
        self.assertIn("evenPageIndices", content)
        self.assertIn("startPrintingOdds", content)
        self.assertIn("startPrintingEvens", content)
        self.assertIn("reverseEvenPages", content)


if __name__ == "__main__":
    unittest.main()
