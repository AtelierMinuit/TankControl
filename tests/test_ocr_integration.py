#!/usr/bin/env python3
"""
Tests unitarios para la integración de OCR nativo offline con Apple Vision
en TankControl (HP Smart Tank 500).
Valida:
1. Existencia y estructura de OCRService.swift.
2. Configuración de Vision.framework (VNRecognizeTextRequest, idiomas, reconocimiento preciso).
3. Integración en ScannerService (enableOCR, generación de PDF buscable y texto .txt).
"""

from __future__ import annotations

from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SOURCES = PROJECT_ROOT / "apps" / "HPSmartTankUtility" / "Sources"
OCR_SERVICE_PATH = APP_SOURCES / "Services" / "OCRService.swift"
SCANNER_SERVICE_PATH = APP_SOURCES / "Services" / "ScannerService.swift"
SCANNER_VIEW_PATH = APP_SOURCES / "Views" / "ScannerView.swift"


class TestOCRIntegration(unittest.TestCase):
    """Verifica que el servicio de OCR offline cumpla los requisitos de privacidad y estructura técnica."""

    def test_sources_exist(self):
        """Verifica que los archivos fuente de OCR existan."""
        self.assertTrue(OCR_SERVICE_PATH.exists(), f"OCRService debe existir en {OCR_SERVICE_PATH}")
        self.assertTrue(SCANNER_SERVICE_PATH.exists(), f"ScannerService debe existir en {SCANNER_SERVICE_PATH}")
        self.assertTrue(SCANNER_VIEW_PATH.exists(), f"ScannerView debe existir en {SCANNER_VIEW_PATH}")

    def test_ocr_service_uses_vision_framework(self):
        """OCRService debe importar Vision y utilizar VNRecognizeTextRequest."""
        content = OCR_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("import Vision", content)
        self.assertIn("VNRecognizeTextRequest", content)
        self.assertIn("VNImageRequestHandler", content)
        self.assertIn(".accurate", content)
        self.assertIn("usesLanguageCorrection", content)
        self.assertIn("createSearchablePDF", content)

    def test_ocr_languages_supported(self):
        """Debe soportar los 5 idiomas europeos y latinoamericanos principales."""
        content = OCR_SERVICE_PATH.read_text(encoding="utf-8")
        for lang in ["es", "en", "pt", "fr", "de"]:
            self.assertIn(f'"{lang}"', content, f"Idioma {lang} debe estar en las recognitionLanguages de Vision")

    def test_scanner_service_connects_ocr(self):
        """ScannerService debe exponer enableOCR y conectar con OCRService."""
        content = SCANNER_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("enableOCR", content)
        self.assertIn("OCRService.shared", content)

    def test_scanner_view_has_ocr_controls(self):
        """ScannerView debe incluir el Toggle de OCR."""
        content = SCANNER_VIEW_PATH.read_text(encoding="utf-8")
        self.assertIn("enableOCR", content)
        self.assertIn("Texto Buscable (OCR)", content)


if __name__ == "__main__":
    unittest.main()
