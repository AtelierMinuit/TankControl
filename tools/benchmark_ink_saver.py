#!/usr/bin/env python3
"""Quantitative InkSaver & Eco-Print Benchmark Tool for HP Smart Tank 500.

Evaluates theoretical coverage reduction, luminance shifts, and perceptual Delta E
across all InkSaver algorithms: Eco25, Eco50, Eco75, EdgePreserve, DotGainGrid, EcoGrayscale.
"""

from __future__ import annotations

import json
import math
from pathlib import Path
from typing import Dict, List, Tuple

ROOT = Path(__file__).resolve().parents[1]


def srgb_to_linear(v: float) -> float:
    v = v / 255.0
    return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4


def rgb_to_xyz(r: int, g: int, b: int) -> Tuple[float, float, float]:
    rl = srgb_to_linear(r)
    gl = srgb_to_linear(g)
    bl = srgb_to_linear(b)
    x = rl * 0.4124564 + gl * 0.3575761 + bl * 0.1804375
    y = rl * 0.2126729 + gl * 0.7151522 + bl * 0.0721750
    z = rl * 0.0193339 + gl * 0.1191920 + bl * 0.9503041
    return x, y, z


def xyz_to_lab(x: float, y: float, z: float) -> Tuple[float, float, float]:
    xn, yn, zn = 0.95047, 1.00000, 1.08883

    def f(t: float) -> float:
        return t ** (1.0 / 3.0) if t > (6.0 / 29.0) ** 3 else (1.0 / 3.0) * ((29.0 / 6.0) ** 2) * t + (4.0 / 29.0)

    fx = f(x / xn)
    fy = f(y / yn)
    fz = f(z / zn)
    L = 116.0 * fy - 16.0
    a = 500.0 * (fx - fy)
    b = 200.0 * (fy - fz)
    return L, a, b


def delta_e76(lab1: Tuple[float, float, float], lab2: Tuple[float, float, float]) -> float:
    return math.sqrt((lab1[0] - lab2[0]) ** 2 + (lab1[1] - lab2[1]) ** 2 + (lab1[2] - lab2[2]) ** 2)


def theoretical_ink_coverage(rgb: Tuple[int, int, int]) -> float:
    """Theoretical ink coverage (0.0 = white/no ink, 1.0 = solid black)."""
    # Inverse intensity in sRGB space
    r, g, b = rgb
    c = (255 - r) / 255.0
    m = (255 - g) / 255.0
    y = (255 - b) / 255.0
    # Approximate total colorant density
    return (c + m + y) / 3.0


# Transformations as implemented in rastertopcl3gui.c
def apply_eco25(r: int, g: int, b: int) -> Tuple[int, int, int]:
    return (
        255 - int((255 - r) * 0.75),
        255 - int((255 - g) * 0.75),
        255 - int((255 - b) * 0.75),
    )


def apply_eco50(r: int, g: int, b: int) -> Tuple[int, int, int]:
    return (
        255 - int((255 - r) * 0.50),
        255 - int((255 - g) * 0.50),
        255 - int((255 - b) * 0.50),
    )


def apply_eco75(r: int, g: int, b: int) -> Tuple[int, int, int]:
    return (
        255 - int((255 - r) * 0.25),
        255 - int((255 - g) * 0.25),
        255 - int((255 - b) * 0.25),
    )


def apply_eco_grayscale(r: int, g: int, b: int) -> Tuple[int, int, int]:
    luma = int(0.299 * r + 0.587 * g + 0.114 * b)
    return (luma, luma, luma)


def apply_dot_gain_grid(r: int, g: int, b: int, x: int, y: int) -> Tuple[int, int, int]:
    # 2x2 dither pattern attenuating alternate pixels
    if (x + y) % 2 == 0:
        return (r, g, b)
    else:
        return apply_eco25(r, g, b)


