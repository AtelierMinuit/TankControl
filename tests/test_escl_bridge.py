#!/usr/bin/env python3
"""Tests unitarios para el puente eSCL / AirScan."""

from __future__ import annotations

from http.server import HTTPServer
import socket
import threading
import time
import unittest
import urllib.request
import urllib.error
from concurrent.futures import ThreadPoolExecutor

from tools.hp_escl_bridge import ESCLBridge, ESCLBridgeHandler


class ESCLBridgeServerTests(unittest.TestCase):
    def test_cli_default_port_matches_launchagent(self) -> None:
        with open("tools/hp_escl_bridge.py", encoding="utf-8") as source_file:
            source = source_file.read()
        self.assertIn('default=8089', source)

    @classmethod
    def setUpClass(cls) -> None:
        cls.port = 8999
        cls.bridge = ESCLBridge(port=cls.port, mock=True)
        ESCLBridgeHandler.bridge = cls.bridge
        cls.server = HTTPServer(("127.0.0.1", cls.port), ESCLBridgeHandler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()
        time.sleep(0.1)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()

    def test_get_capabilities(self) -> None:
        url = f"http://127.0.0.1:{self.port}/eSCL/ScannerCapabilities"
        with urllib.request.urlopen(url) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers.get("Content-Type"), "text/xml")
            body = resp.read().decode("utf-8")
            self.assertIn("HP Smart Tank 500 series", body)
            self.assertIn("PlatenInputCaps", body)

    def test_get_status(self) -> None:
        url = f"http://127.0.0.1:{self.port}/eSCL/ScannerStatus"
        with urllib.request.urlopen(url) as resp:
            self.assertEqual(resp.status, 200)
            body = resp.read().decode("utf-8")
            self.assertIn("<pwg:State>Idle</pwg:State>", body)

    def test_post_scan_job(self) -> None:
        url = f"http://127.0.0.1:{self.port}/eSCL/ScanJobs"
        req = urllib.request.Request(url, data=b"<scan:ScanSettings/>", method="POST")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 201)
            loc = resp.headers.get("Location")
            self.assertIsNotNone(loc)
            self.assertRegex(loc or "", r"/eSCL/ScanJobs/job-[0-9]+$")

    def test_get_next_document_jpeg(self) -> None:
        job_url = self.bridge.create_scan_job(b"<ScanSettings/>")
        job_id = job_url.rstrip("/").split("/")[-1]
        url = f"http://127.0.0.1:{self.port}/eSCL/ScanJobs/{job_id}/NextDocument"
        with urllib.request.urlopen(url) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers.get("Content-Type"), "image/jpeg")
            data = resp.read()
            # Verify JPEG SOI and EOI markers
            self.assertTrue(data.startswith(b"\xFF\xD8"))
            self.assertTrue(data.endswith(b"\xFF\xD9"))

    def test_post_scan_job_with_regions_and_high_res(self) -> None:
        url = f"http://127.0.0.1:{self.port}/eSCL/ScanJobs"
        xml = (
            b'<?xml version="1.0" encoding="UTF-8"?>'
            b'<scan:ScanSettings xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03">'
            b'  <scan:Intent>Photo</scan:Intent>'
            b'  <scan:XResolution>600</scan:XResolution>'
            b'  <scan:YResolution>600</scan:YResolution>'
            b'  <scan:ColorMode>RGB24</scan:ColorMode>'
            b'  <scan:ScanRegions>'
            b'    <scan:ScanRegion>'
            b'      <scan:XOffset>150</scan:XOffset>'
            b'      <scan:YOffset>300</scan:YOffset>'
            b'      <scan:Width>600</scan:Width>'
            b'      <scan:Height>900</scan:Height>'
            b'    </scan:ScanRegion>'
            b'  </scan:ScanRegions>'
            b'</scan:ScanSettings>'
        )
        req = urllib.request.Request(url, data=xml, method="POST")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 201)
            loc = resp.headers.get("Location")
            self.assertIsNotNone(loc)
            # Verify job created in bridge with scaled region
            job_id = loc.split("/")[-1]
            self.assertIn(job_id, self.bridge.jobs)
            job = self.bridge.jobs[job_id]
            self.assertEqual(job["res"], 600)
            self.assertEqual(job["mode"], "color")
            # 600 DPI = 2.0 scale of 300 base
            self.assertEqual(job["region"], (300, 600, 1200, 1800))

    def test_concurrent_job_creation_has_unique_ids(self) -> None:
        def create_job(_: int) -> str:
            request = urllib.request.Request(
                f"http://127.0.0.1:{self.port}/eSCL/ScanJobs",
                data=b"<ScanSettings/>",
                method="POST",
            )
            for attempt in range(4):
                try:
                    with urllib.request.urlopen(request, timeout=10) as response:
                        return response.headers["Location"]
                except Exception:
                    if attempt == 3:
                        raise
                    time.sleep(0.05 * (attempt + 1))
            raise RuntimeError("No se pudo crear trabajo concurrente tras reintentos")

        with ThreadPoolExecutor(max_workers=8) as executor:
            locations = list(executor.map(create_job, range(24)))

        job_ids = [location.rstrip("/").split("/")[-1] for location in locations]
        self.assertEqual(len(job_ids), len(set(job_ids)))
        with self.bridge.jobs_lock:
            self.assertTrue(all(job_id in self.bridge.jobs for job_id in job_ids))

    def test_post_scan_job_accepts_fragmented_http_request(self) -> None:
        body = b"<ScanSettings/>"
        request = (
            b"POST /eSCL/ScanJobs HTTP/1.1\r\nHost: localhost\r\n"
            + f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n".encode()
            + body
        )
        with socket.create_connection(("127.0.0.1", self.port), timeout=3) as conn:
            for offset in range(0, len(request), 7):
                conn.sendall(request[offset : offset + 7])
                time.sleep(0.001)
            response = conn.recv(4096)
        self.assertIn(b"201", response.split(b"\r\n", 1)[0])

    def test_post_scan_job_rejects_chunked_transfer(self) -> None:
        request = (
            b"POST /eSCL/ScanJobs HTTP/1.1\r\nHost: localhost\r\n"
            b"Transfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
            b"f\r\n<ScanSettings/>\r\n0\r\n\r\n"
        )
        with socket.create_connection(("127.0.0.1", self.port), timeout=3) as conn:
            conn.sendall(request)
            response = conn.recv(4096)
        self.assertIn(b"411", response.split(b"\r\n", 1)[0])

    def test_delete_scan_job(self) -> None:
        job_url = self.bridge.create_scan_job(b"<ScanSettings/>")
        job_id = job_url.rstrip("/").split("/")[-1]
        self.assertIn(job_id, self.bridge.jobs)
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}/eSCL/ScanJobs/{job_id}", method="DELETE")
        with urllib.request.urlopen(req) as resp:
            self.assertEqual(resp.status, 200)
        self.assertNotIn(job_id, self.bridge.jobs)

    def test_unsupported_endpoint_returns_404(self) -> None:
        req = urllib.request.Request(f"http://127.0.0.1:{self.port}/eSCL/NonExistentEndpoint")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            urllib.request.urlopen(req)
        self.assertEqual(ctx.exception.code, 404)


class ESCLBridgeTruthfulnessTests(unittest.TestCase):
    def test_hardware_mode_returns_valid_capabilities_and_status(self) -> None:
        bridge = ESCLBridge(port=0, mock=False)
        caps = bridge.get_capabilities()
        self.assertIn("HP Smart Tank 500 series", caps)
        self.assertIn("PlatenInputCaps", caps)
        status = bridge.get_status()
        self.assertIn("ScannerStatus", status)
        self.assertIn("Idle", status)


if __name__ == "__main__":
    unittest.main()
