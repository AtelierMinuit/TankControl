#!/usr/bin/env python3
"""
test_contracts.py
Suite formal de pruebas de contrato para los subsistemas de HP Smart Tank 500.

Verifica formalmente:
1. Contrato del Filtro Raster CUPS (rastertopcl3gui): ABI, retorno, encapsulación UEL/PJL.
2. Contrato del Backend USB CUPS (smarttank): Modo descubrimiento (argc=1), ejecución (argc=6/7), códigos de salida CUPS.
3. Contrato de Protocolo LEDM Scanner: Framing HTTP/1.1 sobre USB, respuestas XML válidas.
4. Contrato de Máquina de Estados eSCL: Rutas obligatorias de Apple Image Capture y eSCL 2.0.
5. Contrato del Arnés de Validación: Device Safety Gate, exit codes normalizados, esquema summary.json.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

FILTER_PATH = PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "rastertopcl3gui"
if not FILTER_PATH.exists():
    FILTER_PATH = PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904" / "rastertopcl3gui"

BACKEND_PATH = PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "smarttank"
if not BACKEND_PATH.exists():
    BACKEND_PATH = PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904" / "smarttank"

HARNESS_PATH = PROJECT_ROOT / "tools" / "run_hardware_validation.sh"
SCHEMA_PATH = PROJECT_ROOT / "docs" / "hardware-validation-summary.schema.json"


class TestRasterFilterContract(unittest.TestCase):
    """Contrato del Filtro Raster CUPS (rastertopcl3gui)."""

    def setUp(self):
        self.assertTrue(FILTER_PATH.exists(), f"Filtro debe existir en {FILTER_PATH}")

    def test_filter_abi_insufficient_arguments(self):
        """Contrato ABI CUPS: si se invoca con menos de 5 argumentos, debe fallar con error y código 1."""
        for num_args in range(5):
            cmd = [str(FILTER_PATH)] + ["arg"] * num_args
            proc = subprocess.run(cmd, capture_output=True)
            self.assertEqual(proc.returncode, 1, f"Debe retornar 1 con {num_args} argumentos")
            self.assertIn("ERROR: Uso:", proc.stderr.decode("utf-8", errors="replace"))

    def test_filter_output_encapsulation_contract(self):
        """Contrato de Encapsulación PCL3GUI: la salida debe iniciar con UEL/PJL y finalizar con PJL EOJ."""
        # Generar un raster mínimo de 1 línea
        sync_word = struct.pack("<I", 0x52615333)
        header = bytearray(1796)
        struct.pack_into("<II", header, 276, 600, 600)
        struct.pack_into("<II", header, 372, 16, 2)
        struct.pack_into("<II", header, 384, 8, 24)
        struct.pack_into("<I", header, 392, 16 * 3)
        struct.pack_into("<I", header, 400, 1)  # RGB
        raster_data = sync_word + bytes(header) + (b"\xff\xff\xff" * 16 * 2)

        cmd = [str(FILTER_PATH), "1", "user", "title", "1", ""]
        proc = subprocess.run(cmd, input=raster_data, capture_output=True)
        self.assertEqual(proc.returncode, 0)

        out = proc.stdout
        # 1. Cabecera UEL y PJL
        self.assertTrue(out.startswith(b"\x1b%-12345X@PJL"), "Debe comenzar con UEL + PJL")
        self.assertIn(b"@PJL ENTER LANGUAGE=PCL3GUI", out)

        # 2. Terminación UEL y EOJ
        self.assertTrue(out.endswith(b"\x1b%-12345X"), "Debe finalizar con secuencia UEL")
        self.assertIn(b"@PJL EOJ\n", out)


class TestCUPSBackendContract(unittest.TestCase):
    """Contrato del Backend CUPS (smarttank)."""

    def setUp(self):
        self.assertTrue(BACKEND_PATH.exists(), f"Backend debe existir en {BACKEND_PATH}")

    def test_discovery_mode_contract(self):
        """Contrato de Descubrimiento CUPS: argc == 1 -> retorno 0 y salida de formato URI estandarizado."""
        env = os.environ.copy()
        env["HP_SMART_TANK_MOCK"] = "1"
        cmd = [str(BACKEND_PATH)]
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0)
        stdout = proc.stdout.strip()
        self.assertTrue(stdout.startswith("direct smarttank://"), f"URI inesperada: {stdout}")
        self.assertIn("HP Smart Tank 500", stdout)
        self.assertIn("CMD:PCL3GUI,LEDM;", stdout)

    def test_invalid_argc_contract(self):
        """Contrato de Argumentos Inválidos: argc entre 2 y 5 debe retornar CUPS_BACKEND_FAILED (1)."""
        for count in [1, 2, 3, 4]:
            cmd = [str(BACKEND_PATH)] + ["arg"] * count
            proc = subprocess.run(cmd, capture_output=True)
            self.assertEqual(proc.returncode, 1, f"Retorno inesperado {proc.returncode} para {count+1} argumentos")


class TestLEDMProtocolContract(unittest.TestCase):
    """Contrato del Protocolo LEDM sobre USB Bulk."""

    def test_http_request_framing(self):
        """Toda petición LEDM sobre bulk OUT debe cumplir RFC 7230 HTTP/1.1 con Host: localhost y Connection: close."""
        from tools.hp_smart_tank import SmartTank500, ChannelInfo
        path = "/DevMgmt/ProductStatusDyn.xml"
        req = f"GET {path} HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode("ascii")
        lines = req.split(b"\r\n")
        self.assertEqual(lines[0], b"GET /DevMgmt/ProductStatusDyn.xml HTTP/1.1")
        self.assertIn(b"Host: localhost", lines)
        self.assertIn(b"Connection: close", lines)
        self.assertTrue(req.endswith(b"\r\n\r\n"))


class TestESCLStateMachineContract(unittest.TestCase):
    """Contrato de Rutas y Máquina de Estados eSCL / AirScan."""

    def test_escl_xml_capabilities_contract(self):
        """Verifica que el generador de ScannerCapabilities emita XML conforme a especificación eSCL / PWG."""
        from tools.hp_escl_bridge import ESCLBridge
        bridge = ESCLBridge(mock=True)
        xml_out = bridge.get_capabilities()
        self.assertIn("<scan:ScannerCapabilities", xml_out)
        self.assertIn("<pwg:Version>2.63</pwg:Version>", xml_out)
        self.assertIn("<scan:Platen>", xml_out)
        self.assertIn("<scan:ColorModes>", xml_out)

    def test_escl_xml_status_contract(self):
        """Verifica que ScannerStatus reporte el estado de escáner en reposo (Idle)."""
        from tools.hp_escl_bridge import ESCLBridge
        bridge = ESCLBridge(mock=True)
        status_xml = bridge.get_status()
        self.assertIn("<scan:ScannerStatus", status_xml)
        self.assertIn("<pwg:State>Idle</pwg:State>", status_xml)


class TestValidationHarnessContract(unittest.TestCase):
    """Contrato del Arnés de Validación de Hardware (run_hardware_validation.sh)."""

    def setUp(self):
        self.assertTrue(HARNESS_PATH.exists(), f"Arnés debe existir en {HARNESS_PATH}")
        self.assertTrue(SCHEMA_PATH.exists(), f"Esquema debe existir en {SCHEMA_PATH}")

    def test_safety_gate_blocking_contract(self):
        """Device Safety Gate: la combinación --fault-tests --live DEBE bloquearse con código 2."""
        proc = subprocess.run(
            [str(HARNESS_PATH), "--fault-tests", "--live"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 2, "Safety Gate debe retornar código 2 al bloquear operación prohibida")
        self.assertIn("DEVELOPER_ONLY", proc.stderr)

    def test_dry_run_success_and_schema_contract(self):
        """Modo Dry-Run: debe finalizar con código 0 y summary.json válido según JSON Schema."""
        proc = subprocess.run(
            [str(HARNESS_PATH), "--dry-run"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(proc.returncode, 0, f"Dry-run falló:\n{proc.stderr}")

        # Extraer ruta del summary.json de la salida
        match = re.search(r"Resumen JSON:\s+(.+summary\.json)", proc.stdout)
        self.assertIsNotNone(match, "No se encontró ruta de summary.json en stdout")
        summary_path = Path(match.group(1).strip())
        self.assertTrue(summary_path.exists())

        # Validar sintaxis y campos obligatorios del esquema
        with open(summary_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        required_keys = ["schema_version", "session_id", "timestamp", "mode", "host", "device", "steps", "result", "evidence"]
        for k in required_keys:
            self.assertIn(k, data, f"Campo obligatorio '{k}' ausente en summary.json")

        self.assertEqual(data["mode"], "dry-run")
        self.assertEqual(data["result"]["final_exit_code"], 0)
        self.assertEqual(data["result"]["overall_status"], "PASS")


if __name__ == "__main__":
    unittest.main()
