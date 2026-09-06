#!/usr/bin/env python3
"""Pruebas de simulación offline para el backend CUPS nativo smarttank."""

from __future__ import annotations

import os
from pathlib import Path
import subprocess
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
BACKEND_BIN = PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "smarttank"


class CupsBackendSimulationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not BACKEND_BIN.is_file():
            raise unittest.SkipTest(f"Binario {BACKEND_BIN} no compilado")

    def test_discovery_mode_emits_device_uri(self) -> None:
        """Sin argumentos (argc==1), CUPS invoca el backend para descubrimiento."""
        env = {**os.environ, "HP_SMART_TANK_MOCK": "1"}
        result = subprocess.run([str(BACKEND_BIN)], env=env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertIn("smarttank://HP/Smart%20Tank%20500%20series", result.stdout)
        self.assertIn("CMD:PCL3GUI,LEDM", result.stdout)

    def test_invalid_argument_count_returns_failed(self) -> None:
        """CUPS backend con argumentos incompletos debe devolver CUPS_BACKEND_FAILED (1)."""
        result = subprocess.run([str(BACKEND_BIN), "1", "user"], capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)  # CUPS_BACKEND_FAILED
        self.assertIn("Uso:", result.stderr)

    def test_invalid_copies_count_returns_failed(self) -> None:
        """Cantidad de copias inválida o no numérica debe ser rechazada."""
        result = subprocess.run(
            [str(BACKEND_BIN), "1", "user", "title", "abc", "options"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("cantidad de copias inválida", result.stderr)

    def test_mock_print_job_processes_pages_and_accounting(self) -> None:
        """En modo mock, procesa el flujo, cuenta páginas 0x0C y genera contabilidad."""
        with tempfile.TemporaryDirectory() as td:
            spool_file = Path(td) / "job.pcl"
            # 3 páginas separadas por form-feed (0x0C)
            spool_file.write_bytes(b"PCL_PAGE_1\x0c" + b"PCL_PAGE_2\x0c" + b"PCL_PAGE_3\x0c")

            env = {**os.environ, "HP_SMART_TANK_MOCK": "1"}
            result = subprocess.run(
                [str(BACKEND_BIN), "105", "testuser", "SimulatedDoc.pdf", "1", "HPInkSaver=Eco50", str(spool_file)],
                env=env,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0)
            self.assertIn("PAGE: 1 1", result.stderr)
            self.assertIn("PAGE: 2 2", result.stderr)
            self.assertIn("PAGE: 3 3", result.stderr)
            self.assertIn("Trabajo #105 simulado exitosamente", result.stderr)
            self.assertIn("Contabilidad", result.stderr)

    def test_unreadable_file_returns_failed(self) -> None:
        """Archivo de entrada inexistente debe devolver CUPS_BACKEND_FAILED (1)."""
        env = {**os.environ, "HP_SMART_TANK_MOCK": "1"}
        result = subprocess.run(
            [str(BACKEND_BIN), "106", "user", "title", "1", "", "/tmp/nonexistent_spool_123456.pcl"],
            env=env,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 1)
        self.assertIn("No se pudo abrir de forma segura", result.stderr)


if __name__ == "__main__":
    unittest.main()
