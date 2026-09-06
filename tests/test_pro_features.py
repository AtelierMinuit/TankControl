#!/usr/bin/env python3
"""
Tests unitarios para características profesionales:
 Controles expuestos por el PPD y transformaciones RIP sujetas a validación física.
"""

from __future__ import annotations

import json
import os
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


class TestProPPDFeatures(unittest.TestCase):
    """Verifica que el PPD no vuelva a exponer el banner no demostrado."""

    def setUp(self):
        self.assertTrue(PPD_PATH.exists(), f"PPD debe existir en {PPD_PATH}")
        self.ppd_text = PPD_PATH.read_text(encoding="utf-8", errors="ignore")

    def test_custom_page_size_banner_limits(self):
        """Verifica ancho máximo conocido y límite seguro sin afirmar banner continuo."""
        self.assertIn('*MaxMediaWidth: "612"', self.ppd_text)
        self.assertIn('*MaxMediaHeight: "1008"', self.ppd_text)
        self.assertIn("*ParamCustomPageSize Width: 1 points 216 612", self.ppd_text)
        self.assertIn("*ParamCustomPageSize Height: 2 points 288 1008", self.ppd_text)

    def test_pro_options_in_ppd(self):
        """Verifica la existencia de HPPureBlack, HPTACLimit, HPGammaCurve y HPWatermark."""
        # Negro Puro
        self.assertIn("*OpenUI *HPPureBlack/Negro Puro: PickOne", self.ppd_text)
        self.assertIn("*HPPureBlack Standard/Estandar Mezcla CMYK:", self.ppd_text)
        self.assertIn("*HPPureBlack TextOnly/Solo Texto GT51 Puro:", self.ppd_text)
        self.assertIn("*HPPureBlack AggressiveK/Separacion K con UCR:", self.ppd_text)

        # Límite TAC
        self.assertIn("*OpenUI *HPTACLimit/Limite Cobertura TAC: PickOne", self.ppd_text)
        self.assertIn("*HPTACLimit TAC240/240% Papel Comun 75g:", self.ppd_text)
        self.assertIn("*HPTACLimit TAC280/280% Presentacion Mate:", self.ppd_text)

        # Curva Tonal
        self.assertIn("*OpenUI *HPGammaCurve/Curva Tonal y Sombras: PickOne", self.ppd_text)
        self.assertIn("*HPGammaCurve ShadowBoost/Recuperacion de Sombras:", self.ppd_text)
        self.assertIn("*HPGammaCurve HighContrast/Alto Contraste S-Curve:", self.ppd_text)
        self.assertIn("*HPGammaCurve VividLandscape/Paisajes Vivos:", self.ppd_text)

        # Marca de Agua
        self.assertIn("*OpenUI *HPWatermark/Marca de Agua RIP: PickOne", self.ppd_text)
        self.assertIn("*HPWatermark Draft/BORRADOR:", self.ppd_text)
        self.assertIn("*HPWatermark Confidential/CONFIDENCIAL:", self.ppd_text)

    def test_cupstestppd_conformance(self):
        """Valida que cupstestppd acepte las nuevas opciones y custom sizes sin errores."""
        res = subprocess.run(["cupstestppd", "-W", "all", str(PPD_PATH)], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"cupstestppd falló: {res.stderr}\n{res.stdout}")
        self.assertTrue("PASA" in res.stdout or "PASS" in res.stdout)


class TestProRasterFilter(unittest.TestCase):
    """Verifica que el motor rastertopcl3gui procese las opciones profesionales."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"Filtro debe existir en {FILTER_PATH}")

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_pure_black_and_tac_options(self):
        """Verifica que HPPureBlack y HPTACLimit se activen en el log de proceso."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPPureBlack=TextOnly HPTACLimit=TAC240", str(SAMPLE_RASTER)]
        res = subprocess.run(cmd, capture_output=True, check=True)
        stderr = res.stderr.decode("utf-8", errors="ignore")
        self.assertIn("NegroPuro: 1", stderr)
        self.assertIn("TAC: 240", stderr)

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_gamma_and_watermark_options(self):
        """Verifica que HPGammaCurve y HPWatermark se activen y procesen."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "HPGammaCurve=ShadowBoost HPWatermark=Draft", str(SAMPLE_RASTER)]
        res = subprocess.run(cmd, capture_output=True, check=True)
        stderr = res.stderr.decode("utf-8", errors="ignore")
        self.assertIn("Gamma: 1", stderr)
        self.assertIn("MarcaAgua: BORRADOR", stderr)


class TestBackendAccounting(unittest.TestCase):
    """Verifica que el backend registre la contabilidad financiera y consumo."""

    def setUp(self):
        self.assertTrue(BACKEND_PATH.exists(), f"Backend debe existir en {BACKEND_PATH}")

    def test_accounting_logged_on_job(self):
        env = dict(os.environ, HP_SMART_TANK_MOCK="1")
        cmd = [str(BACKEND_PATH), "99", "contabilidad_user", "Factura_Pro.pdf", "2", "", "/dev/null"]
        res = subprocess.run(cmd, capture_output=True, text=True, env=env, check=True)
        stderr = res.stderr
        self.assertIn("Contabilidad: Trabajo #99", stderr)
        self.assertIn("Costo estimado:", stderr)

        # Verificar JSON generado
        last_cost_path = Path("/tmp/hp_smarttank_last_cost.json")
        self.assertTrue(last_cost_path.exists())
        data = json.loads(last_cost_path.read_text())
        self.assertEqual(data["job_id"], "99")
        self.assertGreater(data["cost_usd"], 0)


class TestCLIDiagnostics(unittest.TestCase):
    """Verifica los nuevos comandos de terminal accounting y test-pattern."""

    def setUp(self):
        self.assertTrue(TOOL_PATH.exists(), f"Herramienta debe existir en {TOOL_PATH}")

    def test_accounting_command(self):
        res = subprocess.run([str(TOOL_PATH), "accounting", "--mock"], capture_output=True, text=True, check=True)
        self.assertIn("AUDITORÍA FINANCIERA Y CONTABILIDAD DE COSTES", res.stdout)
        self.assertIn("Costo promedio por página", res.stdout)

    def test_json_accounting_command(self):
        res = subprocess.run([str(TOOL_PATH), "json-accounting", "--mock"], capture_output=True, text=True, check=True)
        data = json.loads(res.stdout)
        self.assertIn("cost_usd", data)

    def test_test_pattern_command(self):
        for pattern in ["grid", "cmyk", "alignment"]:
            res = subprocess.run([str(TOOL_PATH), "test-pattern", pattern, "--mock"], capture_output=True, text=True, check=True)
            self.assertIn("PATRÓN PROFESIONAL DE DIAGNÓSTICO", res.stdout)
            self.assertIn(pattern, res.stdout)


if __name__ == "__main__":
    unittest.main()
