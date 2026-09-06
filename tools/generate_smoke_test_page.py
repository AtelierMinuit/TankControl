#!/usr/bin/env python3
"""
generate_smoke_test_page.py
Genera una página de prueba mínima, conservadora y estandarizada (A4, 300 DPI)
para validación física en hardware HP Smart Tank 500.

Incluye:
- Texto de cabecera con Session ID y Timestamp
- Línea de borde perimetral (márgenes seguros)
- Bloques de color calibrados: Negro, Rojo, Verde, Azul, Cian, Magenta, Amarillo
- Escala de grises (100%, 75%, 50%, 25%, 10%)
- Patrón de líneas finas para verificación de alineación y resolución
- Conversión nativa a PDF mediante Apple sips (0 dependencias externas)
"""

from __future__ import annotations

import argparse
from datetime import datetime
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]


# Mini 5x7 bitmap font for rendering text without PIL/FreeType
FONT_5X7 = {
    ' ': [0x00, 0x00, 0x00, 0x00, 0x00],
    '-': [0x08, 0x08, 0x08, 0x08, 0x08],
    '_': [0x40, 0x40, 0x40, 0x40, 0x40],
    ':': [0x00, 0x36, 0x36, 0x00, 0x00],
    '.': [0x00, 0x60, 0x60, 0x00, 0x00],
    '/': [0x20, 0x10, 0x08, 0x04, 0x02],
    '|': [0x00, 0x7f, 0x7f, 0x00, 0x00],
    '0': [0x3e, 0x51, 0x49, 0x45, 0x3e],
    '1': [0x00, 0x42, 0x7f, 0x40, 0x00],
    '2': [0x42, 0x61, 0x51, 0x49, 0x46],
    '3': [0x21, 0x41, 0x45, 0x4b, 0x31],
    '4': [0x18, 0x14, 0x12, 0x7f, 0x10],
    '5': [0x27, 0x45, 0x45, 0x45, 0x39],
    '6': [0x3c, 0x4a, 0x49, 0x49, 0x30],
    '7': [0x01, 0x71, 0x09, 0x05, 0x03],
    '8': [0x36, 0x49, 0x49, 0x49, 0x36],
    '9': [0x06, 0x49, 0x49, 0x29, 0x1e],
    'A': [0x7e, 0x11, 0x11, 0x11, 0x7e],
    'B': [0x7f, 0x49, 0x49, 0x49, 0x36],
    'C': [0x3e, 0x41, 0x41, 0x41, 0x22],
    'D': [0x7f, 0x41, 0x41, 0x22, 0x1c],
    'E': [0x7f, 0x49, 0x49, 0x49, 0x41],
    'F': [0x7f, 0x09, 0x09, 0x09, 0x01],
    'G': [0x3e, 0x41, 0x49, 0x49, 0x7a],
    'H': [0x7f, 0x08, 0x08, 0x08, 0x7f],
    'I': [0x00, 0x41, 0x7f, 0x41, 0x00],
    'J': [0x20, 0x40, 0x41, 0x3f, 0x01],
    'K': [0x7f, 0x08, 0x14, 0x22, 0x41],
    'L': [0x7f, 0x40, 0x40, 0x40, 0x40],
    'M': [0x7f, 0x02, 0x0c, 0x02, 0x7f],
    'N': [0x7f, 0x04, 0x08, 0x10, 0x7f],
    'O': [0x3e, 0x41, 0x41, 0x41, 0x3e],
    'P': [0x7f, 0x09, 0x09, 0x09, 0x06],
    'Q': [0x3e, 0x41, 0x51, 0x21, 0x5e],
    'R': [0x7f, 0x09, 0x19, 0x29, 0x46],
    'S': [0x46, 0x49, 0x49, 0x49, 0x31],
    'T': [0x01, 0x01, 0x7f, 0x01, 0x01],
    'U': [0x3f, 0x40, 0x40, 0x40, 0x3f],
    'V': [0x1f, 0x20, 0x40, 0x20, 0x1f],
    'W': [0x7f, 0x20, 0x18, 0x20, 0x7f],
    'X': [0x63, 0x14, 0x08, 0x14, 0x63],
    'Y': [0x07, 0x08, 0x70, 0x08, 0x07],
    'Z': [0x61, 0x51, 0x49, 0x45, 0x43],
}


