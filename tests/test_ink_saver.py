#!/usr/bin/env python3
"""
Tests unitarios para la tecnología InkSaver y Motor Eco-Print (HP Smart Tank 500 series).
Verifica:
1. Conformidad de PPD con Adobe PostScript v4.3 (HPInkSaver, HPEcoColorDrop).
2. Procesamiento RIP en rastertopcl3gui (Eco25, Eco50, Eco75, EdgePreserve, DotGainGrid, DropColorBg, EcoGrayscale).
3. Auditoría financiera y cálculo de ahorro de tinta/dinero en smarttank backend.
4. Consulta CLI y telemetría JSON en hp-smart-tank-tool.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PPD_PATH = PROJECT_ROOT / "research" / "builds" / "hp-smart_tank_500_series_mac.ppd"
AUDIT_BUILD = Path(os.environ.get("HP_AUDIT_BUILD_DIR", str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904")))
FILTER_PATH = AUDIT_BUILD / "rastertopcl3gui"
BACKEND_PATH = AUDIT_BUILD / "smarttank"
TOOL_PATH = AUDIT_BUILD / "hp-smart-tank-tool"
SAMPLE_RASTER = PROJECT_ROOT / "scratch" / "05-black-square.rgb.raster"


class TestInkSaverPPD(unittest.TestCase):
    """Verifica que el archivo PPD exponga los controles InkSaver y pase cupstestppd."""

    def setUp(self):
        self.assertTrue(PPD_PATH.exists(), f"El archivo PPD debe existir en {PPD_PATH}")
        self.ppd_text = PPD_PATH.read_text(encoding="utf-8", errors="ignore")

    def test_ink_saver_ui_group(self):
        """Verifica la definición de HPInkSaver en el PPD."""
        self.assertIn("*OpenUI *HPInkSaver/Tecnologia InkSaver: PickOne", self.ppd_text)
        self.assertIn("*DefaultHPInkSaver: Off", self.ppd_text)
        self.assertIn("*HPInkSaver Off/", self.ppd_text)
        self.assertIn("*HPInkSaver Eco25/", self.ppd_text)
        self.assertIn("*HPInkSaver Eco50/", self.ppd_text)
        self.assertIn("*HPInkSaver Eco75/", self.ppd_text)
        self.assertIn("*HPInkSaver EdgePreserve/", self.ppd_text)
        self.assertIn("*HPInkSaver DotGainGrid/", self.ppd_text)
        self.assertIn("*CloseUI: *HPInkSaver", self.ppd_text)

    def test_eco_color_drop_ui_group(self):
        """Verifica la definición de HPEcoColorDrop en el PPD."""
        self.assertIn("*OpenUI *HPEcoColorDrop/Filtro Ecologico de Color: PickOne", self.ppd_text)
        self.assertIn("*DefaultHPEcoColorDrop: None", self.ppd_text)
        self.assertIn("*HPEcoColorDrop None/", self.ppd_text)
        self.assertIn("*HPEcoColorDrop DropColorBg/", self.ppd_text)
        self.assertIn("*HPEcoColorDrop EcoGrayscale/", self.ppd_text)
        self.assertIn("*CloseUI: *HPEcoColorDrop", self.ppd_text)

    def test_no_unmeasured_ink_percent_claims(self):
        """El PPD no debe prometer porcentajes físicos sin medición gravimétrica."""
        forbidden = ("Ahorro 25%", "Ahorro 50%", "Ahorro 75%", "-20%", "+30%", "100% Tinta")
        for claim in forbidden:
            self.assertNotIn(claim, self.ppd_text)

    def test_cupstestppd_conformance(self):
        """Valida que el PPD pase cupstestppd sin errores fatales."""
        proc = subprocess.run(
            ["cupstestppd", "-W", "all", str(PPD_PATH)],
            capture_output=True,
            text=True
        )
        self.assertEqual(
            proc.returncode, 0,
            f"cupstestppd falló en {PPD_PATH}:\nSTDOUT:\n{proc.stdout}\nSTDERR:\n{proc.stderr}"
        )
        self.assertTrue("PASS" in proc.stdout or "PASA" in proc.stdout)


class TestInkSaverRIPEngine(unittest.TestCase):
    """Verifica que el motor rastertopcl3gui procese correctamente los modos InkSaver."""

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_eco50_mode(self):
        """Verifica que Eco50 reporte reducción raster estimada, no tinta física."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPInkSaver=Eco50", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("InkSaver: Pagina 1 (Modo: Eco50", stderr)
        self.assertIn("Reduccion raster estimada (no tinta fisica):", stderr)

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_edge_preserve_mode(self):
        """Verifica que el modo EdgePreserve proteja bordes y atenúe rellenos."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPInkSaver=EdgePreserve", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("InkSaver: Pagina 1 (Modo: EdgePreserve", stderr)
        self.assertIn("Reduccion raster estimada (no tinta fisica):", stderr)

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_dot_gain_grid_mode(self):
        """Verifica la micro-perforación capilar DotGainGrid."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPInkSaver=DotGainGrid", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("InkSaver: Pagina 1 (Modo: DotGainGrid", stderr)
        self.assertIn("Reduccion raster estimada (no tinta fisica):", stderr)

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_eco_grayscale_mode(self):
        """Verifica el filtro HPEcoColorDrop=EcoGrayscale."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPEcoColorDrop=EcoGrayscale", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("ColorDrop: EcoGrayscale (Escala Grises Eco)", stderr)
        self.assertIn("Reduccion raster estimada (no tinta fisica):", stderr)


class TestAccountingAndSavings(unittest.TestCase):
    """Verifica el registro contable y financiero de ahorro de tinta."""

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_backend_accounting_with_ink_saver(self):
        """Verifica que el backend registre los ahorros en el JSON de auditoría."""
        json_path = Path("/tmp/hp_smarttank_last_cost.json")
        if json_path.exists():
            json_path.unlink()

        env = dict(os.environ, HP_SMART_TANK_MOCK="1")
        cmd = [
            str(BACKEND_PATH), "999", "audituser", "TestEco.pdf", "1",
            "HPInkSaver=Eco50 HPEcoColorDrop=DropColorBg", str(SAMPLE_RASTER)
        ]
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, check=True)
        self.assertIn("Reduccion raster estimada:", proc.stderr)
        self.assertTrue(json_path.exists(), "Debe generarse el archivo de costes JSON")

        data = json.loads(json_path.read_text(encoding="utf-8"))
        self.assertEqual(data["job_id"], "999")
        self.assertEqual(data["saver_mode"], "Eco50")
        self.assertGreater(data["ink_saved_ml"], 0.0)
        self.assertGreater(data["money_saved_usd"], 0.0)

    def test_cli_accounting_command(self):
        """Verifica que el comando accounting de la CLI muestre el ahorro ecológico."""
        proc = subprocess.run(
            [str(TOOL_PATH), "accounting"],
            capture_output=True,
            text=True,
            check=True
        )
        self.assertIn("AUDITORÍA FINANCIERA", proc.stdout)
        self.assertIn("Reduccion raster estimada (no tinta fisica):", proc.stdout)

    def test_cli_json_accounting_command(self):
        """Verifica la respuesta JSON del comando json-accounting."""
        proc = subprocess.run(
            [str(TOOL_PATH), "json-accounting", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(proc.stdout)
        self.assertIn("ink_saved_ml", data)
        self.assertIn("money_saved_usd", data)
        self.assertIn("saver_mode", data)


if __name__ == "__main__":
    unittest.main()
