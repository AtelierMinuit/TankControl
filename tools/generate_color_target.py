#!/usr/bin/env python3
"""
generate_color_target.py
Generador de Carta de Calibración Cromática para HP Smart Tank 500 (macOS Apple Silicon).
Genera una carta de alta precisión con:
  - 4 dianas de registro fiducial en las esquinas para alineación y desvío automático (deskew).
  - 24 parches estándar Macbeth ColorChecker con valores colorimétricos teóricos sRGB / CIELAB.
  - Escala de grises lineal de 16 pasos para cuantificar ganancia de punto (dot-gain).
  - Rampas de densidad pura C, M, Y, K para absorción de tintas HP GT51 / GT52 / GT53.
Produce formatos listos para imprimir: PDF, PNG y TIFF nativos mediante sips (sin dependencias).
"""

from __future__ import annotations

import argparse
import tempfile
from pathlib import Path
import struct
import subprocess
import sys

# 24 Parches estándar Macbeth ColorChecker (Nombre, (R, G, B), (L*, a*, b*))
COLORCHECKER_PATCHES = [
    ("Dark Skin", (115, 82, 68), (37.986, 13.555, 14.059)),
    ("Light Skin", (194, 150, 130), (65.711, 18.130, 17.810)),
    ("Blue Sky", (98, 122, 157), (49.927, -4.880, -21.925)),
    ("Foliage", (87, 108, 67), (43.139, -13.095, 21.905)),
    ("Blue Flower", (133, 128, 177), (55.112, 8.844, -25.399)),
    ("Bluish Green", (103, 189, 170), (70.719, -33.397, -0.199)),
    ("Orange", (214, 126, 44), (62.661, 36.067, 57.096)),
    ("Purplish Blue", (80, 91, 166), (40.020, 10.410, -45.964)),
    ("Moderate Red", (193, 90, 99), (51.124, 48.239, 16.248)),
    ("Purple", (94, 60, 108), (30.325, 22.976, -21.587)),
    ("Yellow Green", (157, 188, 64), (72.532, -23.709, 57.255)),
    ("Orange Yellow", (224, 163, 46), (71.941, 19.364, 67.857)),
    ("Blue", (56, 61, 150), (28.778, 14.179, -50.297)),
    ("Green", (70, 148, 73), (55.261, -38.342, 31.370)),
    ("Red", (175, 54, 60), (42.101, 53.378, 28.190)),
    ("Yellow", (231, 199, 31), (81.733, 4.039, 79.819)),
    ("Magenta", (187, 86, 149), (51.935, 49.986, -14.574)),
    ("Cyan", (8, 133, 161), (51.038, -28.631, -28.638)),
    ("White 9.5", (243, 243, 242), (96.539, -0.425, 1.186)),
    ("Neutral 8", (200, 200, 200), (81.222, -0.638, -0.335)),
    ("Neutral 6.5", (160, 160, 160), (66.766, -0.734, -0.504)),
    ("Neutral 5", (122, 122, 121), (50.867, -0.153, -0.270)),
    ("Neutral 3.5", (85, 85, 85), (35.656, -0.421, -1.231)),
    ("Black 2", (52, 52, 52), (20.461, -0.079, -0.973)),
]