class SmokeCanvas:
    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.pixels = bytearray(width * height * 3)
        # Initialize with white (255, 255, 255)
        for i in range(len(self.pixels)):
            self.pixels[i] = 255

    def fill_rect(self, x0: int, y0: int, w: int, h: int, color: tuple[int, int, int]) -> None:
        r, g, b = color
        for y in range(max(0, y0), min(self.height, y0 + h)):
            row_start = y * self.width * 3
            for x in range(max(0, x0), min(self.width, x0 + w)):
                idx = row_start + x * 3
                self.pixels[idx] = r
                self.pixels[idx + 1] = g
                self.pixels[idx + 2] = b

    def draw_rect(self, x0: int, y0: int, w: int, h: int, color: tuple[int, int, int], thickness: int = 1) -> None:
        self.fill_rect(x0, y0, w, thickness, color)
        self.fill_rect(x0, y0 + h - thickness, w, thickness, color)
        self.fill_rect(x0, y0, thickness, h, color)
        self.fill_rect(x0 + w - thickness, y0, thickness, h, color)

    def draw_char(self, char: str, x0: int, y0: int, color: tuple[int, int, int], scale: int = 2) -> int:
        col_patterns = FONT_5X7.get(char.upper(), FONT_5X7[' '])
        for col_idx, bits in enumerate(col_patterns):
            for row_idx in range(7):
                if (bits >> row_idx) & 1:
                    self.fill_rect(x0 + col_idx * scale, y0 + row_idx * scale, scale, scale, color)
        return (len(col_patterns) + 1) * scale

    def draw_text(self, text: str, x0: int, y0: int, color: tuple[int, int, int], scale: int = 2) -> None:
        cur_x = x0
        for ch in text:
            cur_x += self.draw_char(ch, cur_x, y0, color, scale)

    def write_ppm(self, path: Path) -> None:
        header = f"P6\n{self.width} {self.height}\n255\n".encode("ascii")
        with open(path, "wb") as f:
            f.write(header)
            f.write(self.pixels)


