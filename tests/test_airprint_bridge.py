#!/usr/bin/env python3
"""Acceptance tests for the IPP Everywhere/AirPrint bridge."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class AirPrintBridgeTests(unittest.TestCase):
    def test_required_macos_components_exist(self) -> None:
        self.assertTrue(Path("/usr/bin/ippeveprinter").is_file())
        self.assertTrue(Path("/usr/libexec/cups/command/ippeveps").is_file())

    def test_launcher_is_separate_from_local_escl(self) -> None:
        source = (ROOT / "tools" / "hp_airprint_daemon.sh").read_text(encoding="utf-8")
        conf = (ROOT / "tools" / "hp-smart-tank-500-airprint.conf").read_text(encoding="utf-8")
        self.assertIn("/usr/bin/ippeveprinter", source)
        self.assertIn("-r _universal", source)
        self.assertIn("pwg-raster", conf)
        self.assertIn("urf-supported", conf)
        self.assertNotIn("hp_escl_bridge.py", source)

    def test_submit_rejects_unknown_format(self) -> None:
        sample = ROOT / "research" / "corpus" / "pdf" / "01-white.pdf"
        result = subprocess.run(
            [str(ROOT / "tools" / "hp_ipp_submit.sh"), str(sample)],
            env={**os.environ, "CONTENT_TYPE": "application/octet-stream"},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("formato no soportado", result.stderr)

    def test_pdf_converts_without_printing(self) -> None:
        sample = ROOT / "research" / "corpus" / "pdf" / "01-white.pdf"
        with tempfile.TemporaryDirectory(prefix="hp-ipp-output-") as output:
            env = {
                **os.environ,
                "CONTENT_TYPE": "application/pdf",
                "OUTPUT_FORMAT": "application/postscript",
                "PPD": str(ROOT / "research" / "builds" / "hp-smart_tank_500_series.ppd"),
                "HP_IPP_TEST_OUTPUT_DIR": output,
                "IPP_JOB_ID": "42",
                "IPP_JOB_NAME": "Acceptance test",
            }
            result = subprocess.run(
                [str(ROOT / "tools" / "hp_ipp_submit.sh"), str(sample)],
                env=env,
                capture_output=True,
                text=True,
                timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            converted = Path(output) / "job-42.ps"
            self.assertTrue(converted.is_file())
            self.assertGreater(converted.stat().st_size, 1000)
            self.assertTrue(converted.read_bytes().startswith(b"%!PS-Adobe"))
            self.assertEqual(converted.stat().st_mode & 0o777, 0o600)

    def test_launcher_rejects_invalid_port(self) -> None:
        result = subprocess.run(
            [str(ROOT / "tools" / "hp_airprint_daemon.sh"), "--port", "80", "--no-advertise"],
            env={**os.environ, "HP_AIRPRINT_PROJECT_ROOT": str(ROOT)},
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 2)
        self.assertIn("puerto inválido", result.stderr)


if __name__ == "__main__":
    unittest.main()
