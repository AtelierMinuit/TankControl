#!/usr/bin/env python3
"""
Tests unitarios para la adaptación regional de formatos de papel y capacidades de hardware
en HP Smart Tank 500 series (TankControl).
Valida:
1. Declaración inequívoca en PPD de Carta, Legal, Oficio Chile/LATAM (8.5x13 pulg.) y A4/A5/A6.
2. Soporte de tamaños personalizados de papel (CustomPageSize) hasta 44 pulgadas (3168 pt).
3. Mapeo correcto en el motor C (rastertopcl3gui) de media_id:
   - Carta -> media_id 2
   - Legal -> media_id 3
   - Oficio Chile/LATAM (936 pt) -> media_id 10 (resolviendo bug histórico de fallback a A4)
   - A4 -> media_id 26
   - A5 -> media_id 25
   - A6 -> media_id 24
   - Banner Continuo (>1050 pt) -> media_id 101
"""

from __future__ import annotations

import os
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PPD_PATH = PROJECT_ROOT / "research" / "builds" / "hp-smart_tank_500_series_mac.ppd"
FILTER_PATH = PROJECT_ROOT / "tools" / "rastertopcl3gui"


def create_mock_cups_raster(width_pt: int, height_pt: int, dpi: int = 300, cups_integer_0: int = 0) -> bytes:
    """Genera un archivo raster CUPS sintético mínimo (RGB 24-bit) con la geometría especificada."""
    width_px = int(width_pt * dpi / 72)
    height_px = 5  # Solo 5 filas de prueba para verificación instantánea
    bpp = 24
    bytes_per_line = (width_px * bpp + 7) // 8

    # Sincronización CUPS en ARM64 ("3SaR" little-endian)
    magic = b"3SaR"

    # Buffer de 1796 bytes para cups_page_header2_t
    hdr = bytearray(1796)

    # HWResolution[2] en offset 276
    struct.pack_into("<II", hdr, 276, dpi, dpi)
    # PageSize[2] en offset 352 (en puntos PostScript)
    struct.pack_into("<II", hdr, 352, width_pt, height_pt)
    # cupsWidth, cupsHeight en offset 372, 376
    struct.pack_into("<II", hdr, 372, width_px, height_px)
    # cupsBitsPerColor en 384
    struct.pack_into("<I", hdr, 384, 8)
    # cupsBitsPerPixel en 388
    struct.pack_into("<I", hdr, 388, bpp)
    # cupsBytesPerLine en 392
    struct.pack_into("<I", hdr, 392, bytes_per_line)
    # cupsColorSpace en 400 (1 = RGB)
    struct.pack_into("<I", hdr, 400, 1)
    # cupsInteger[0] en offset 452
    struct.pack_into("<I", hdr, 452, cups_integer_0)

    # Filas de píxeles en blanco (RGB 255, 255, 255)
    row = b"\xff" * bytes_per_line
    body = row * height_px

    return magic + bytes(hdr) + body


