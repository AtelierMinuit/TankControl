#!/usr/bin/env python3
"""Tests unitarios para el Gemelo Digital / Emulador de Hardware."""

from __future__ import annotations

from http.server import HTTPServer
import socket
import threading
import time
import os
import sys
import unittest
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from tools.virtual_smart_tank import VirtualEWSHandler, process_print_job, STATE
import tools.pcl3gui_encode as enc


class VirtualSmartTankTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.ews_port = 8991
        cls.server = HTTPServer(("127.0.0.1", cls.ews_port), VirtualEWSHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()

    def test_ews_product_status(self) -> None:
        url = f"http://127.0.0.1:{self.ews_port}/DevMgmt/ProductStatusDyn.xml"
        with urllib.request.urlopen(url) as resp:
            self.assertEqual(resp.status, 200)
            body = resp.read().decode("utf-8")
            self.assertIn("<psdyn:StatusCategory>ready</psdyn:StatusCategory>", body)

    def test_ews_consumables(self) -> None:
        url = f"http://127.0.0.1:{self.ews_port}/DevMgmt/ConsumableConfigDyn.xml"
        with urllib.request.urlopen(url) as resp:
            self.assertEqual(resp.status, 200)
            body = resp.read().decode("utf-8")
            self.assertIn("<ccdyn:ConsumableLabelCode>K</ccdyn:ConsumableLabelCode>", body)
            self.assertIn("<ccdyn:ConsumableLabelCode>C</ccdyn:ConsumableLabelCode>", body)

    def test_ews_maintenance_cleaning(self) -> None:
        initial_cycles = STATE.cleaning_cycles
        url = f"http://127.0.0.1:{self.ews_port}/DevMgmt/InternalPrintDyn.xml"
        req = urllib.request.Request(url, data=b"<ipdyn:JobType>cleaningPage</ipdyn:JobType>", method="POST")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(STATE.cleaning_cycles, initial_cycles + 1)

    def test_virtual_engine_print_job_processing(self) -> None:
        # Generar un trabajo mínimo con el codificador
        width, height = 200, 50
        rows = [bytes([255] * (width * 3))] * height
        row20 = bytearray([255] * (width * 3))
        for x in range(20, 50):
            row20[x * 3] = 0
            row20[x * 3 + 1] = 0
            row20[x * 3 + 2] = 0
        rows[20] = bytes(row20)

        pcl_stream = enc.encode_page(rows, width, height, dpi=600, media="a4")
        res = process_print_job(pcl_stream, 999)

        self.assertTrue(res["ok"])
        self.assertEqual(res["ending_y"], 21)
        self.assertIn("ppm_path", res)

    def test_ews_rejects_malformed_content_length(self) -> None:
        url = f"http://127.0.0.1:{self.ews_port}/DevMgmt/InternalPrintDyn.xml"
        for value in ("invalid", "-1", str(VirtualEWSHandler.MAX_BODY + 1)):
            req = urllib.request.Request(
                url,
                data=b"x",
                headers={"Content-Length": value},
                method="POST",
            )
            with self.assertRaises(urllib.error.HTTPError) as ctx:
                urllib.request.urlopen(req)
            self.assertIn(ctx.exception.code, (400, 411, 413))


if __name__ == "__main__":
    unittest.main()
