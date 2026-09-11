#!/usr/bin/env python3
"""Integration tests for IPP Everywhere / AirPrint bridge using Apple's /usr/bin/ipptool."""

from __future__ import annotations

import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
IPP_TOOL = Path("/usr/bin/ipptool")
IPP_SUITE_DIR = Path("/usr/share/cups/ipptool")


def get_free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


class AirPrintIppToolSuiteTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        if not IPP_TOOL.is_file() or not IPP_SUITE_DIR.is_dir():
            raise unittest.SkipTest("ipptool or IPP test suite missing on system")

    def setUp(self) -> None:
        self.port = get_free_port()
        self.output_dir = tempfile.TemporaryDirectory(prefix="hp-airprint-test-")
        self.env = {
            **os.environ,
            "HP_AIRPRINT_PROJECT_ROOT": str(ROOT),
            "HP_IPP_TEST_OUTPUT_DIR": self.output_dir.name,
            "PPD": str(ROOT / "research" / "builds" / "hp-smart_tank_500_series.ppd"),
        }
        self.daemon_proc = subprocess.Popen(
            [
                str(ROOT / "tools" / "hp_airprint_daemon.sh"),
                "--port",
                str(self.port),
                "--no-advertise",
                "--test-output-dir",
                self.output_dir.name,
            ],
            env=self.env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # Wait for daemon to bind port
        bound = False
        for _ in range(30):
            time.sleep(0.1)
            if self.daemon_proc.poll() is not None:
                break
            try:
                with socket.create_connection(("127.0.0.1", self.port), timeout=0.2):
                    bound = True
                    break
            except (ConnectionRefusedError, OSError):
                pass

        if not bound:
            self.fail(f"Daemon failed to bind port {self.port}")

        self.printer_uri = f"ipp://localhost:{self.port}/ipp/print"

    def tearDown(self) -> None:
        if self.daemon_proc.poll() is None:
            self.daemon_proc.terminate()
            try:
                self.daemon_proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                self.daemon_proc.kill()
                self.daemon_proc.wait()
        self.output_dir.cleanup()

    def test_get_printer_attributes(self) -> None:
        test_file = IPP_SUITE_DIR / "get-printer-attributes.test"
        cmd = [str(IPP_TOOL), "-t", self.printer_uri, str(test_file)]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
        self.assertEqual(res.returncode, 0, f"get-printer-attributes failed:\n{res.stdout}\n{res.stderr}")
        self.assertIn("[PASS]", res.stdout)

    def test_validate_job_formats(self) -> None:
        test_file = IPP_SUITE_DIR / "validate-job.test"
        formats = ["image/pwg-raster", "image/urf", "application/octet-stream"]
        for fmt in formats:
            with self.subTest(format=fmt):
                cmd = [
                    str(IPP_TOOL),
                    "-t",
                    "-d",
                    f"filetype={fmt}",
                    self.printer_uri,
                    str(test_file),
                ]
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
                self.assertEqual(res.returncode, 0, f"validate-job failed for {fmt}:\n{res.stdout}\n{res.stderr}")
                self.assertIn("[PASS]", res.stdout)

    def test_print_job_creates_postscript_spool(self) -> None:
        test_file = IPP_SUITE_DIR / "print-job.test"
        sample_pwg = ROOT / "tests" / "fixtures" / "onepage-letter-300-black-1.pwg"
        if not sample_pwg.is_file():
            sample_pwg = ROOT / "research" / "cups-apple-v2.3.6" / "examples" / "onepage-letter-300-black-1.pwg"
        self.assertTrue(sample_pwg.is_file(), f"Sample PWG raster not found: {sample_pwg}")

        cmd = [
            str(IPP_TOOL),
            "-t",
            "-d",
            "filetype=image/pwg-raster",
            "-d",
            f"filename={sample_pwg}",
            self.printer_uri,
            str(test_file),
        ]
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        self.assertEqual(res.returncode, 0, f"print-job failed:\n{res.stdout}\n{res.stderr}")
        self.assertIn("[PASS]", res.stdout)

        # Allow submit script output to finish writing
        time.sleep(0.5)
        spool_files = list(Path(self.output_dir.name).glob("job-*.ps"))
        self.assertGreaterEqual(len(spool_files), 1, f"No spool files generated in {self.output_dir.name}")
        ps_file = spool_files[0]
        self.assertGreater(ps_file.stat().st_size, 1000)
        content = ps_file.read_bytes()
        self.assertTrue(content.startswith(b"%!PS-Adobe"), "Generated file is not PostScript")


if __name__ == "__main__":
    unittest.main()
