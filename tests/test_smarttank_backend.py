#!/usr/bin/env python3
"""
Test Suite: Native CUPS Backend (smarttank://)
Verifica:
1. Existencia y arquitectura Mach-O ARM64 del binario compilado.
2. Descubrimiento CUPS (modo discovery con 0 argumentos).
3. Formato de URI de dispositivo compatible con el estándar CUPS.
4. Procesamiento de trabajos de impresión simulados con emisión de directivas STATE y PAGE.
"""

import unittest
import os
import subprocess

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIT_BUILD = os.environ.get("HP_AUDIT_BUILD_DIR", os.path.join(BASE_DIR, "research", "builds", "audit-clean", "night-20260904"))
BACKEND_PATH = os.path.join(AUDIT_BUILD, "smarttank")

class TestSmartTankBackend(unittest.TestCase):
    def setUp(self):
        self.assertTrue(os.path.exists(BACKEND_PATH), f"No se encontró el binario: {BACKEND_PATH}")

    def test_01_binary_architecture(self):
        res = subprocess.run(["file", BACKEND_PATH], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Mach-O 64-bit", res.stdout)
        self.assertIn("arm64", res.stdout)

    def test_02_discovery_mode_mock(self):
        env = os.environ.copy()
        env["HP_SMART_TANK_MOCK"] = "1"
        res = subprocess.run([BACKEND_PATH], env=env, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        lines = res.stdout.strip().splitlines()
        self.assertGreater(len(lines), 0, "El backend no emitió salida en modo descubrimiento")
        
        # Validar sintaxis CUPS backend:
        # direct device-uri "make and model" "info" "device-id" "location"
        line = lines[0]
        self.assertTrue(line.startswith("direct smarttank://"))
        self.assertIn("HP Smart Tank 500 series", line)
        self.assertIn("CMD:PCL3GUI,LEDM;", line)

    def test_03_print_job_mock_execution(self):
        env = os.environ.copy()
        env["HP_SMART_TANK_MOCK"] = "1"
        
        # Simular flujo PCL3GUI con 2 páginas (0x0C = form feed / page eject)
        mock_stream = b"\x1b*r1A" + (b"\x00" * 100) + b"\x0c" + b"\x1b*r1A" + (b"\x00" * 100) + b"\x0c"
        
        cmd = [BACKEND_PATH, "42", "tester", "DocPrueba", "1", "MediaType=Plain"]
        res = subprocess.run(cmd, input=mock_stream, env=env, capture_output=True)
        
        self.assertEqual(res.returncode, 0)
        stderr_output = res.stderr.decode("utf-8", errors="replace")
        
        # Verificar emisión de directivas CUPS
        self.assertIn("DEBUG: [smarttank] Iniciando trabajo #42", stderr_output)
        self.assertIn("STATE: -media-empty-error,media-jam-error,door-open-error", stderr_output)
        self.assertIn("PAGE: 1 1", stderr_output)
        self.assertIn("INFO: [smarttank] Trabajo #42 simulado exitosamente", stderr_output)

    def test_04_print_job_with_mock_device_uri(self):
        env = os.environ.copy()
        env.pop("HP_SMART_TANK_MOCK", None)
        env["DEVICE_URI"] = "smarttank://HP/Smart%20Tank%20500%20series?mock=1"
        
        mock_stream = b"\x1b*r1A\x0c"
        cmd = [BACKEND_PATH, "99", "admin", "Photo", "1", ""]
        res = subprocess.run(cmd, input=mock_stream, env=env, capture_output=True)
        
        self.assertEqual(res.returncode, 0)
        stderr_output = res.stderr.decode("utf-8", errors="replace")
        self.assertIn("PAGE: 1 1", stderr_output)
        self.assertIn("Trabajo #99 simulado exitosamente", stderr_output)

if __name__ == "__main__":
    unittest.main()
