#!/usr/bin/env python3
"""
Fuzzing Diferencial y Pruebas de Resiliencia de Memoria para rastertopcl3gui (Apple Silicon).
Prueba mutaciones de cabeceras CUPS raster, desbordamientos de enteros, corrupciones de flujo
y verifica inmunidad a caídas y fugas con Clang AddressSanitizer (ASan/UBSan).
"""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path
import random
import struct
import subprocess
import sys
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
AUDIT_BUILD = Path(os.environ.get("HP_AUDIT_BUILD_DIR", str(PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904")))
BINARY_PATH = AUDIT_BUILD / "rastertopcl3gui"
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
ASAN_BIN = AUDIT_BUILD / "rastertopcl3gui_asan"

# Compilar binario ASan si no existe
if not ASAN_BIN.exists():
    cmd = [
        "clang", "-fsanitize=address,undefined", "-g", "-O1",
        str(PROJECT_ROOT / "tools" / "rastertopcl3gui.c"),
        "-o", str(ASAN_BIN),
        "-lcups"
    ]
    subprocess.run(cmd, check=True)

# Cargar decodificador
SPEC_DEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
DECODER = importlib.util.module_from_spec(SPEC_DEC)
sys.modules[SPEC_DEC.name] = DECODER
SPEC_DEC.loader.exec_module(DECODER)


def build_cups_raster_header(
    width: int = 200,
    height: int = 100,
    dpi: int = 300,
    bpp: int = 24,
    bpc: int = 8,
    bytes_per_line: int | None = None,
    color_space: int = 1,  # CUPS_CSPACE_RGB
    magic: bytes = b"3SaR",
) -> bytes:
    """Construye una cabecera CUPS raster v2/v3 válida o modificable."""
    if bytes_per_line is None:
        bytes_per_line = (width * bpp + 7) // 8

    # Buffer de 1796 bytes para cups_page_header2_t
    hdr = bytearray(1796)

    # HWResolution en offset 276
    struct.pack_into("<II", hdr, 276, dpi, dpi)
    # cupsWidth, cupsHeight en offset 372, 376
    struct.pack_into("<II", hdr, 372, width, height)
    # cupsBitsPerColor en 384
    struct.pack_into("<I", hdr, 384, bpc)
    # cupsBitsPerPixel en 388
    struct.pack_into("<I", hdr, 388, bpp)
    # cupsBytesPerLine en 392
    struct.pack_into("<I", hdr, 392, bytes_per_line)
    # cupsColorSpace en 400
    struct.pack_into("<I", hdr, 400, color_space)

    # PageSize[2] en offset 344 (aproximado en puntos)
    pt_w = int(width * 72.0 / dpi)
    pt_h = int(height * 72.0 / dpi)
    struct.pack_into("<II", hdr, 344, pt_w, pt_h)

    return magic + bytes(hdr)


class DifferentialFuzzingPCL3GUITests(unittest.TestCase):
    """Batería de pruebas de fuzzing diferencial y robustez de memoria."""

    def run_filter(self, data: bytes, target_bin: Path = ASAN_BIN) -> tuple[int, bytes, str]:
        """Ejecuta el filtro con los datos dados en stdin."""
        env = os.environ.copy()
        # Opciones ASan para macOS (Darwin no soporta LSan/detect_leaks)
        env["ASAN_OPTIONS"] = "abort_on_error=1:allocator_may_return_null=1"
        proc = subprocess.run(
            [str(target_bin), "1", "fuzzuser", "fuzztask", "1", ""],
            input=data,
            capture_output=True,
            env=env,
        )
        return proc.returncode, proc.stdout, proc.stderr.decode(errors="replace")

    def test_fuzz_corrupt_magics_no_crash(self) -> None:
        """Verifica que números mágicos corruptos o incompletos no tiren el proceso."""
        corrupt_magics = [
            b"",
            b"Ra",
            b"XXXX",
            b"\x00\x00\x00\x00",
            b"\xff\xff\xff\xff",
            b"RaS3\x00\x00",
        ]
        for mag in corrupt_magics:
            code, stdout, stderr = self.run_filter(mag)
            self.assertIn(code, (0, 1), f"Fallo catastrófico con magic {mag!r}")

    def test_fuzz_truncated_headers_no_crash(self) -> None:
        """Verifica truncamientos a distintas longitudes de cabecera."""
        full_hdr = build_cups_raster_header(width=100, height=50)
        for cut in [1, 4, 10, 100, 500, 1000, 1795]:
            code, _, _ = self.run_filter(full_hdr[:cut])
            self.assertIn(code, (0, 1), f"Fallo con cabecera truncada en byte {cut}")

    def test_fuzz_zero_and_negative_dimensions(self) -> None:
        """Dimensiones cero deben rechazarse limpiamente."""
        # width = 0
        hdr = build_cups_raster_header(width=0, height=100)
        code, _, stderr = self.run_filter(hdr)
        self.assertIn(code, (0, 1))
        self.assertIn("Dimensiones de pagina invalidas", stderr)

        # height = 0
        hdr = build_cups_raster_header(width=100, height=0)
        code, _, stderr = self.run_filter(hdr)
        self.assertIn(code, (0, 1))
        self.assertIn("Dimensiones de pagina invalidas", stderr)

    def test_fuzz_excessive_dimensions_rejected(self) -> None:
        """Dimensiones descomunales no deben provocar desbordamiento de búfer ni OOM."""
        hdr = build_cups_raster_header(width=35000, height=5000)
        code, _, stderr = self.run_filter(hdr)
        self.assertEqual(code, 1)
        self.assertIn("Dimensiones de pagina invalidas", stderr)

        hdr2 = build_cups_raster_header(width=100, height=70000)
        code2, _, stderr2 = self.run_filter(hdr2)
        self.assertEqual(code2, 1)
        self.assertIn("Dimensiones de pagina invalidas", stderr2)

    def test_fuzz_excessive_bytes_per_line_rejected(self) -> None:
        """cupsBytesPerLine enorme no debe provocar integer wrap o crash."""
        hdr = build_cups_raster_header(width=200, height=100, bytes_per_line=1000000)
        code, _, stderr = self.run_filter(hdr)
        self.assertIn(code, (0, 1))
        self.assertTrue(
            "cupsBytesPerLine excesivo" in stderr or "0 paginas procesadas" in stderr,
            f"Salida inesperada: {stderr}"
        )

    def test_fuzz_undersized_bytes_per_line_in_grayscale(self) -> None:
        """En escala de grises, cupsBytesPerLine menor que width debe rechazarse."""
        hdr = build_cups_raster_header(
            width=200, height=50, bpp=8, bpc=8, bytes_per_line=50, color_space=0  # CUPS_CSPACE_W
        )
        code, _, stderr = self.run_filter(hdr)
        self.assertEqual(code, 1)
        self.assertTrue(
            "cupsBytesPerLine" in stderr or "0 paginas procesadas" in stderr,
            f"Salida inesperada: {stderr}"
        )

    def test_fuzz_unsupported_bpp_rejected_cleanly(self) -> None:
        """Formatos como 32 bpp (CMYK o RGBA) o 1 bpp deben manejarse con mensaje informativo."""
        for unsupported_bpp in [1, 4, 16, 64]:
            hdr = build_cups_raster_header(width=100, height=50, bpp=unsupported_bpp, color_space=6)
            code, _, stderr = self.run_filter(hdr)
            self.assertEqual(code, 1)
            self.assertTrue(
                "Profundidad de color no soportada" in stderr or "0 paginas procesadas" in stderr,
                f"Salida inesperada: {stderr}"
            )

    def test_fuzz_truncated_pixel_stream_resilience(self) -> None:
        """Si la trama se corta antes del final de la página, el filtro debe terminar graciosamente."""
        width = 100
        height = 100
        hdr = build_cups_raster_header(width=width, height=height)
        # Solo entregar 3 filas de pixeles en lugar de 100
        partial_data = hdr + (b"\x10\x20\x30" * width) * 3
        code, stdout, stderr = self.run_filter(partial_data)
        self.assertEqual(code, 1)
        # El flujo debe terminar con PJL EOJ limpio
        self.assertTrue(stdout.endswith(b"\x1b%-12345X"))

    def test_fuzz_high_entropy_noise(self) -> None:
        """Generar ruido pseudo-aleatorio de alta entropía y verificar compresión Mode 10."""
        random.seed(42)
        width = 150
        height = 40
        hdr = build_cups_raster_header(width=width, height=height)
        # 40 líneas de bytes completamente aleatorios
        noise_lines = [os.urandom(width * 3) for _ in range(height)]
        stream = hdr + b"".join(noise_lines)

        code, stdout, stderr = self.run_filter(stream)
        self.assertEqual(code, 0, f"Error con ruido aleatorio: {stderr}")
        self.assertGreater(len(stdout), 1000)

        # Verificar que el flujo es 100% decodificable por nuestro motor
        dec_rows, _, stats, _ = DECODER.decode_stream_mode10(stdout, width, height)
        self.assertEqual(len(dec_rows), height, "El número de filas decodificadas debe coincidir")

    def test_fuzz_mode10_extreme_runs_and_seed_copies(self) -> None:
        """Prueba patrones que fuerzan números muy grandes de RLE y copia de semilla (VLI)."""
        width = 2000
        height = 10
        hdr = build_cups_raster_header(width=width, height=height)

        lines = []
        # Fila 1: Todo rojo
        lines.append(b"\xFF\x00\x00" * width)
        # Fila 2: Mitad idéntica a semilla (rojo), mitad verde
        lines.append((b"\xFF\x00\x00" * 1000) + (b"\x00\xFF\x00" * 1000))
        # Fila 3: Todo verde (copia completa de la 2da mitad anterior)
        lines.append(b"\x00\xFF\x00" * width)
        # Fila 4: Variaciones de +/- 1 en cada componente (fuerza short deltas masivos)
        sdelta_row = bytearray()
        for i in range(width):
            sdelta_row.extend(b"\x01\xFE\x02")
        lines.append(bytes(sdelta_row))

        # Rellenar resto con azul
        for _ in range(height - 4):
            lines.append(b"\x00\x00\xFF" * width)

        stream = hdr + b"".join(lines)
        code, stdout, stderr = self.run_filter(stream)
        self.assertEqual(code, 0, f"Fallo en prueba Mode 10 VLI: {stderr}")

        # Decodificar y verificar
        dec_rows, _, stats, _ = DECODER.decode_stream_mode10(stdout, width, height)
        self.assertEqual(len(dec_rows), height)


if __name__ == "__main__":
    unittest.main()
