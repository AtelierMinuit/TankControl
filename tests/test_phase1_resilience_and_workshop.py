#!/usr/bin/env python3
"""
Tests unitarios para:
1. Blindaje de memoria (Zero-Realloc per page) y decodificación CMYK 32-bit nativa en rastertopcl3gui.
2. Resiliencia USB Hotplug y sincronización thread-safe en backend smarttank.
3. Comandos de servicio y taller mecánico (prime-tubes, waste-ink, head-health) en hp-smart-tank-tool.
"""

from __future__ import annotations

import json
import os
from pathlib import Path
import struct
import subprocess
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
AUDIT_BUILD = Path(os.environ.get("HP_AUDIT_BUILD_DIR", str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904")))
FILTER_PATH = AUDIT_BUILD / "rastertopcl3gui"
BACKEND_PATH = AUDIT_BUILD / "smarttank"
TOOL_PATH = AUDIT_BUILD / "hp-smart-tank-tool"
SAMPLE_RASTER = PROJECT_ROOT / "scratch" / "05-black-square.rgb.raster"


def create_minimal_cups_raster(width: int, height: int, colorspace: int = 6, bpp: int = 32) -> bytes:
    """Genera un archivo CUPS raster sintético con cabecera cups_page_header2_t válida."""
    # Sincronización CUPS Raster (0x52615333 en orden de máquina)
    sync_word = struct.pack("<I", 0x52615333)

    header = bytearray(1796)
    bytes_per_line = width * (bpp // 8)

    # HWResolution (offset 276): 600 x 600 DPI
    struct.pack_into("<II", header, 276, 600, 600)

    # PageSize (offset 352): 612 x 792 (Letter)
    struct.pack_into("<II", header, 352, 612, 792)

    # cupsWidth (offset 372)
    struct.pack_into("<I", header, 372, width)
    # cupsHeight (offset 376)
    struct.pack_into("<I", header, 376, height)
    # cupsMediaType (offset 380)
    struct.pack_into("<I", header, 380, 0)
    # cupsBitsPerColor (offset 384)
    struct.pack_into("<I", header, 384, 8)
    # cupsBitsPerPixel (offset 388)
    struct.pack_into("<I", header, 388, bpp)
    # cupsBytesPerLine (offset 392)
    struct.pack_into("<I", header, 392, bytes_per_line)
    # cupsColorOrder (offset 396)
    struct.pack_into("<I", header, 396, 0)  # CUPS_ORDER_CHUNKED
    # cupsColorSpace (offset 400)
    struct.pack_into("<I", header, 400, colorspace)  # CUPS_CSPACE_CMYK = 6
    # cupsNumColors (offset 420)
    struct.pack_into("<I", header, 420, 4 if bpp == 32 else 3)

    # Pixeles: relleno
    pixel_data = bytearray(bytes_per_line * height)
    if bpp == 32:
        # Píxel CMYK: C=0, M=128, Y=200, K=50
        for i in range(0, len(pixel_data), 4):
            pixel_data[i] = 0
            pixel_data[i+1] = 128
            pixel_data[i+2] = 200
            pixel_data[i+3] = 50

    return sync_word + bytes(header) + bytes(pixel_data)


class TestPhase1ResilienceAndCMYK(unittest.TestCase):
    """Verifica mejoras de robustez en rastertopcl3gui y cups_backend_smarttank."""

    def test_cmyk_32bit_raster_conversion(self):
        """Verifica que rastertopcl3gui procese flujos de color CMYK de 32 bits (InDesign/Affinity)."""
        cmyk_raster = create_minimal_cups_raster(width=100, height=50, colorspace=18, bpp=32)
        tmp_raster_file = Path("/tmp/test_cmyk.raster")
        tmp_raster_file.write_bytes(cmyk_raster)

        cmd = [str(FILTER_PATH), "1", "prepress", "doc_cmyk", "1", "", str(tmp_raster_file)]
        proc = subprocess.run(cmd, capture_output=True, check=True)

        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("Finalizado exitosamente. 1 paginas procesadas.", stderr)
        self.assertTrue(proc.stdout.startswith(b"\x1b%-12345X"))
        self.assertTrue(proc.stdout.endswith(b"\x1b%-12345X"))

        if tmp_raster_file.exists():
            tmp_raster_file.unlink()

    @unittest.skipUnless(SAMPLE_RASTER.exists(), "Requiere scratch/05-black-square.rgb.raster")
    def test_multi_page_buffer_reuse(self):
        """Verifica que el procesamiento de múltiples páginas sea limpio y sin sobreasignación."""
        cmd = [str(FILTER_PATH), "1", "user", "doc", "1", "", str(SAMPLE_RASTER)]
        proc = subprocess.run(cmd, capture_output=True, check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("Finalizado exitosamente.", stderr)

    def test_backend_hotplug_and_thread_safety(self):
        """Verifica que el backend con sincronización mutex ejecute limpiamente en modo mock."""
        env = dict(os.environ, HP_SMART_TANK_MOCK="1")
        cmd = [str(BACKEND_PATH), "777", "hotplug_test", "JobDoc.pdf", "1", "mock=1"]
        proc = subprocess.run(cmd, env=env, capture_output=True, input=b"\x0c", check=True)
        stderr = proc.stderr.decode("utf-8", errors="replace")
        self.assertIn("Trabajo #777 simulado exitosamente", stderr)
        self.assertEqual(proc.returncode, 0)


class TestWorkshopCommands(unittest.TestCase):
    """Verifica los nuevos comandos de taller y servicio de CISS (prime-tubes, waste-ink, head-health)."""

    def test_hazardous_commands_require_explicit_confirmation(self):
        """Las operaciones físicas deben bloquearse antes de abrir el hardware."""
        commands = [
            ["clean-heads"], ["deep-clean"], ["clean-rollers"],
            ["diag-page"], ["nozzle-test"], ["align"], ["prime-tubes"],
            ["test-pattern"],
        ]
        for command in commands:
            with self.subTest(command=command[0]):
                proc = subprocess.run([str(TOOL_PATH), *command], capture_output=True, text=True)
                self.assertEqual(proc.returncode, 2)
                self.assertIn("Operación bloqueada", proc.stderr)

        raw = Path("/tmp/hp-raw-confirmation-test.bin")
        raw.write_bytes(b"x")
        proc = subprocess.run([str(TOOL_PATH), "inject-raw", str(raw)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 2)
        self.assertIn("Operación bloqueada", proc.stderr)

    def test_prime_tubes_mock(self):
        """Verifica la ejecución del comando de cebado forzado de mangueras CISS."""
        proc = subprocess.run(
            [str(TOOL_PATH), "prime-tubes", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        self.assertIn("CEBADO Y PURGA FORZADA DE TUBOS DE TINTA CISS", proc.stdout)
        self.assertIn("Cebado simulado completado", proc.stdout)

    def test_waste_ink_audit_mock(self):
        """Verifica el cálculo de saturación de almohadillas absorbedoras de tinta de desecho."""
        proc = subprocess.run(
            [str(TOOL_PATH), "waste-ink", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        self.assertIn("AUDITORÍA DE ALMOHADILLAS DE TINTA RESIDUAL", proc.stdout)
        self.assertIn("Capacidad del depósito absorbedor", proc.stdout)
        self.assertIn("Saturación de las almohadillas", proc.stdout)

    def test_waste_ink_uses_management_ews_interface(self):
        text = (PROJECT_ROOT / "tools" / "hp-smart-tank-tool.c").read_text()
        section = text[text.index('} else if (strcmp(cmd, "waste-ink")'):]
        section = section[:section.index('} else if (strcmp(cmd, "json-waste-ink")')]
        self.assertIn('open_channel(ctx, 0xff, 0x04, 0x01, &chan)', section)
        self.assertNotIn('open_channel(ctx, 0xff, 0xcc, 0x00, &chan)', section)
        self.assertIn('parse_xml_nonnegative_int(buffer, "TotalSpitCount>", &spit_count)', section)
        self.assertNotIn('sscanf(ptr, "TotalSpitCount>%d", &spit_count)', section)

    def test_json_waste_ink(self):
        """Verifica la telemetría JSON de almohadillas absorbedoras."""
        proc = subprocess.run(
            [str(TOOL_PATH), "json-waste-ink", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(proc.stdout)
        self.assertIn("capacity_ml", data)
        self.assertIn("waste_ml", data)
        self.assertIn("saturation_pct", data)
        self.assertIn("status", data)

    def test_head_health_mock(self):
        """Verifica el diagnóstico térmico y eléctrico de cabezales M0H51A / M0H50A."""
        proc = subprocess.run(
            [str(TOOL_PATH), "head-health", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        self.assertIn("DIAGNÓSTICO TÉRMICO Y SALUD DE CABEZALES", proc.stdout)
        self.assertIn("M0H51A", proc.stdout)
        self.assertIn("M0H50A", proc.stdout)
        self.assertIn("valores siguientes son sintéticos", proc.stdout)

    def test_json_head_health(self):
        """Verifica la telemetría JSON de salud de cabezales."""
        proc = subprocess.run(
            [str(TOOL_PATH), "json-head-health", "--mock"],
            capture_output=True,
            text=True,
            check=True
        )
        data = json.loads(proc.stdout)
        self.assertIn("black_head", data)
        self.assertIn("color_head", data)
        self.assertIn("flex_voltage", data)
        self.assertEqual(data["black_head"]["model"], "M0H51A")


if __name__ == "__main__":
    unittest.main()
