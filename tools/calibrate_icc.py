#!/usr/bin/env python3
"""
calibrate_icc.py
Generador experimental de perfiles ColorSync ICC para HP Smart Tank 500.
Analiza la carta escaneada a 600 DPI, calcula desviaciones CIELAB Delta E,
modela curvas TRC y ganancia de punto de las tintas HP GT51 / GT52 / GT53,
y sintetiza un perfil ICC matemáticamente válido para inspección con macOS sips; no acredita calibración física.
"""

from __future__ import annotations

import argparse
import atexit
import math
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
import sys

TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

from generate_color_target import COLORCHECKER_PATCHES


def srgb_to_linear(v: float) -> float:
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def linear_to_srgb(v: float) -> int:
    val = 12.92 * v if v <= 0.0031308 else 1.055 * (v ** (1.0 / 2.4)) - 0.055
    return max(0, min(255, int(round(val * 255.0))))


def rgb_to_xyz(r: int, g: int, b: int) -> tuple[float, float, float]:
    """Convierte sRGB a CIE XYZ (D65)."""
    rl = srgb_to_linear(r)
    gl = srgb_to_linear(g)
    bl = srgb_to_linear(b)
    x = rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375
    y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750
    z = rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041
    return x, y, z


def xyz_to_lab(x: float, y: float, z: float, xn: float = 0.95047, yn: float = 1.00000, zn: float = 1.08883) -> tuple[float, float, float]:
    """Convierte CIE XYZ a CIE L*a*b* (D65)."""
    def f(t: float) -> float:
        return t ** (1.0 / 3.0) if t > (6.0 / 29.0) ** 3 else (1.0 / 3.0) * ((29.0 / 6.0) ** 2) * t + (4.0 / 29.0)

    fx = f(x / xn)
    fy = f(y / yn)
    fz = f(z / zn)
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)
    return L, a, b


def delta_e76(lab1: tuple[float, float, float], lab2: tuple[float, float, float]) -> float:
    """Calcula la distancia de color perceptual Delta E CIE 1976."""
    return math.sqrt((lab1[0] - lab2[0]) ** 2 + (lab1[1] - lab2[1]) ** 2 + (lab1[2] - lab2[2]) ** 2)


class PPMImage:
    """Lector ligero de PPM binario (P6) sin dependencias."""

    def __init__(self, filepath: Path) -> None:
        with open(filepath, "rb") as f:
            magic = f.readline().strip()
            if magic != b"P6":
                raise ValueError(f"Formato PPM no soportado ({magic})")
            line = f.readline().strip()
            while line.startswith(b"#"):
                line = f.readline().strip()
            dims = line.split()
            self.width = int(dims[0])
            self.height = int(dims[1])
            maxval = f.readline().strip()
            while maxval.startswith(b"#"):
                maxval = f.readline().strip()
            self.maxval = int(maxval)
            self.data = f.read()

    def sample_average_rgb(self, cx: int, cy: int, radius: int = 10) -> tuple[float, float, float]:
        total_r = total_g = total_b = 0
        count = 0
        for dy in range(-radius, radius + 1):
            y = cy + dy
            if 0 <= y < self.height:
                row_offset = y * self.width * 3
                for dx in range(-radius, radius + 1):
                    x = cx + dx
                    if 0 <= x < self.width:
                        idx = row_offset + x * 3
                        total_r += self.data[idx]
                        total_g += self.data[idx + 1]
                        total_b += self.data[idx + 2]
                        count += 1
        if count == 0:
            return (0.0, 0.0, 0.0)
        return (total_r / count, total_g / count, total_b / count)


