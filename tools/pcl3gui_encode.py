#!/usr/bin/env python3
"""
pcl3gui_encode.py
Codificador nativo e independiente de PCL3GUI Mode 10 para HP Smart Tank 500 series.
Convierte imágenes RGB (PPM o CUPS Raster) directamente en streams PCL3GUI sin dependencias de HPLIP.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
import io
from pathlib import Path
import struct
import sys

# Constantes PCL / PJL verificadas
UEL = b"\x1b%-12345X"
PJL_HEADER = b"@PJL SET STRINGCODESET=UTF8\n@PJL ENTER LANGUAGE=PCL3GUI\n"
PCL_RESET = b"\x1bE"
MEDIA_PRELOAD = b"\x1b&l-2H"
GRAPHICS_START = b"\x1b*r1A"
GRAPHICS_END = b"\x1b*rC"
PAGE_EJECT = b"\x1b&l0H\x0c"
PJL_EXIT = b"\x1b%-12345X@PJL EOJ\n\x1b%-12345X"

# CRD sequence para color Mode 10 (24-bit sRGB)
CRD_COLOR_MODE10 = b"\x1b*g12W\x06\x07\x00\x01\x00\x00\x00\x00\x0a\x01\x20\x01"

# Diccionario de tamaños de papel (PCL Media ID)
PCL_MEDIA_IDS = {
    "letter": 2,
    "legal": 3,
    "executive": 1,
    "a4": 26,
    "a5": 25,
    "b5": 100,
    "4x6": 71,
    "5x7": 72,
}


def raw_pixel(rgb: bytes | tuple[int, int, int]) -> bytes:
    """Codifica un pixel de 24-bit RGB (el bit 0 de azul se trunca a 0)."""
    r, g, b = rgb[0], rgb[1], rgb[2]
    packed = (r << 16) | (g << 8) | (b & 0xFE)
    return (packed >> 1).to_bytes(3, "big")


def short_delta(dr: int, dg: int, db: int) -> bytes:
    """Codifica un pixel Short Delta relativo a la fila semilla (2 bytes)."""
    val = 0x8000 | ((dr & 0x1F) << 10) | ((dg & 0x1F) << 5) | ((db // 2) & 0x1F)
    return val.to_bytes(2, "big")


def encode_mode10_row(cur_row: bytes, seed_row: bytes, width: int) -> bytes:
    """Comprime una fila de width pixeles en Mode 10 contra la fila semilla."""
    if cur_row == seed_row:
        return b""

    out = bytearray()
    x = 0
    while x < width:
        # 1. Contar pixeles idénticos a la fila semilla
        seed_copy = 0
        while x < width and cur_row[x * 3 : x * 3 + 3] == seed_row[x * 3 : x * 3 + 3]:
            seed_copy += 1
            x += 1

        if x >= width:
            break

        # 2. Segmento con diferencias a partir de x
        cur_px = cur_row[x * 3 : x * 3 + 3]
        rle_run = 1
        while x + rle_run < width and cur_row[(x + rle_run) * 3 : (x + rle_run) * 3 + 3] == cur_px:
            rle_run += 1

        if rle_run >= 2:
            # Comando RLE: Bit 7=1, Bits 6-5=00 (New Pixel)
            cmd = 0x80 | (min(3, seed_copy) << 3) | min(7, rle_run - 2)
            out.append(cmd)

            sc_rem = seed_copy - 3
            while sc_rem >= 0:
                if sc_rem >= 255:
                    out.append(255)
                    sc_rem -= 255
                else:
                    out.append(sc_rem)
                    break

            seed_px = seed_row[x * 3 : x * 3 + 3]
            dr = cur_px[0] - seed_px[0]
            dg = cur_px[1] - seed_px[1]
            db = cur_px[2] - seed_px[2]
            if -16 <= dr <= 15 and -16 <= dg <= 15 and -32 <= db <= 30 and (db % 2 == 0):
                out.extend(short_delta(dr, dg, db))
            else:
                out.extend(raw_pixel(cur_px))

            rc_rem = (rle_run - 2) - 7
            while rc_rem >= 0:
                if rc_rem >= 255:
                    out.append(255)
                    rc_rem -= 255
                else:
                    out.append(rc_rem)
                    break
            x += rle_run
        else:
            # Comando Literal: Bit 7=0, Bits 6-5=00 (New Pixel)
            cmd = 0x00 | (min(3, seed_copy) << 3) | 0
            out.append(cmd)

            sc_rem = seed_copy - 3
            while sc_rem >= 0:
                if sc_rem >= 255:
                    out.append(255)
                    sc_rem -= 255
                else:
                    out.append(sc_rem)
                    break

            seed_px = seed_row[x * 3 : x * 3 + 3]
            dr = cur_px[0] - seed_px[0]
            dg = cur_px[1] - seed_px[1]
            db = cur_px[2] - seed_px[2]
            if -16 <= dr <= 15 and -16 <= dg <= 15 and -32 <= db <= 30 and (db % 2 == 0):
                out.extend(short_delta(dr, dg, db))
            else:
                out.extend(raw_pixel(cur_px))
            x += 1

    return bytes(out)


def encode_page(rows: list[bytes], width: int, height: int, dpi: int = 600, media: str = "a4") -> bytes:
    """Genera un stream completo PCL3GUI Mode 10 para una página."""
    out = io.BytesIO()
    media_id = PCL_MEDIA_IDS.get(media.lower(), 26)

    # 1. Cabecera PJL y PCL
    out.write(UEL)
    out.write(PJL_HEADER)
    out.write(PCL_RESET)
    out.write(f"\x1b&l1H\x1b&l0M\x1b&l{media_id}A\x1b*o1M".encode("ascii"))
    out.write(b"\x1b*o5W\x0d\x03\x00\x00\x00")
    out.write(CRD_COLOR_MODE10)
    out.write(f"\x1b&u{dpi}D".encode("ascii"))
    out.write(f"\x1b*t{dpi}R".encode("ascii"))
    out.write(f"\x1b*r{width}S".encode("ascii"))
    out.write(MEDIA_PRELOAD)
    out.write(GRAPHICS_START)

    seed_row = bytes([255]) * (width * 3)
    white_row = seed_row
    blank_rows = 0

    for y in range(height):
        row = rows[y] if y < len(rows) else white_row
        if row == white_row:
            blank_rows += 1
            continue

        # Si había filas blancas previas, emitir salto vertical y reiniciar semilla a blanco
        if blank_rows > 0:
            out.write(f"\x1b*b{blank_rows}Y".encode("ascii"))
            blank_rows = 0
            seed_row = white_row

        # Comprimir fila contra la semilla
        payload = encode_mode10_row(row, seed_row, width)
        out.write(f"\x1b*b{len(payload)}W".encode("ascii") + payload)
        seed_row = row

    # Cierre de gráficos y página
    out.write(GRAPHICS_END)
    out.write(PAGE_EJECT)
    out.write(PJL_EXIT)

    return out.getvalue()


def read_ppm(stream: io.BufferedReader) -> tuple[int, int, list[bytes]]:
    """Lee una imagen PPM (P6 binaria)."""
    header = stream.readline().strip()
    if header != b"P6":
        raise ValueError(f"Formato no soportado: {header}. Se requiere P6 (PPM binario).")

    line = stream.readline()
    while line.startswith(b"#"):
        line = stream.readline()

    parts = line.split()
    while len(parts) < 2:
        parts.extend(stream.readline().split())

    width, height = int(parts[0]), int(parts[1])
    maxval = int(stream.readline().strip())
    if maxval != 255:
        raise ValueError(f"Maxval {maxval} no soportado (se requiere 255).")

    rows = []
    for _ in range(height):
        row_data = stream.read(width * 3)
        if len(row_data) < width * 3:
            row_data = row_data.ljust(width * 3, b"\xff")
        rows.append(row_data)

    return width, height, rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Codificador PCL3GUI Mode 10 para HP Smart Tank 500")
    parser.add_argument("input", nargs="?", type=Path, help="Archivo de entrada PPM (o stdin si se omite)")
    parser.add_argument("-o", "--output", type=Path, help="Archivo de salida PCL3GUI (o stdout si se omite)")
    parser.add_argument("--dpi", type=int, default=600, choices=[600, 1200], help="Resolución en DPI (default: 600)")
    parser.add_argument("--media", type=str, default="a4", help="Tamaño de papel (a4, letter, etc.)")
    args = parser.parse_args()

    if args.input:
        with args.input.open("rb") as f:
            width, height, rows = read_ppm(f)
    else:
        width, height, rows = read_ppm(sys.stdin.buffer)

    pcl_data = encode_page(rows, width, height, dpi=args.dpi, media=args.media)

    if args.output:
        args.output.write_bytes(pcl_data)
        sys.stderr.write(f"Stream PCL3GUI generado exitosamente ({len(pcl_data)} bytes) en {args.output}\n")
    else:
        sys.stdout.buffer.write(pcl_data)

    return 0


if __name__ == "__main__":
    sys.exit(main())
