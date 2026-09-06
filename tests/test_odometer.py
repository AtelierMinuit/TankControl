#!/usr/bin/env python3
"""
Test Suite: Hardware Odometer & Advanced Maintenance
Verifica:
1. Comando CLI 'odometer' formateado para terminal humana.
2. Comando CLI 'json-odometer' con esquema JSON estructurado para SwiftUI/APIs.
3. Endpoint XML /DevMgmt/ProductUsageDyn.xml en el servidor virtual EWS.
4. Ejecución de comandos de mantenimiento Nivel 3 (clean-rollers) y verificación (nozzle-test).
"""

import unittest
import os
import subprocess
import json
import urllib.request
import threading
from http.server import HTTPServer

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIT_BUILD = os.environ.get("HP_AUDIT_BUILD_DIR", os.path.join(BASE_DIR, "research", "builds", "audit-clean", "night-20260904"))
TOOL_PATH = os.path.join(AUDIT_BUILD, "hp-smart-tank-tool")

import sys
sys.path.insert(0, os.path.join(BASE_DIR, "tools"))
from virtual_smart_tank import VirtualEWSHandler

class TestOdometerAndMaintenance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Iniciar servidor virtual EWS en puerto efímero
        cls.server = HTTPServer(("127.0.0.1", 0), VirtualEWSHandler)
        cls.port = cls.server.server_address[1]
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()

    def test_01_cli_odometer_human_readable(self):
        res = subprocess.run([TOOL_PATH, "odometer", "--mock"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        out = res.stdout
        self.assertIn("ODÓMETRO", out)
        self.assertIn("TELEMETRÍA DE HARDWARE", out)
        self.assertIn("Páginas Totales", out)
        self.assertIn("Monocromáticas", out)
        self.assertIn("Color", out)
        self.assertIn("Sin Bordes", out)
        self.assertIn("Escáner", out)
        self.assertIn("Atascos de Papel", out)
        self.assertIn("Disparos de Inyectores", out)

    def test_02_cli_odometer_json(self):
        res = subprocess.run([TOOL_PATH, "json-odometer", "--mock"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        data = json.loads(res.stdout)
        
        self.assertTrue(data.get("connected"))
        self.assertTrue(data.get("mock"))
        self.assertIsInstance(data.get("total_pages"), int)
        self.assertGreater(data["total_pages"], 0)
        self.assertEqual(data["mono_pages"] + data["color_pages"], data["total_pages"])
        self.assertGreaterEqual(data.get("borderless_pages", 0), 0)
        self.assertGreaterEqual(data.get("scans", 0), 0)
        self.assertGreaterEqual(data.get("jams", 0), 0)
        
        # Validar consumo de gotas por canal de color
        drops = data.get("drops", {})
        self.assertIn("k", drops)
        self.assertIn("c", drops)
        self.assertIn("m", drops)
        self.assertIn("y", drops)
        self.assertGreater(drops["k"], 0)

    def test_03_virtual_ews_product_usage_dyn(self):
        url = f"http://127.0.0.1:{self.port}/DevMgmt/ProductUsageDyn.xml"
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=5) as resp:
            self.assertEqual(resp.status, 200)
            xml_data = resp.read().decode("utf-8")
            self.assertIn("<pudyn:ProductUsageDyn", xml_data)
            self.assertIn("<pudyn:PrintUsage>", xml_data)
            self.assertIn("<pudyn:TotalImpressions>", xml_data)
            self.assertIn("<pudyn:MonochromeImpressions>", xml_data)
            self.assertIn("<pudyn:ColorImpressions>", xml_data)
            self.assertIn("<pudyn:BorderlessImpressions>", xml_data)
            self.assertIn("<pudyn:JamEvents>", xml_data)
            self.assertIn("<pudyn:FlatbedScans>", xml_data)
            self.assertIn("<pudyn:TotalDropsFiredK>", xml_data)

    def test_04_level3_clean_rollers_command(self):
        res = subprocess.run([TOOL_PATH, "clean-rollers", "--mock"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("Nivel 3", res.stdout)
        self.assertIn("rodillos", res.stdout.lower())

    def test_05_nozzle_verification_command(self):
        res = subprocess.run([TOOL_PATH, "nozzle-test", "--mock"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("verificacion", res.stdout.lower())

if __name__ == "__main__":
    unittest.main()
