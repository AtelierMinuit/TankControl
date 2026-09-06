#!/usr/bin/env python3
"""
Tests unitarios para controles avanzados de RIP, PPD auditado, PML de secado
e inyección directa de hardware (HP Smart Tank 500 series), sin afirmar validación física.
"""

from __future__ import annotations

import os
from pathlib import Path
import os
import subprocess
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
PPD_PATH = PROJECT_ROOT / "research" / "builds" / "hp-smart_tank_500_series_mac.ppd"
AUDIT_BUILD = Path(os.environ.get("HP_AUDIT_BUILD_DIR", str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904")))
FILTER_PATH = AUDIT_BUILD / "rastertopcl3gui"
TOOL_PATH = AUDIT_BUILD / "hp-smart-tank-tool"
SAMPLE_RASTER = PROJECT_ROOT / "scratch" / "05-black-square.rgb.raster"


class TestPPDLiberation(unittest.TestCase):
    """Verifica que el PPD conserve las restricciones de compatibilidad de HPLIP."""

    def setUp(self):
        self.assertTrue(PPD_PATH.exists(), f"El archivo PPD debe existir en {PPD_PATH}")
        self.ppd_text = PPD_PATH.read_text(encoding="utf-8", errors="ignore")

    def test_reference_ui_constraints_preserved(self):
        """Evita exponer combinaciones que HPLIP bloquea para este modelo."""
        required_constraints = [
            "*UIConstraints: *PageSize A4 *MediaType Glossy",
            "*UIConstraints: *PageSize Letter *MediaType Glossy",
            "*UIConstraints: *PageSize A5 *MediaType Glossy",
            "*UIConstraints: *PageSize B5 *MediaType Glossy",
            "*UIConstraints: *PageSize A4 *MediaType FastGlossy",
            "*UIConstraints: *PageSize Letter *MediaType FastGlossy",
            "*UIConstraints: *PageSize A4 *MediaType BrochureGlosy",
        ]
        for constraint in required_constraints:
            self.assertIn(
                constraint,
                self.ppd_text,
                f"Falta restricción de compatibilidad heredada de HPLIP: {constraint}"
            )

    def test_hp_advanced_group_exists(self):
        """Verifica que el grupo HPAdvanced y las opciones HPDensity y HPDryTime existan."""
        self.assertIn("*OpenGroup: HPAdvanced/Ajustes Avanzados", self.ppd_text)
        self.assertIn("*CloseGroup: HPAdvanced", self.ppd_text)

        # HPDensity
        self.assertIn("*OpenUI *HPDensity/Densidad de Tinta: PickOne", self.ppd_text)
        self.assertIn("*HPDensity Economy/", self.ppd_text)
        self.assertIn("*HPDensity Light/", self.ppd_text)
        self.assertIn("*HPDensity Normal/", self.ppd_text)
        self.assertIn("*HPDensity High/", self.ppd_text)
        self.assertIn("*HPDensity VeryHigh/", self.ppd_text)
        self.assertIn("*HPDensity MaxTransfer/", self.ppd_text)

        # HPDryTime
        self.assertIn("*OpenUI *HPDryTime/Tiempo de Secado: PickOne", self.ppd_text)
        self.assertIn("*HPDryTime None/", self.ppd_text)
        self.assertIn("*HPDryTime Short/", self.ppd_text)
        self.assertIn("*HPDryTime Medium/", self.ppd_text)
        self.assertIn("*HPDryTime Long/", self.ppd_text)
        self.assertIn("*HPDryTime Maximum/", self.ppd_text)

    def test_cupstestppd_conformance(self):
        """Valida que cupstestppd acepte la sintaxis del PPD; no implica validación física."""
        res = subprocess.run(["cupstestppd", "-W", "all", str(PPD_PATH)], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"cupstestppd falló: {res.stderr}\n{res.stdout}")
        self.assertTrue("PASA" in res.stdout or "PASS" in res.stdout)


class TestRasterFilterAdvancedControls(unittest.TestCase):
    """Verifica que rastertopcl3gui procese HPDensity y emita el PML de HPDryTime."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"El binario del filtro debe existir en {FILTER_PATH}")

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_pml_dry_time_injection(self):
        """Verifica que HPDryTime=Short (5 seg) inyecte la secuencia PML ExtraDryTime."""
        cmd = [str(FILTER_PATH), "1", "user", "title", "1", "HPDryTime=Short", str(SAMPLE_RASTER)]
        res = subprocess.run(cmd, capture_output=True, check=True)
        pcl_output = res.stdout
        stderr_text = res.stderr.decode("utf-8", errors="ignore")

        # Secuencia PML esperada para 5 segundos (0x05)
        # \x1b&b16WPML \x04\x00\x06\x01\x04\x01\x04\x01\x06\x08\x01\x05
        pml_expected = b"\x1b&b16WPML \x04\x00\x06\x01\x04\x01\x04\x01\x06\x08\x01\x05"
        self.assertIn(pml_expected, pcl_output, "La secuencia binaria PML de secado no fue encontrada en el flujo PCL3GUI")
        self.assertIn("Tiempo de secado PML activo: 5 seg", stderr_text)

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_density_lut_option(self):
        """Verifica que HPDensity=High aplique la escala 1.10x."""
        cmd = [str(FILTER_PATH), "1", "user", "title", "1", "HPDensity=High", str(SAMPLE_RASTER)]
        res = subprocess.run(cmd, capture_output=True, check=True)
        stderr_text = res.stderr.decode("utf-8", errors="ignore")
        self.assertIn("Densidad: 1.10x", stderr_text)


class TestHardwareToolCommands(unittest.TestCase):
    """Verifica los comandos CLI dump-tree e inject-raw de hp-smart-tank-tool."""

    def setUp(self):
        self.assertTrue(TOOL_PATH.exists(), f"El binario de la herramienta debe existir en {TOOL_PATH}")

    def test_dump_tree_mock(self):
        """Verifica que dump-tree --mock devuelva los árboles XML requeridos."""
        cmd = [str(TOOL_PATH), "dump-tree", "--mock"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        stdout = res.stdout
        self.assertIn("DiscoveryTree", stdout)
        self.assertIn("ProductConfigDyn", stdout)
        self.assertIn("HP Smart Tank 500 series", stdout)
        self.assertIn("MediaCapabilities", stdout)
        self.assertIn("IOConfig", stdout)

    def test_inject_raw_mock(self):
        """Verifica que inject-raw --mock transfiera el archivo binario simulado."""
        dummy_file = "/tmp/test_unit_injection.bin"
        Path(dummy_file).write_bytes(b"\x1b%-12345X@PJL INFO ID\r\n\x1b%-12345X\r\n")
        cmd = [str(TOOL_PATH), "inject-raw", dummy_file, "--mock"]
        res = subprocess.run(cmd, capture_output=True, text=True, check=True)
        stdout = res.stdout
        self.assertIn("INYECCIÓN RAW DIRECTA A HARDWARE", stdout)
        self.assertIn("EP 0x02 Bulk OUT", stdout)
        self.assertIn("Inyección RAW completada exitosamente", stdout)


if __name__ == "__main__":
    unittest.main()
