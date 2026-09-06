#!/usr/bin/env python3
"""
Test Suite: Harness de Validación de Hardware HP Smart Tank 500
================================================================
Verifica el comportamiento, seguridad, modelos de evidencia y códigos de salida
del script tools/run_hardware_validation.sh en entorno 100% offline.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
HARNESS_BIN = REPO_ROOT / "tools" / "run_hardware_validation.sh"
SMOKE_GEN = REPO_ROOT / "tools" / "generate_smoke_test_page.py"


class TestHardwareValidationHarness(unittest.TestCase):
    def setUp(self):
        self.assertTrue(HARNESS_BIN.exists(), f"Harness no encontrado en {HARNESS_BIN}")
        self.assertTrue(os.access(HARNESS_BIN, os.X_OK), "Harness debe ser ejecutable")
        self.temp_dir = tempfile.TemporaryDirectory()
        self.session_dir = Path(self.temp_dir.name) / "test-session"

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_harness_help(self):
        """Verifica que --help retorne 0 y documente todos los modos y opciones."""
        res = subprocess.run(
            [str(HARNESS_BIN), "--help"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 0)
        self.assertIn("Uso:", res.stdout)
        self.assertIn("--dry-run", res.stdout)
        self.assertIn("--probe", res.stdout)
        self.assertIn("--telemetry", res.stdout)
        self.assertIn("--print", res.stdout)
        self.assertIn("--scan", res.stdout)
        self.assertIn("--fault-tests", res.stdout)
        self.assertIn("--mock", res.stdout)

    def test_harness_invalid_option(self):
        """Verifica que una opción desconocida aborte con código 2 (error sintaxis CLI)."""
        res = subprocess.run(
            [str(HARNESS_BIN), "--unsupported-option"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 2)
        self.assertIn("Opción desconocida", res.stderr)

    def test_generate_smoke_test_page(self):
        """Verifica que el generador de la página de prueba produzca un PDF válido."""
        out_pdf = Path(self.temp_dir.name) / "smoke-test-sample.pdf"
        res = subprocess.run(
            [
                "python3",
                str(SMOKE_GEN),
                "--output",
                str(out_pdf),
                "--session-id",
                "TEST-UNIT-01",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 0, f"Error generando smoke test: {res.stderr}")
        self.assertTrue(out_pdf.exists())
        self.assertGreater(out_pdf.stat().st_size, 20000)
        with open(out_pdf, "rb") as f:
            header = f.read(5)
            self.assertEqual(header, b"%PDF-")

    def test_harness_dry_run_execution(self):
        """Verifica la ejecución completa de --dry-run con generación de evidencias y sin telemetría falsa."""
        res = subprocess.run(
            [
                str(HARNESS_BIN),
                "--dry-run",
                "--session-dir",
                str(self.session_dir),
                "--assume-yes",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(
            res.returncode, 0, f"Harness dry-run falló (rc={res.returncode}):\n{res.stdout}\n{res.stderr}"
        )

        # Verificar artefactos estructurados de la sesión
        manifest_file = self.session_dir / "manifest.txt"
        summary_json = self.session_dir / "summary.json"
        summary_md = self.session_dir / "summary.md"
        usb_txt = self.session_dir / "usb.txt"
        cups_txt = self.session_dir / "cups.txt"
        env_txt = self.session_dir / "environment.txt"

        self.assertTrue(manifest_file.exists(), "manifest.txt ausente")
        self.assertTrue(summary_json.exists(), "summary.json ausente")
        self.assertTrue(summary_md.exists(), "summary.md ausente")
        self.assertTrue(usb_txt.exists(), "usb.txt ausente")
        self.assertTrue(cups_txt.exists(), "cups.txt ausente")
        self.assertTrue(env_txt.exists(), "environment.txt ausente")

        # Validar contenido y esquema de summary.json
        with open(summary_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data["schema_version"], "1.0.0")
        self.assertEqual(data["mode"], "dry-run")
        self.assertEqual(data["device"]["vid"], "0x03f0")
        self.assertEqual(data["device"]["pid"], "0x2b54")
        self.assertEqual(data["result"]["overall_status"], "PASS")
        self.assertEqual(data["result"]["final_exit_code"], 0)
        self.assertEqual(data["result"]["step_count"], 7)
        self.assertEqual(data["result"]["fail_count"], 0)
        self.assertEqual(data["result"]["blocked_count"], 0)
        self.assertIn("manifest_file", data["evidence"])

        # Comprobar que todos los pasos se marcaron como DRY-RUN
        for step in data["steps"]:
            self.assertEqual(
                step["status"],
                "DRY-RUN",
                f"El paso {step['key']} tiene estado {step['status']}",
            )
            self.assertEqual(step["exit_code"], 0)
            self.assertIn("duration_ms", step)
            self.assertIn("evidence_files", step)
            self.assertEqual(
                step["status"],
                "DRY-RUN",
                f"El paso {step['key']} tiene estado {step['status']}",
            )
            self.assertEqual(step["exit_code"], 0)

        # Comprobar que no hay telemetría falsa en dry-run
        telemetry_log = self.session_dir / "logs" / "05_telemetry.log"
        self.assertTrue(telemetry_log.exists())
        content = telemetry_log.read_text(encoding="utf-8")
        self.assertIn("NO HARDWARE DATA COLLECTED", content)
        self.assertIn("WOULD RUN:", content)

        # Comprobar artefactos del pipeline de impresión
        print_pdf = self.session_dir / "print" / "hardware-smoke-test.pdf"
        print_raster = self.session_dir / "print" / "smoke-test.raster"
        print_pcl = self.session_dir / "print" / "smoke-test.pcl"
        stream_manifest = self.session_dir / "print" / "stream-manifest.txt"

        self.assertTrue(print_pdf.exists())
        self.assertTrue(print_raster.exists())
        self.assertTrue(print_pcl.exists())
        self.assertTrue(stream_manifest.exists())
        self.assertGreater(print_pcl.stat().st_size, 1000)

    def test_harness_mock_execution(self):
        """Verifica la ejecución en modo --mock contra el gemelo digital."""
        res = subprocess.run(
            [
                str(HARNESS_BIN),
                "--mock",
                "--session-dir",
                str(self.session_dir),
                "--assume-yes",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 0, f"Harness mock falló:\n{res.stdout}\n{res.stderr}")

        summary_json = self.session_dir / "summary.json"
        with open(summary_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data["result"]["overall_status"], "PASS")
        self.assertEqual(data["result"]["final_exit_code"], 0)
        self.assertEqual(data["mode"], "mock")

        for step in data["steps"]:
            self.assertEqual(step["status"], "MOCK")

    def test_harness_probe_blocked_without_hardware(self):
        """Verifica que el modo --probe detecte la ausencia de hardware y retorne código 2 (BLOCKED)."""
        res = subprocess.run(
            [
                str(HARNESS_BIN),
                "--probe",
                "--session-dir",
                str(self.session_dir),
                "--assume-yes",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        # Si hay hardware real conectado físicamente, retornará 0 (PASS); si no, 2 (BLOCKED).
        self.assertIn(res.returncode, (0, 2), f"Se esperaba código 0 (PASS con hardware) o 2 (BLOCKED sin hardware), se obtuvo {res.returncode}")

        summary_json = self.session_dir / "summary.json"
        with open(summary_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        usb_step = next(s for s in data["steps"] if s["key"] == "03_usb_probe")
        if res.returncode == 2:
            self.assertEqual(data["result"]["overall_status"], "BLOCKED")
            self.assertEqual(data["result"]["final_exit_code"], 2)
            self.assertGreaterEqual(data["result"]["blocked_count"], 1)
            self.assertEqual(usb_step["status"], "BLOCKED")
            self.assertEqual(usb_step["exit_code"], 2)
        else:
            self.assertEqual(data["result"]["overall_status"], "PASS")
            self.assertEqual(data["result"]["final_exit_code"], 0)
            self.assertEqual(usb_step["status"], "PASS")
            self.assertEqual(usb_step["exit_code"], 0)

    def test_harness_fault_tests_execution(self):
        """Verifica que el modo --fault-tests ejecute las pruebas negativas en modo offline aislado."""
        res = subprocess.run(
            [
                str(HARNESS_BIN),
                "--fault-tests",
                "--session-dir",
                str(self.session_dir),
                "--assume-yes",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 0, f"Fault tests falló: {res.stdout}\n{res.stderr}")

        summary_json = self.session_dir / "summary.json"
        with open(summary_json, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(data["result"]["overall_status"], "PASS")
        self.assertEqual(data["result"]["final_exit_code"], 0)

        # El paso de pruebas negativas debe existir y haber aprobado
        fault_step = next(s for s in data["steps"] if s["key"] == "08_fault_tests")
        self.assertEqual(fault_step["status"], "PASS")
        self.assertEqual(fault_step["exit_code"], 0)

    def test_harness_fault_tests_live_rejection(self):
        """Verifica que el safety gate rechace terminantemente combinar --fault-tests con --live."""
        res = subprocess.run(
            [
                str(HARNESS_BIN),
                "--fault-tests",
                "--live",
                "--session-dir",
                str(self.session_dir),
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )
        self.assertEqual(res.returncode, 2)
        self.assertIn("DEVELOPER_ONLY", res.stderr)
        self.assertIn("Prohibido contra hardware real", res.stderr)


if __name__ == "__main__":
    unittest.main()
