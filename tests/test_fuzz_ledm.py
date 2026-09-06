#!/usr/bin/env python3
"""
Fuzzing de Protocolo LEDM / eSCL para el puente AirScan de HP Smart Tank 500.
Verifica que cargas XML malformadas, coordenadas anómalas y payloads no estándar
no causen excepciones no controladas ni bloqueos de concurrencia.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
BRIDGE_PATH = PROJECT_ROOT / "tools" / "hp_escl_bridge.py"

SPEC = importlib.util.spec_from_file_location("hp_escl_bridge", BRIDGE_PATH)
BRIDGE_MOD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BRIDGE_MOD)


class FuzzLEDMTests(unittest.TestCase):
    def setUp(self) -> None:
        self.bridge = BRIDGE_MOD.ESCLBridge(port=9999, mock=True)

    def test_fuzz_malformed_xml_payloads(self) -> None:
        """Prueba una variedad de XMLs rotos o malformados."""
        bad_payloads = [
            b"",
            b"not xml at all",
            b"<xml><unclosed>",
            b"<?xml version='1.0'?><scan:ScanSettings xmlns:scan='http://schemas.hp.com/imaging/escl/2011/05/03'><XResolution>abc</XResolution></scan:ScanSettings>",
            b"\x00\xff\xfe\x00<ScanSettings>",
            b"<!DOCTYPE foo [<!ENTITY xx 'xxxx'>]><foo>&xx;&xx;</foo>",
            b"<ScanSettings><XResolution>-600</XResolution><Width>-100</Width></ScanSettings>",
            b"<ScanSettings><XOffset>99999999</XOffset><YOffset>99999999</YOffset></ScanSettings>",
            b"<ScanSettings><ColorMode>SuperWeirdMode32</ColorMode></ScanSettings>",
        ]

        for payload in bad_payloads:
            job_url = self.bridge.create_scan_job(payload)
            self.assertIn("/eSCL/ScanJobs/job-", job_url, f"Fallo al procesar {payload!r}")
            # El trabajo debe haberse registrado con coordenadas seguras
            job_id = job_url.split("/")[-1]
            job = self.bridge.jobs[job_id]
            x, y, w, h = job["region"]
            self.assertGreaterEqual(x, 0)
            self.assertGreaterEqual(y, 0)
            self.assertGreater(w, 0)
            self.assertGreater(h, 0)
            self.assertLessEqual(x + w, int(8.5 * job["res"]) + 1)
            self.assertLessEqual(y + h, int(11.69 * job["res"]) + 1)

    def test_fuzz_extreme_resolutions(self) -> None:
        """Resoluciones anómalas deben mapearse graciosamente sin división por cero."""
        for res in [-100, 0, 1, 10000]:
            xml = f"<ScanSettings><XResolution>{res}</XResolution></ScanSettings>".encode()
            job_url = self.bridge.create_scan_job(xml)
            job_id = job_url.split("/")[-1]
            job = self.bridge.jobs[job_id]
            self.assertIn(job["state"], ("Processing", "Completed"))


if __name__ == "__main__":
    unittest.main()