class Canvas:
    """Lienzo de dibujo en memoria RGB de 24 bits con soporte de primitivas gráficas."""

    def __init__(self, width: int, height: int, bg_color: tuple[int, int, int] = (255, 255, 255)) -> None:
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 3)
        self.fill_rect(0, 0, width, height, bg_color)

    def set_pixel(self, x: int, y: int, color: tuple[int, int, int]) -> None:
        if 0 <= x < self.width and 0 <= y < self.height:
            idx = (y * self.width + x) * 3
            self.pixels[idx : idx + 3] = color

    def fill_rect(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int]) -> None:
        x0 = max(0, x)
        y0 = max(0, y)
        x1 = min(self.width, x + w)
        y1 = min(self.height, y + h)
        if x1 <= x0 or y1 <= y0:
            return

        row_chunk = bytes(color) * (x1 - x0)
        chunk_len = len(row_chunk)
        for row in range(y0, y1):
            idx = (row * self.width + x0) * 3
            self.pixels[idx : idx + chunk_len] = row_chunk

    def draw_rect_outline(self, x: int, y: int, w: int, h: int, color: tuple[int, int, int], thickness: int = 1) -> None:
        self.fill_rect(x, y, w, thickness, color)  # Top
        self.fill_rect(x, y + h - thickness, w, thickness, color)  # Bottom
        self.fill_rect(x, y, thickness, h, color)  # Left
        self.fill_rect(x + w - thickness, y, thickness, h, color)  # Right

    def draw_fiducial_target(self, cx: int, cy: int, radius: int = 35) -> None:
        """Dibuja una diana fiducial de alta precisión (círculo con cuadrantes opuestos blanco/negro)."""
        r2 = radius * radius
        inner_r2 = (radius // 3) * (radius // 3)
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                dist2 = dx * dx + dy * dy
                if dist2 <= r2:
                    # Cuadrantes opuestos (tablero de ajedrez polar)
                    in_q1_or_q3 = (dx >= 0 and dy >= 0) or (dx < 0 and dy < 0)
                    color = (0, 0, 0) if in_q1_or_q3 else (255, 255, 255)
                    # Círculo concéntrico exterior
                    if dist2 > (radius - 2) * (radius - 2):
                        color = (0, 0, 0)
                    self.set_pixel(cx + dx, cy + dy, color)

        # Cruz central
        cross_len = radius + 15
        self.fill_rect(cx - cross_len, cy - 1, cross_len * 2 + 1, 3, (0, 0, 0))
        self.fill_rect(cx - 1, cy - cross_len, 3, cross_len * 2 + 1, (0, 0, 0))

    def save_ppm(self, filepath: Path) -> None:
        header = f"P6\n{self.width} {self.height}\n255\n".encode("ascii")
        with open(filepath, "wb") as f:
            f.write(header)
            f.write(self.pixels)


def generate_color_target(dpi: int = 300, output_dir: Path | None = None) -> tuple[Path, Path, Path]:
    """Genera la carta en A4 (8.27 x 11.69 pulgadas) a la resolución indicada."""
    if output_dir is None:
        output_dir = Path(tempfile.mkdtemp(prefix="hp-color-target-"))
    output_dir.mkdir(parents=True, exist_ok=True)

    width = int(8.27 * dpi)
    height = int(11.69 * dpi)
    canvas = Canvas(width, height, (255, 255, 255))

    # 1. Dianas fiduciales en las 4 esquinas (con margen de 0.6 pulgadas)
    margin = int(0.65 * dpi)
    radius = int(0.20 * dpi)
    fids = [
        (margin, margin),
        (width - margin, margin),
        (margin, height - margin),
        (width - margin, height - margin),
    ]
    for cx, cy in fids:
        canvas.draw_fiducial_target(cx, cy, radius)

    # 2. Marco perimetral
    canvas.draw_rect_outline(margin, margin, width - 2 * margin, height - 2 * margin, (180, 180, 180), thickness=2)

    # 3. Matriz 24 Parches ColorChecker (4 filas x 6 columnas)
    grid_x0 = int(1.2 * dpi)
    grid_y0 = int(1.3 * dpi)
    patch_w = int(0.95 * dpi)
    patch_h = int(0.95 * dpi)
    gap_x = int(0.08 * dpi)
    gap_y = int(0.08 * dpi)

    for idx, (name, srgb, lab) in enumerate(COLORCHECKER_PATCHES):
        row = idx // 6
        col = idx % 6
        px = grid_x0 + col * (patch_w + gap_x)
        py = grid_y0 + row * (patch_h + gap_y)

        # Relleno del parche
        canvas.fill_rect(px, py, patch_w, patch_h, srgb)
        # Borde sutil
        canvas.draw_rect_outline(px, py, patch_w, patch_h, (0, 0, 0), thickness=1)

    # 4. Escala de grises lineal de 16 pasos (dot gain / curvas TRC)
    gray_y0 = grid_y0 + 4 * (patch_h + gap_y) + int(0.4 * dpi)
    gray_w = int(patch_w * 6 + gap_x * 5)
    step_w = gray_w // 16
    for step in range(16):
        val = int(255 * (step / 15.0))
        gx = grid_x0 + step * step_w
        canvas.fill_rect(gx, gray_y0, step_w, int(0.5 * dpi), (val, val, val))
        canvas.draw_rect_outline(gx, gray_y0, step_w, int(0.5 * dpi), (0, 0, 0), thickness=1)

    # 5. Rampas de densidad de tinta pura CMYK (5 niveles por tinta: 0, 25, 50, 75, 100%)
    cmyk_y0 = gray_y0 + int(0.7 * dpi)
    cmyk_colors = [
        ("Cyan (GT52)", lambda s: (int(255 - s * 255), 255, 255)),
        ("Magenta (GT52)", lambda s: (255, int(255 - s * 255), 255)),
        ("Yellow (GT52)", lambda s: (255, 255, int(255 - s * 255))),
        ("Black (GT51)", lambda s: (int(255 - s * 255), int(255 - s * 255), int(255 - s * 255))),
    ]
    step_dens_w = gray_w // 5
    for c_idx, (cname, rgb_func) in enumerate(cmyk_colors):
        cy = cmyk_y0 + c_idx * int(0.4 * dpi)
        for d_step in range(5):
            factor = d_step / 4.0
            col_rgb = rgb_func(factor)
            dx = grid_x0 + d_step * step_dens_w
            canvas.fill_rect(dx, cy, step_dens_w, int(0.32 * dpi), col_rgb)
            canvas.draw_rect_outline(dx, cy, step_dens_w, int(0.32 * dpi), (100, 100, 100), thickness=1)

    # 6. Guardar archivo PPM nativo
    ppm_path = output_dir / "HP_Smart_Tank_Color_Target.ppm"
    png_path = output_dir / "HP_Smart_Tank_Color_Target.png"
    pdf_path = output_dir / "HP_Smart_Tank_Color_Target.pdf"

    print(f"[ColorTarget] Guardando matriz de píxeles: {ppm_path} ({width}x{height} px)...")
    canvas.save_ppm(ppm_path)

    # 7. Convertir con sips a PNG y PDF listos para imprimir
    print(f"[ColorTarget] Convirtiendo a PNG y PDF mediante sips...")
    subprocess.run(["sips", "-s", "format", "png", str(ppm_path), "--out", str(png_path)], check=True)
    subprocess.run(["sips", "-s", "format", "pdf", str(ppm_path), "--out", str(pdf_path)], check=True)

    print(f"[ColorTarget] ¡Archivos generados exitosamente!")
    print(f"  - PDF para imprimir: {pdf_path}")
    print(f"  - PNG: {png_path}")
    return ppm_path, png_path, pdf_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generador de Carta de Calibración Cromática para HP Smart Tank 500")
    parser.add_argument("--dpi", type=int, default=300, help="Resolución en DPI (default: 300)")
    parser.add_argument("--outdir", type=Path, default=None, help="Directorio de destino")
    args = parser.parse_args()

    generate_color_target(dpi=args.dpi, output_dir=args.outdir)