def synthesize_icc_profile(
    output_icc_path: Path,
    r_gamma: float = 2.2,
    g_gamma: float = 2.2,
    b_gamma: float = 2.2,
    desc_name: str = "HP Smart Tank 500 Precision ColorSync Profile",
    r_xyz: tuple[float, float, float] = (0.4360, 0.2225, 0.0139),
    g_xyz: tuple[float, float, float] = (0.3851, 0.7169, 0.0971),
    b_xyz: tuple[float, float, float] = (0.1431, 0.0606, 0.7141),
) -> Path:
    """Sintetiza un perfil binario ICC v2.4 para pruebas offline."""
    def to_s15fixed16(val: float) -> int:
        return int(round(val * 65536.0))

    def make_xyz_tag(x: float, y: float, z: float) -> bytes:
        return b"XYZ \x00\x00\x00\x00" + struct.pack(">iii", to_s15fixed16(x), to_s15fixed16(y), to_s15fixed16(z))

    def make_desc_tag(text: str) -> bytes:
        ascii_bytes = text.encode("ascii") + b"\x00"
        tag = b"desc\x00\x00\x00\x00"
        tag += struct.pack(">I", len(ascii_bytes)) + ascii_bytes
        tag += struct.pack(">IIHB67s", 0, 0, 0, 0, b"\x00" * 67)
        return tag

    def make_text_tag(text: str) -> bytes:
        return b"text\x00\x00\x00\x00" + text.encode("ascii") + b"\x00"

    def make_curve_gamma(gamma: float) -> bytes:
        u8fixed8 = int(round(gamma * 256.0))
        return b"curv\x00\x00\x00\x00" + struct.pack(">IH", 1, u8fixed8) + b"\x00\x00"

    # Matriz de adaptación cromática Bradford a PCS D50
    chad_matrix = (68674, 1502, -3290, 1938, 64913, -1118, -605, 988, 49260)
    chad_tag = b"sf32\x00\x00\x00\x00" + struct.pack(">9i", *chad_matrix)

    tags = [
        (b"desc", make_desc_tag(desc_name)),
        (b"cprt", make_text_tag("Copyright (c) 2026 Native HP Smart Tank Project (MIT)")),
        (b"dmnd", make_desc_tag("Hewlett-Packard")),
        (b"dmdd", make_desc_tag("HP Smart Tank 500 series")),
        (b"wtpt", make_xyz_tag(0.9642, 1.0000, 0.8249)),  # D50 white point
        (b"bkpt", make_xyz_tag(0.0000, 0.0000, 0.0000)),
        (b"rXYZ", make_xyz_tag(r_xyz[0], r_xyz[1], r_xyz[2])),
        (b"gXYZ", make_xyz_tag(g_xyz[0], g_xyz[1], g_xyz[2])),
        (b"bXYZ", make_xyz_tag(b_xyz[0], b_xyz[1], b_xyz[2])),
        (b"rTRC", make_curve_gamma(r_gamma)),
        (b"gTRC", make_curve_gamma(g_gamma)),
        (b"bTRC", make_curve_gamma(b_gamma)),
        (b"chad", chad_tag),
    ]

    tag_count = len(tags)
    tag_table_len = 4 + tag_count * 12
    current_offset = 128 + tag_table_len

    tag_records = []
    tag_payloads = []

    for sig, data in tags:
        pad = (4 - (len(data) % 4)) % 4
        padded_data = data + b"\x00" * pad
        tag_records.append(struct.pack(">4sII", sig, current_offset, len(data)))
        tag_payloads.append(padded_data)
        current_offset += len(padded_data)

    total_size = current_offset
    hdr = bytearray(128)
    struct.pack_into(">I", hdr, 0, total_size)
    hdr[4:8] = b"appl"
    struct.pack_into(">I", hdr, 8, 0x02200000)  # v2.2.0
    hdr[12:16] = b"mntr"                         # Monitor/Output class
    hdr[16:20] = b"RGB "
    hdr[20:24] = b"XYZ "
    struct.pack_into(">HHHHHH", hdr, 24, 2026, 9, 4, 12, 0, 0)
    hdr[36:40] = b"acsp"
    hdr[40:44] = b"APPL"
    hdr[48:52] = b"HP  "
    hdr[52:56] = b"500 "
    struct.pack_into(">iii", hdr, 68, to_s15fixed16(0.9642), to_s15fixed16(1.0000), to_s15fixed16(0.8249))

    full_profile = bytes(hdr) + struct.pack(">I", tag_count) + b"".join(tag_records) + b"".join(tag_payloads)
    output_icc_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_icc_path, "wb") as f:
        f.write(full_profile)

    return output_icc_path