def run_benchmark() -> Dict[str, Any]:
    # Test suite of representative patches
    patches = [
        ("Solid Black", (0, 0, 0)),
        ("Dark Gray (80%)", (51, 51, 51)),
        ("Mid Gray (50%)", (128, 128, 128)),
        ("Light Gray (20%)", (204, 204, 204)),
        ("Saturated Red", (255, 0, 0)),
        ("Saturated Green", (0, 255, 0)),
        ("Saturated Blue", (0, 0, 255)),
        ("Cyan", (0, 255, 255)),
        ("Magenta", (255, 0, 255)),
        ("Yellow", (255, 255, 0)),
    ]

    modes = {
        "Eco25": lambda r, g, b, x, y: apply_eco25(r, g, b),
        "Eco50": lambda r, g, b, x, y: apply_eco50(r, g, b),
        "Eco75": lambda r, g, b, x, y: apply_eco75(r, g, b),
        "EcoGrayscale": lambda r, g, b, x, y: apply_eco_grayscale(r, g, b),
        "DotGainGrid": lambda r, g, b, x, y: apply_dot_gain_grid(r, g, b, x, y),
    }

    results: Dict[str, Any] = {}

    for mode_name, transform in modes.items():
        patch_metrics = []
        total_orig_cov = 0.0
        total_trans_cov = 0.0
        delta_e_list = []

        for name, rgb in patches:
            orig_cov = theoretical_ink_coverage(rgb)
            orig_lab = xyz_to_lab(*rgb_to_xyz(*rgb))

            # Simulate a 10x10 patch
            patch_trans_cov = 0.0
            patch_delta_e = 0.0
            for py in range(10):
                for px in range(10):
                    t_rgb = transform(rgb[0], rgb[1], rgb[2], px, py)
                    patch_trans_cov += theoretical_ink_coverage(t_rgb)
                    t_lab = xyz_to_lab(*rgb_to_xyz(*t_rgb))
                    patch_delta_e += delta_e76(orig_lab, t_lab)

            patch_trans_cov /= 100.0
            patch_delta_e /= 100.0

            reduction_pct = ((orig_cov - patch_trans_cov) / orig_cov * 100.0) if orig_cov > 0.001 else 0.0

            patch_metrics.append({
                "patch": name,
                "orig_rgb": rgb,
                "theoretical_orig_coverage": round(orig_cov, 4),
                "theoretical_new_coverage": round(patch_trans_cov, 4),
                "reduction_pct": round(reduction_pct, 2),
                "delta_e": round(patch_delta_e, 2),
            })

            total_orig_cov += orig_cov
            total_trans_cov += patch_trans_cov
            delta_e_list.append(patch_delta_e)

        avg_reduction = ((total_orig_cov - total_trans_cov) / total_orig_cov * 100.0) if total_orig_cov > 0 else 0.0
        avg_delta_e = sum(delta_e_list) / len(delta_e_list)

        results[mode_name] = {
            "average_coverage_reduction_pct": round(avg_reduction, 2),
            "average_delta_e": round(avg_delta_e, 2),
            "max_delta_e": round(max(delta_e_list), 2),
            "patches": patch_metrics,
        }

    return results


def main() -> None:
    print("=== INKSAVER & ECO-PRINT QUANTITATIVE BENCHMARK ===")
    results = run_benchmark()

    print(f"\n{'Modo':<15} | {'Reducción Teórica':<20} | {'Promedio ΔE':<12} | {'Máximo ΔE':<12}")
    print("-" * 65)
    for mode, data in results.items():
        red = f"{data['average_coverage_reduction_pct']}%"
        de = f"{data['average_delta_e']}"
        mde = f"{data['max_delta_e']}"
        print(f"{mode:<15} | {red:<20} | {de:<12} | {mde:<12}")

    out_path = ROOT / "research" / "results" / "ink_saver_benchmark.json"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"\n[Benchmark] Datos completos exportados a: {out_path}")


if __name__ == "__main__":
    main()