def generate_smoke_test_pdf(output_path: Path, session_id: str = "OFFLINE-AUDIT") -> Path:
    # A4 dimensions at 300 DPI: 2480 x 3508 pixels
    width, height = 2480, 3508
    canvas = SmokeCanvas(width, height)

    # 1. Borde perimetral (Margen físico seguro: 5 mm = 59 píxeles)
    margin = 59
    canvas.draw_rect(margin, margin, width - 2 * margin, height - 2 * margin, (0, 0, 0), thickness=4)

    # 2. Textos de Cabecera y Trazabilidad
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    canvas.draw_text("HP SMART TANK 500 - HARDWARE SMOKE TEST", margin + 60, margin + 80, (0, 0, 0), scale=5)
    canvas.draw_text(f"SESSION ID: {session_id}", margin + 60, margin + 140, (50, 50, 50), scale=3)
    canvas.draw_text(f"TIMESTAMP:  {timestamp}", margin + 60, margin + 175, (50, 50, 50), scale=3)
    canvas.draw_text("TARGET:     VID 03F0 PID 2B54 | P15_CISS ENGINE | USB ONLY", margin + 60, margin + 210, (50, 50, 50), scale=3)
    canvas.draw_text("BASELINE:   A4 PLAIN | 600 DPI NORMAL | PCL3GUI MODE 10", margin + 60, margin + 245, (50, 50, 50), scale=3)

    # Línea separadora
    canvas.fill_rect(margin + 60, margin + 290, width - 2 * margin - 120, 4, (0, 0, 0))

    # 3. Bloques de Color Primario y Secundario en Espacio sRGB
    canvas.draw_text("1. PARCHES DE PROCESO sRGB (EMULACION CROMATICA TIJ 2.X):", margin + 60, margin + 330, (0, 0, 0), scale=3)
    colors = [
        ("sRGB BLACK", (0, 0, 0)),
        ("sRGB RED", (255, 0, 0)),
        ("sRGB GREEN", (0, 200, 0)),
        ("sRGB BLUE", (0, 0, 255)),
        ("PROCESS CYAN", (0, 200, 255)),
        ("PROCESS MAGENTA", (255, 0, 180)),
        ("PROCESS YELLOW", (255, 220, 0)),
    ]
    patch_w = 280
    patch_h = 240
    patch_gap = 40
    start_x = margin + 60
    start_y = margin + 370

    for idx, (cname, rgb) in enumerate(colors):
        px = start_x + (idx % 4) * (patch_w + patch_gap)
        py = start_y + (idx // 4) * (patch_h + 80)
        canvas.fill_rect(px, py, patch_w, patch_h, rgb)
        canvas.draw_rect(px, py, patch_w, patch_h, (0, 0, 0), thickness=2)
        canvas.draw_text(cname, px + 10, py + patch_h + 15, (0, 0, 0), scale=2)

    # 4. Escala de Grises sRGB Neutra
    gray_y = start_y + 2 * (patch_h + 80) + 40
    canvas.draw_text("2. ESCALA TONAL sRGB NEUTRA (RAMPA 100% A 10%):", margin + 60, gray_y, (0, 0, 0), scale=3)
    gray_levels = [
        ("100%", (0, 0, 0)),
        ("75%", (64, 64, 64)),
        ("50%", (128, 128, 128)),
        ("25%", (192, 192, 192)),
        ("10%", (230, 230, 230)),
    ]
    gw = 420
    gh = 160
    for idx, (glabel, grgb) in enumerate(gray_levels):
        gx = margin + 60 + idx * gw
        gy = gray_y + 40
        canvas.fill_rect(gx, gy, gw - 15, gh, grgb)
        canvas.draw_rect(gx, gy, gw - 15, gh, (100, 100, 100), thickness=2)
        canvas.draw_text(glabel, gx + 20, gy + gh + 15, (0, 0, 0), scale=2)

    # 5. Patrón de Resolución y Alineación de Carro (Líneas 1px, 2px, 4px)
    grid_y = gray_y + gh + 100
    canvas.draw_text("3. LINEAS DE RESOLUCION Y ALINEACION:", margin + 60, grid_y, (0, 0, 0), scale=3)
    line_box_y = grid_y + 40
    canvas.draw_rect(margin + 60, line_box_y, width - 2 * margin - 120, 400, (200, 200, 200), thickness=1)

    # Líneas verticales alternas
    for lx in range(margin + 100, width - margin - 100, 30):
        canvas.fill_rect(lx, line_box_y + 20, 2, 160, (0, 0, 0))

    # Líneas horizontales alternas
    for ly in range(line_box_y + 210, line_box_y + 370, 25):
        canvas.fill_rect(margin + 100, ly, width - 2 * margin - 200, 2, (0, 0, 0))

    # 6. Pie de Página y Advertencia de Seguridad
    footer_y = height - margin - 120
    canvas.fill_rect(margin + 60, footer_y, width - 2 * margin - 120, 2, (0, 0, 0))
    canvas.draw_text("ESTA PAGINA ES UNA PRUEBA MINIMA PARA CORRELACIONAR EL STREAM PCL3GUI CON LA EXPULSION FISICA.", margin + 60, footer_y + 20, (80, 80, 80), scale=2)
    canvas.draw_text("AUDITADO Y GENERADO POR ANTIGRAVITY MAC OS DRIVER SUITE - NO CONTRAVIENE GARANTIA OEM.", margin + 60, footer_y + 50, (80, 80, 80), scale=2)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("wb", suffix=".ppm", delete=False) as tmp_ppm:
        ppm_file = Path(tmp_ppm.name)

    try:
        canvas.write_ppm(ppm_file)
        # Convert to PDF with macOS sips
        subprocess.run(["sips", "-s", "format", "pdf", str(ppm_file), "--out", str(output_path)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    finally:
        if ppm_file.exists():
            ppm_file.unlink()

    return output_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generador de página de prueba de hardware para HP Smart Tank 500")
    parser.add_argument("--output", type=Path, default=ROOT / "research" / "hardware-validation" / "hardware-smoke-test.pdf", help="Ruta de destino del PDF")
    parser.add_argument("--session-id", type=str, default="OFFLINE-AUDIT-2026", help="Identificador único de sesión")
    args = parser.parse_args()

    out = generate_smoke_test_pdf(args.output, session_id=args.session_id)
    print(f"[SmokePage] Página de prueba generada exitosamente en: {out} ({out.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