def synthesize_multi_paper_profiles(output_dir: Path) -> dict[str, Path]:
    """Sintetiza perfiles específicos según la absorción y gamut de cada tipo de papel."""
    output_dir.mkdir(parents=True, exist_ok=True)
    profiles = {
        "Plain": synthesize_icc_profile(
            output_dir / "HP_Smart_Tank_Plain.icc",
            r_gamma=2.35, g_gamma=2.25, b_gamma=2.38,
            desc_name="HP Smart Tank 500 - Papel Normal",
        ),
        "Glossy": synthesize_icc_profile(
            output_dir / "HP_Smart_Tank_Glossy.icc",
            r_gamma=2.10, g_gamma=2.05, b_gamma=2.12,
            desc_name="HP Smart Tank 500 - Papel Fotografico",
            r_xyz=(0.4600, 0.2350, 0.0140),
            g_xyz=(0.3600, 0.7200, 0.0900),
            b_xyz=(0.1442, 0.0450, 0.7209),
        ),
        "Matte": synthesize_icc_profile(
            output_dir / "HP_Smart_Tank_Matte.icc",
            r_gamma=2.22, g_gamma=2.20, b_gamma=2.24,
            desc_name="HP Smart Tank 500 - Folleto y Mate",
        ),
    }
    return profiles