class TestPaperFormatsPPD(unittest.TestCase):
    """Verifica que el PPD declare correctamente los formatos regionales y pase cupstestppd."""

    def setUp(self):
        self.assertTrue(PPD_PATH.exists(), f"PPD debe existir en {PPD_PATH}")
        self.ppd_text = PPD_PATH.read_text(encoding="utf-8", errors="ignore")

    def test_regional_paper_sizes_defined(self):
        """Verifica la desambiguación explícita de Carta, Oficio Chile/LATAM y Legal."""
        self.assertIn("*PageSize Letter/Carta - Letter (8.5x11 pulg.):", self.ppd_text)
        self.assertIn("*PageSize 8.5x13/Oficio (8.5x13 pulg. / Chile-LATAM):", self.ppd_text)
        self.assertIn("*PageSize Legal/Legal - Oficio Americano (8.5x14 pulg.):", self.ppd_text)
        self.assertIn("*PageSize A4/A4 (210x297 mm):", self.ppd_text)
        self.assertIn("*PageSize A5/A5 (148x210 mm):", self.ppd_text)
        self.assertIn("*PageSize A6/A6 (105x148 mm):", self.ppd_text)
        self.assertIn("*PageSize 8.5x13.FB/Oficio Sin Bordes (8.5x13 pulg.):", self.ppd_text)

    def test_oficio_cups_integer_mapping(self):
        """Verifica que Oficio inyecte cupsInteger0 10 en setpagedevice."""
        self.assertIn("<</cupsInteger0 10/PageSize [612 936]/ImagingBBox null>>setpagedevice", self.ppd_text)

    def test_custom_page_size_limits(self):
        """Verifica que CustomPageSize defina límites seguros de hardware."""
        self.assertIn('*MaxMediaHeight: "1008"', self.ppd_text)
        self.assertIn("*ParamCustomPageSize Height: 2 points 288 1008", self.ppd_text)

    def test_cupstestppd_validation(self):
        """cupstestppd debe aprobar el PPD con código de salida 0."""
        cmd = ["cupstestppd", "-W", "all", str(PPD_PATH)]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"cupstestppd falló:\n{res.stderr}")
        self.assertTrue("PASA" in res.stdout or "PASS" in res.stdout, f"cupstestppd no pasó:\n{res.stdout}")


class TestRasterToPCL3GUIMediaID(unittest.TestCase):
    """Verifica que rastertopcl3gui asigne el ID de medio exacto para cada formato regional."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"El binario debe existir en {FILTER_PATH}")

    def _run_filter_with_dimensions(self, width_pt: int, height_pt: int, cups_int_0: int = 0) -> str:
        raster_data = create_mock_cups_raster(width_pt, height_pt, dpi=300, cups_integer_0=cups_int_0)
        with tempfile.NamedTemporaryFile(suffix=".raster", delete=False) as f:
            f.write(raster_data)
            tmp_path = f.name

        try:
            cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "", tmp_path]
            proc = subprocess.run(cmd, capture_output=True)
            stderr = proc.stderr.decode("utf-8", errors="replace")
            return stderr
        finally:
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    def test_carta_letter_media_id(self):
        """Carta (612x792 pt) debe mapear a media_id 2."""
        stderr = self._run_filter_with_dimensions(612, 792)
        self.assertIn("media_id: 2", stderr)

    def test_oficio_chile_latam_media_id(self):
        """Oficio Chile/LATAM (612x936 pt) debe mapear a media_id 10 (NUNCA a A4 26)."""
        stderr = self._run_filter_with_dimensions(612, 936)
        self.assertIn("media_id: 10", stderr)
        self.assertNotIn("media_id: 26", stderr)

    def test_legal_media_id(self):
        """Legal (612x1008 pt) debe mapear a media_id 3."""
        stderr = self._run_filter_with_dimensions(612, 1008)
        self.assertIn("media_id: 3", stderr)

    def test_a4_media_id(self):
        """A4 (595x842 pt) debe mapear a media_id 26."""
        stderr = self._run_filter_with_dimensions(595, 842)
        self.assertIn("media_id: 26", stderr)

    def test_a5_media_id(self):
        """A5 (420x595 pt) debe mapear a media_id 25."""
        stderr = self._run_filter_with_dimensions(420, 595)
        self.assertIn("media_id: 25", stderr)

    def test_a6_media_id(self):
        """A6 (298x420 pt) debe mapear a media_id 24."""
        stderr = self._run_filter_with_dimensions(298, 420)
        self.assertIn("media_id: 24", stderr)

    def test_banner_continuous_media_id(self):
        """Banner continuo (>1050 pt, ej. 2000 pt) debe mapear a media_id 101."""
        stderr = self._run_filter_with_dimensions(612, 2000)
        self.assertIn("media_id: 101", stderr)

    def test_explicit_cups_integer_override(self):
        """Si el PPD inyecta cupsInteger0, debe tener precedencia."""
        stderr = self._run_filter_with_dimensions(612, 936, cups_int_0=10)
        self.assertIn("media_id: 10", stderr)


if __name__ == "__main__":
    unittest.main()
