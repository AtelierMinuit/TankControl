import subprocess
import time
import os
import hashlib
from pathlib import Path

TOOL = "research/builds/antigravity-offline-audit/hp_scan"
OUT_DIR = Path("research/hardware-validation/20260905-110110-master/scan_advanced")
OUT_DIR.mkdir(parents=True, exist_ok=True)
REPORT = OUT_DIR / "advanced_scan_report.txt"

tests = [
    ("300_color", ["--output", str(OUT_DIR / "scan_300_color.jpg"), "--resolution", "300", "--mode", "Color"]),
    ("300_gray", ["--output", str(OUT_DIR / "scan_300_gray.jpg"), "--resolution", "300", "--mode", "Gray"]),
    ("300_crop", ["--output", str(OUT_DIR / "scan_300_crop.jpg"), "--resolution", "300", "--mode", "Color", "--x", "200", "--y", "200", "--width", "1000", "--height", "1000"]),
    ("600_color", ["--output", str(OUT_DIR / "scan_600_color.jpg"), "--resolution", "600", "--mode", "Color"]),
]

print("======================================================================")
print("  FASES 10-12 — ESCÁNER AVANZADO (300 DPI, CROP, 600 DPI)")
print("  Hardware: HP Smart Tank 500 CIS Platen")
print("======================================================================")

with open(REPORT, "w", encoding="utf-8") as f_out:
    f_out.write("# VALIDACIÓN DE MODOS AVANZADOS DE ESCANEO\n")
    f_out.write("# Hardware: HP Smart Tank 500 (VID 03f0, PID 2b54, Serial CN1924S1W7)\n\n")

    for name, args in tests:
        out_file = Path(args[1])
        print(f"\n[Test {name}] Ejecutando con {args}...")
        t0 = time.perf_counter()
        proc = subprocess.run([TOOL] + args, capture_output=True, text=True)
        dt = time.perf_counter() - t0

        if proc.returncode != 0:
            err_line = f"  {name}: FALLO (code {proc.returncode}) en {dt:.1f}s: {proc.stderr.strip()}"
            print(err_line)
            f_out.write(err_line + "\n")
            continue

        if not out_file.exists() or out_file.stat().st_size < 100:
            err_line = f"  {name}: FALLO - archivo no creado o vacío"
            print(err_line)
            f_out.write(err_line + "\n")
            continue

        data = out_file.read_bytes()
        soi = data[:2].hex()
        eoi = data[-2:].hex()
        sha = hashlib.sha256(data).hexdigest()
        size = len(data)

        # Usar sips para extraer dimensiones reales
        sips_proc = subprocess.run(["sips", "-g", "all", str(out_file)], capture_output=True, text=True)
        sips_out = sips_proc.stdout

        res_line = f"  {name}: PASS | {dt:.1f}s | {size} bytes | SOI={soi}, EOI={eoi} | SHA-256: {sha}"
        print(res_line)
        f_out.write(res_line + "\n")
        f_out.write(f"  Detalle sips:\n{sips_out}\n---\n")
        time.sleep(1.0)

print(f"\nReporte guardado en: {REPORT}")