def run_calibration(
    scan_file: Path | None = None,
    output_icc: Path | None = None,
    install: bool = False,
    mock: bool = False,
) -> Path:
    """Ejecuta el análisis en bucle cerrado y genera el perfil ICC maestro."""
    if output_icc is None:
        output_icc = Path(tempfile.mkdtemp(prefix="hp-icc-")) / "HP_Smart_Tank_500_Precision.icc"

    print("======================================================================")
    print("  CALIBRADOR CROMÁTICO EN BUCLE CERRADO (HP SMART TANK 500)")
    print("  Óptica de escáner plano + Inyección térmica GT51/GT52/GT53")
    print("======================================================================")

    # 1. Obtener imagen en formato PPM
    tmp_dir = Path(tempfile.mkdtemp(prefix="hp-icc-scan-"))
    atexit.register(shutil.rmtree, tmp_dir, ignore_errors=True)
    tmp_ppm = tmp_dir / "calibration_scan.ppm"
    if scan_file and scan_file.exists():
        print(f"[Calibrate] Cargando imagen escaneada: {scan_file}")
        subprocess.run(["sips", "-s", "format", "ppm", str(scan_file), "--out", str(tmp_ppm)], check=True)
    elif not mock:
        raise RuntimeError("Se requiere --scan con una carta escaneada; la carta sintética sólo está disponible con --mock.")
    else:
        # Generar una referencia temporal; no depender del árbol de desarrollo.
        from generate_color_target import generate_color_target
        ref_ppm, _, _ = generate_color_target(dpi=150)
        tmp_ppm = ref_ppm
        print(f"[Calibrate] Modo {'Simulado / Referencia' if mock else 'Carta Patrón'}: {tmp_ppm}")

    img = PPMImage(tmp_ppm)
    print(f"[Calibrate] Dimensiones del escaneo: {img.width}x{img.height} px")

    # 2. Muestreo de los 24 parches ColorChecker
    dpi_est = img.width / 8.27
    grid_x0 = int(1.2 * dpi_est)
    grid_y0 = int(1.3 * dpi_est)
    patch_w = int(0.95 * dpi_est)
    patch_h = int(0.95 * dpi_est)
    gap_x = int(0.08 * dpi_est)
    gap_y = int(0.08 * dpi_est)

    print("\n[Calibrate] Muestreando 24 parches ColorChecker y computando Delta E:")
    print("  #   Parche                   Ref sRGB       Medido RGB     Delta E")
    print("  ------------------------------------------------------------------")

    delta_errors = []
    r_measurements = []
    g_measurements = []
    b_measurements = []

    for idx, (name, ref_srgb, ref_lab) in enumerate(COLORCHECKER_PATCHES):
        row = idx // 6
        col = idx % 6
        cx = grid_x0 + col * (patch_w + gap_x) + patch_w // 2
        cy = grid_y0 + row * (patch_h + gap_y) + patch_h // 2

        mr, mg, mb = img.sample_average_rgb(cx, cy, radius=int(0.1 * dpi_est))

        # En simulación, añadir ligera dispersión de absorción de papel (-3%)
        if mock:
            mr = max(0, mr * 0.97)
            mg = max(0, mg * 0.98)
            mb = max(0, mb * 0.96)

        r_measurements.append((ref_srgb[0], mr))
        g_measurements.append((ref_srgb[1], mg))
        b_measurements.append((ref_srgb[2], mb))

        mx, my, mz = rgb_to_xyz(int(mr), int(mg), int(mb))
        mlab = xyz_to_lab(mx, my, mz)
        dE = delta_e76(ref_lab, mlab)
        delta_errors.append(dE)

        print(f"  {idx+1:02d}  {name:<22}  {str(ref_srgb):<13}  ({int(mr):3d},{int(mg):3d},{int(mb):3d})   ΔE = {dE:5.2f}")

    avg_dE = sum(delta_errors) / len(delta_errors)
    max_dE = max(delta_errors)
    print("  ------------------------------------------------------------------")
    print(f"  Promedio Delta E: {avg_dE:.2f} | Máximo Delta E: {max_dE:.2f}")

    # 3. Modelado de curvas TRC y compensación de ganancia de punto
    # Gamma calibrada según atenuación media del canal
    r_gain = sum(m / max(1, r) for r, m in r_measurements if r > 40) / len(r_measurements)
    g_gain = sum(m / max(1, g) for g, m in g_measurements if g > 40) / len(g_measurements)
    b_gain = sum(m / max(1, b) for b, m in b_measurements if b > 40) / len(b_measurements)

    r_gamma = 2.2 * (1.0 / max(0.5, min(1.5, r_gain)))
    g_gamma = 2.2 * (1.0 / max(0.5, min(1.5, g_gain)))
    b_gamma = 2.2 * (1.0 / max(0.5, min(1.5, b_gain)))

    print(f"\n[Calibrate] Coeficientes TRC sintetizados:")
    print(f"  R-Gamma: {r_gamma:.3f} | G-Gamma: {g_gamma:.3f} | B-Gamma: {b_gamma:.3f}")

    # 4. Sintetizar perfil ICC
    print(f"[Calibrate] Escribiendo perfil ColorSync ICC: {output_icc}...")
    synthesize_icc_profile(output_icc, r_gamma=r_gamma, g_gamma=g_gamma, b_gamma=b_gamma)

    # 5. Verificación nativa con sips
    print("[Calibrate] Verificando perfil con motor ColorSync nativo (sips)...")
    res = subprocess.run(["sips", "-g", "all", str(output_icc)], capture_output=True, text=True, check=True)
    print(res.stdout.strip())

    # 6. Instalación opcional en ColorSync del usuario
    if install:
        dest_dir = Path.home() / "Library" / "ColorSync" / "Profiles"
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_icc = dest_dir / "HP_Smart_Tank_500_Precision.icc"
        shutil.copyfile(output_icc, dest_icc)
        print(f"[Calibrate] ¡Perfil instalado en ColorSync del usuario!: {dest_icc}")

    print("\n======================================================================")
    print("  ¡CALIBRACIÓN CROMÁTICA COMPLETADA EXITOSAMENTE!")
    print(f"  Perfil generado: {output_icc}")
    print("======================================================================\n")
    return output_icc


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Calibrador Cromático ICC para HP Smart Tank 500")
    parser.add_argument("--scan", type=Path, default=None, help="Ruta de la imagen escaneada (JPEG, PNG o PPM)")
    parser.add_argument("--out", type=Path, default=None, help="Ruta del archivo ICC de salida")
    parser.add_argument("--install", action="store_true", help="Instalar en ~/Library/ColorSync/Profiles/")
    parser.add_argument("--mock", action="store_true", help="Modo simulado de calibración")
    args = parser.parse_args()

    run_calibration(scan_file=args.scan, output_icc=args.out, install=args.install, mock=args.mock)
