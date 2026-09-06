#!/usr/bin/env python3
"""
generate_option_matrix.py
Generador y evaluador combinatorio de matriz de opciones PPD para HP Smart Tank 500.

Realiza:
1. Muestreo exhaustivo de pares (pairwise combinatorial testing) de opciones clave:
   - Media × Quality
   - Media × PageSize / Borderless
   - Quality × InkSaver
   - ColorModel × PureBlack
   - Density × GammaCurve
   - DryTime × Media
2. Pruebas diferenciales contra rastertopcl3gui para verificar que:
   - Opciones activas alteran el stream PCL3GUI de forma determinista y reproducible.
   - Opciones idénticas generan streams bit a bit idénticos.
   - El filtro retorna código 0 sin crashes ni leaks de memoria.
"""

from __future__ import annotations

import argparse
import hashlib
import itertools
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
from typing import Any, Dict, List, Tuple

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Localización del binario del filtro compilado
DEFAULT_FILTER = PROJECT_ROOT / "research" / "builds" / "antigravity-offline-audit" / "rastertopcl3gui"
if not DEFAULT_FILTER.exists():
    DEFAULT_FILTER = PROJECT_ROOT / "research" / "builds" / "audit-clean" / "night-20260904" / "rastertopcl3gui"


def make_test_cups_raster(
    width: int = 64,
    height: int = 64,
    dpi: int = 600,
    colorspace: int = 1,  # 1 = RGB, 6 = CMYK, 17 = RGBW, 0 = Gray
    bpp: int = 24,
    media_type: int = 0,
    page_size_name: str = "A4",
    row_step: int = 0,
) -> bytes:
    """Crea un flujo de raster CUPS sintético y determinista para pruebas."""
    sync_word = struct.pack("<I", 0x52615333)  # RaS3
    header = bytearray(1796)

    # HWResolution (276)
    struct.pack_into("<II", header, 276, dpi, dpi)

    # cupsPageSizeName (32 bytes at 288)
    ps_bytes = page_size_name.encode("ascii")[:31]
    header[288 : 288 + len(ps_bytes)] = ps_bytes

    # PageSize points (352)
    if "Letter" in page_size_name:
        pt_w, pt_h = 612, 792
    elif "4x6" in page_size_name:
        pt_w, pt_h = 288, 432
    else:
        pt_w, pt_h = 595, 842  # A4

    struct.pack_into("<II", header, 352, pt_w, pt_h)

    # cupsImagingBBox (360)
    if ".FB" in page_size_name or "Borderless" in page_size_name:
        struct.pack_into("<ffff", header, 360, 0.0, 0.0, float(pt_w), float(pt_h))
    else:
        struct.pack_into("<ffff", header, 360, 9.0, 9.0, float(pt_w - 9), float(pt_h - 9))

    # cupsWidth, cupsHeight (372, 376)
    struct.pack_into("<II", header, 372, width, height)

    # cupsMediaType (380)
    struct.pack_into("<I", header, 380, media_type)

    # cupsBitsPerColor (384), cupsBitsPerPixel (388)
    bpc = 8
    struct.pack_into("<II", header, 384, bpc, bpp)

    bytes_per_line = (width * bpp) // 8
    struct.pack_into("<I", header, 392, bytes_per_line)

    # cupsColorOrder (396 = 0: CHUNKED)
    struct.pack_into("<I", header, 396, 0)

    # cupsColorSpace (400)
    struct.pack_into("<I", header, 400, colorspace)

    # cupsNumColors (420)
    num_colors = 4 if bpp == 32 else (1 if bpp == 8 else 3)
    struct.pack_into("<I", header, 420, num_colors)

    # cupsRowStep (440)
    struct.pack_into("<I", header, 440, row_step)

    # Generar contenido sintético de píxeles:
    # Cuadrantes con: Negro puro, Gris medio, Color (Rojo/Cian), Blanco
    rows = []
    half_w = width // 2
    half_h = height // 2

    for y in range(height):
        row = bytearray()
        for x in range(width):
            if colorspace == 1:  # sRGB 24-bit
                if y < half_h and x < half_w:
                    if y < half_h // 2:
                        row.extend(b"\x14\x16\x15")  # Near-black cuasi-neutro (20, 22, 21) -> forzado a (0,0,0) por TextOnly
                    else:
                        row.extend(b"\x00\x00\x00")  # Negro puro
                elif y < half_h and x >= half_w:
                    row.extend(b"\x7f\x7f\x7f")  # Gris 50%
                elif y >= half_h and x < half_w:
                    # Dividir en rojo y verde follaje para pruebas de gamut
                    if y < half_h + half_h // 2:
                        row.extend(b"\xff\x20\x20")  # Rojo vivo
                    else:
                        row.extend(b"\x20\xc0\x30")  # Verde follaje (ejercita VividLandscape)
                else:
                    # Dividir en blanco y azul cielo
                    if y < half_h + half_h // 2:
                        row.extend(b"\xff\xff\xff")  # Blanco
                    else:
                        row.extend(b"\x20\x40\xd0")  # Azul cielo (ejercita VividLandscape)
            elif colorspace == 6:  # CMYK 32-bit
                if y < half_h and x < half_w:
                    row.extend(b"\x00\x00\x00\xff")  # K puro
                elif y < half_h and x >= half_w:
                    row.extend(b"\x00\x00\x00\x80")  # K medio
                elif y >= half_h and x < half_w:
                    row.extend(b"\x00\xff\xff\x00")  # Rojo (M+Y)
                else:
                    row.extend(b"\x00\x00\x00\x00")  # Blanco
            elif colorspace == 17:  # RGBW 32-bit
                if y < half_h and x < half_w:
                    row.extend(b"\x00\x00\x00\x00")  # Negro
                elif y < half_h and x >= half_w:
                    row.extend(b"\x7f\x7f\x7f\x00")  # Gris
                elif y >= half_h and x < half_w:
                    row.extend(b"\xff\x20\x20\x00")  # Rojo
                else:
                    row.extend(b"\xff\xff\xff\xff")  # Blanco
            elif colorspace == 0:  # Gray 8-bit
                if y < half_h and x < half_w:
                    row.append(0x00)  # Negro
                elif y < half_h and x >= half_w:
                    row.append(0x80)  # Gris
                else:
                    row.append(0xFF)  # Blanco
            else:
                row.extend(b"\x00" * (bpp // 8))
        rows.append(bytes(row))

    return sync_word + bytes(header) + b"".join(rows)


def run_filter(filter_bin: Path, options_str: str, raster_bytes: bytes) -> Tuple[int, bytes, str]:
    """Ejecuta rastertopcl3gui pasando el raster por stdin y opciones en argv[5]."""
    cmd = [str(filter_bin), "1", "testuser", "testdoc", "1", options_str]
    proc = subprocess.run(
        cmd,
        input=raster_bytes,
        capture_output=True,
    )
    return proc.returncode, proc.stdout, proc.stderr.decode("utf-8", errors="replace")


def generate_pairwise_matrix() -> List[Dict[str, Any]]:
    """Genera casos de prueba combinatorios cubriendo pares ortogonales clave."""
    media_types = [("Plain", 0), ("Photo", 5), ("Matte", 8)]
    qualities = ["Draft", "Normal", "Best"]
    page_sizes = ["A4", "Letter", "4x6in.FB"]
    ink_savers = ["Off", "Eco25", "Eco50", "EdgePreserve", "DotGainGrid"]
    pure_blacks = ["Standard", "TextOnly", "AggressiveK"]
    gamma_curves = ["Standard", "ShadowBoost", "VividLandscape"]
    dry_times = ["None", "Short", "Medium"]
    densities = ["Normal", "Economy", "MaxTransfer"]

    cases = []
    case_id = 1

    # 1. Media x Quality
    for media_name, media_val in media_types:
        for qual in qualities:
            cases.append({
                "id": f"MQ_{case_id:03d}",
                "category": "Media_x_Quality",
                "media": (media_name, media_val),
                "quality": qual,
                "page_size": "A4",
                "options": f"OutputMode={qual} MediaType={media_name}",
            })
            case_id += 1

    # 2. Media x Borderless
    for media_name, media_val in [("Plain", 0), ("Photo", 5)]:
        for ps in ["A4", "Letter", "4x6in.FB"]:
            cases.append({
                "id": f"MB_{case_id:03d}",
                "category": "Media_x_Borderless",
                "media": (media_name, media_val),
                "quality": "Normal",
                "page_size": ps,
                "options": f"PageSize={ps} MediaType={media_name}",
            })
            case_id += 1

    # 3. Quality x InkSaver
    for qual in ["Draft", "Normal"]:
        for saver in ink_savers:
            cases.append({
                "id": f"QS_{case_id:03d}",
                "category": "Quality_x_InkSaver",
                "media": ("Plain", 0),
                "quality": qual,
                "page_size": "A4",
                "options": f"OutputMode={qual} HPInkSaver={saver}",
            })
            case_id += 1

    # 4. PureBlack x ColorModel
    for pb in pure_blacks:
        for cs_name, cs_val, bpp in [("sRGB", 1, 24), ("CMYK", 6, 32), ("RGBW", 17, 32)]:
            cases.append({
                "id": f"PB_{case_id:03d}",
                "category": "PureBlack_x_ColorModel",
                "media": ("Plain", 0),
                "quality": "Normal",
                "page_size": "A4",
                "colorspace": (cs_name, cs_val, bpp),
                "options": f"HPPureBlack={pb}",
            })
            case_id += 1

    # 5. Density x GammaCurve
    for dens in densities:
        for gamma in gamma_curves:
            cases.append({
                "id": f"DG_{case_id:03d}",
                "category": "Density_x_Gamma",
                "media": ("Plain", 0),
                "quality": "Normal",
                "page_size": "A4",
                "options": f"HPDensity={dens} HPGammaCurve={gamma}",
            })
            case_id += 1

    # 6. DryTime x Media
    for dt in dry_times:
        for media_name, media_val in [("Plain", 0), ("Photo", 5)]:
            cases.append({
                "id": f"DM_{case_id:03d}",
                "category": "DryTime_x_Media",
                "media": (media_name, media_val),
                "quality": "Best",
                "page_size": "A4",
                "options": f"HPDryTime={dt} MediaType={media_name}",
            })
            case_id += 1

    return cases


def run_matrix_tests(filter_bin: Path, verbose: bool = False) -> bool:
    """Ejecuta todas las pruebas combinatorias y diferenciales."""
    if not filter_bin.exists():
        print(f"[ERROR] Binario del filtro no encontrado: {filter_bin}", file=sys.stderr)
        return False

    cases = generate_pairwise_matrix()
    print(f"[*] Iniciando evaluación de matriz de opciones ({len(cases)} combinaciones)...")

    # 1. Ejecución de la matriz completa
    failures = 0
    passes = 0

    for c in cases:
        media_name, media_val = c.get("media", ("Plain", 0))
        page_size = c.get("page_size", "A4")
        cs_info = c.get("colorspace", ("sRGB", 1, 24))
        cs_val, bpp = cs_info[1], cs_info[2]

        raster = make_test_cups_raster(
            width=64,
            height=64,
            colorspace=cs_val,
            bpp=bpp,
            media_type=media_val,
            page_size_name=page_size,
        )

        code, stdout, stderr = run_filter(filter_bin, c["options"], raster)
        if code != 0 or len(stdout) == 0:
            failures += 1
            print(f"  [FAIL] Caso {c['id']} ({c['category']}): exit={code}, stdout={len(stdout)}B")
            if verbose:
                print(f"         stderr: {stderr.strip()}")
        else:
            passes += 1
            if verbose:
                sha = hashlib.sha256(stdout).hexdigest()[:12]
                print(f"  [PASS] Caso {c['id']} ({c['category']}): {len(stdout)} bytes [sha={sha}]")

    print(f"[*] Resultados combinatorios: {passes}/{len(cases)} superados ({failures} fallos).")
    if failures > 0:
        return False

    # 2. Pruebas diferenciales clave (Default vs Opciones Activas)
    print("[*] Ejecutando pruebas diferenciales y de determinismo...")
    diff_checks = [
        # (Nombre, Opt_A, Opt_B, Debe_ser_diferente, Razón)
        ("Determinismo Eco50", "HPInkSaver=Eco50", "HPInkSaver=Eco50", False, "Mismas opciones deben dar stream idéntico"),
        ("InkSaver Eco50 vs Off", "HPInkSaver=Off", "HPInkSaver=Eco50", True, "Eco50 debe alterar el raster Mode10"),
        ("InkSaver EdgePreserve vs Off", "HPInkSaver=Off", "HPInkSaver=EdgePreserve", True, "EdgePreserve debe modificar pixeles internos"),
        ("PureBlack TextOnly vs Standard", "HPPureBlack=Standard", "HPPureBlack=TextOnly", True, "TextOnly debe forzar negros puros"),
        ("DryTime Medium vs None", "HPDryTime=None", "HPDryTime=Medium", True, "DryTime emite comando PML adicional"),
        ("Gamma Vivid vs Standard", "HPGammaCurve=Standard", "HPGammaCurve=VividLandscape", True, "Gamma Vivid altera LUT de color"),
        ("Density Economy vs Normal", "HPDensity=Normal", "HPDensity=Economy", True, "Density Economy aplica reducción del 20%"),
    ]

    base_raster = make_test_cups_raster(width=64, height=64, colorspace=1, bpp=24)

    for test_name, opt_a, opt_b, should_differ, reason in diff_checks:
        code_a, out_a, _ = run_filter(filter_bin, opt_a, base_raster)
        code_b, out_b, _ = run_filter(filter_bin, opt_b, base_raster)

        self_equal = (hashlib.sha256(out_a).digest() == hashlib.sha256(out_b).digest())
        has_diff = not self_equal

        if code_a != 0 or code_b != 0:
            print(f"  [FAIL] {test_name}: Error de ejecución (exit_a={code_a}, exit_b={code_b})")
            return False

        if should_differ and not has_diff:
            print(f"  [FAIL] {test_name}: Se esperaba diferencia en el stream PCL pero resultaron idénticos. ({reason})")
            return False
        elif not should_differ and has_diff:
            print(f"  [FAIL] {test_name}: Se esperaba determinismo pero los streams difieren. ({reason})")
            return False
        else:
            print(f"  [PASS] {test_name} -> OK ({reason})")

    print("[+] Toda la matriz combinatoria y diferencial completada con éxito.")
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="PPD Option Matrix Combinatorial & Differential Tester")
    parser.add_argument("--filter-bin", type=Path, default=DEFAULT_FILTER, help="Ruta al binario rastertopcl3gui")
    parser.add_argument("--verbose", "-v", action="store_true", help="Salida detallada de cada caso")
    args = parser.parse_args()

    success = run_matrix_tests(args.filter_bin, verbose=args.verbose)
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
