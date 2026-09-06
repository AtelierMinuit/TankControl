#!/usr/bin/env python3
"""Tests para el generador de carta cromática y calibrador ICC."""

from __future__ import annotations

import importlib.util
from pathlib import Path
import subprocess
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
GEN_TARGET = PROJECT_ROOT / "tools" / "generate_color_target.py"
CALIB_ICC = PROJECT_ROOT / "tools" / "calibrate_icc.py"

SPEC_GEN = importlib.util.spec_from_file_location("generate_color_target", GEN_TARGET)
MOD_GEN = importlib.util.module_from_spec(SPEC_GEN)
SPEC_GEN.loader.exec_module(MOD_GEN)

SPEC_CALIB = importlib.util.spec_from_file_location("calibrate_icc", CALIB_ICC)
MOD_CALIB = importlib.util.module_from_spec(SPEC_CALIB)
SPEC_CALIB.loader.exec_module(MOD_CALIB)


class ColorCalibrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp_dir = PROJECT_ROOT / "scratch" / "test_calib"
        self.tmp_dir.mkdir(parents=True, exist_ok=True)

    def test_generate_target_chart_files(self) -> None:
        """Verifica que la generación de carta produzca PPM, PNG y PDF válidos."""
        ppm, png, pdf = MOD_GEN.generate_color_target(dpi=75, output_dir=self.tmp_dir)
        self.assertTrue(ppm.exists())
        self.assertTrue(png.exists())
        self.assertTrue(pdf.exists())

        # Validar con sips
        proc = subprocess.run(["sips", "-g", "pixelWidth", str(png)], capture_output=True, text=True, check=True)
        self.assertIn("pixelWidth", proc.stdout)

    def test_synthesize_and_verify_icc_profile(self) -> None:
        """Verifica que el perfil sintético sea validado por ColorSync (sips)."""
        icc_path = self.tmp_dir / "test_precision.icc"
        MOD_CALIB.synthesize_icc_profile(icc_path, r_gamma=2.2, g_gamma=2.2, b_gamma=2.2)
        self.assertTrue(icc_path.exists())

        # Verificar con sips
        proc = subprocess.run(["sips", "-g", "all", str(icc_path)], capture_output=True, text=True, check=True)
        self.assertIn("format: icc", proc.stdout)
        self.assertIn("typeIdentifier: icc", proc.stdout)

    def test_run_closed_loop_calibration_mock(self) -> None:
        """Verifica el ciclo completo de calibración en bucle cerrado."""
        icc_out = self.tmp_dir / "HP_Smart_Tank_500_Precision_Test.icc"
        res_icc = MOD_CALIB.run_calibration(output_icc=icc_out, mock=True, install=False)
        self.assertTrue(res_icc.exists())
        self.assertGreater(res_icc.stat().st_size, 500)


if __name__ == "__main__":
    unittest.main()
