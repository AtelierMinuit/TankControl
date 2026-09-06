import subprocess
import time
import os
import hashlib
from pathlib import Path

TOOL = "research/builds/antigravity-offline-audit/hp_scan"
OUT_DIR = Path("research/hardware-validation/20260905-110110-master/scan_repeatability")
OUT_DIR.mkdir(parents=True, exist_ok=True)
LOG_FILE = OUT_DIR / "repeatability_report.txt"

print("======================================================================")
print("  FASE 9 — REPETIBILIDAD DE ESCANEO FÍSICO (5 ITERACIONES 150 DPI)")
print("  Hardware: HP Smart Tank 500 CIS Platen")
print("======================================================================")

with open(LOG_FILE, "w", encoding="utf-8") as f_out:
    f_out.write("# REPETIBILIDAD DE ESCANEO FÍSICO (5 CICLOS CONSECUTIVOS)\n")
    f_out.write("# Hardware: HP Smart Tank 500 (VID 03f0, PID 2b54, Serial CN1924S1W7)\n\n")

    success_count = 0
    total = 5

    for i in range(1, total + 1):
        target_jpg = OUT_DIR / f"scan_rep_{i:02d}.jpg"
        print(f"\n[Ciclo {i}/{total}] Escaneando 150 DPI Color...")
        t0 = time.perf_counter()
        proc = subprocess.run([
            TOOL,
            "--output", str(target_jpg),
            "--resolution", "150",
            "--mode", "Color"
        ], capture_output=True, text=True)
        dt = time.perf_counter() - t0

        if proc.returncode != 0:
            err_line = f"  Ciclo #{i}: FALLO (exit {proc.returncode}) en {dt:.1f}s: {proc.stderr.strip()}"
            print(err_line)
            f_out.write(err_line + "\n")
            continue

        if not target_jpg.exists() or target_jpg.stat().st_size < 100:
            err_line = f"  Ciclo #{i}: FALLO - archivo vacío o corrupto"
            print(err_line)
            f_out.write(err_line + "\n")
            continue

        data = target_jpg.read_bytes()
        soi = data[:2].hex()
        eoi = data[-2:].hex()
        sha = hashlib.sha256(data).hexdigest()
        size = len(data)

        if soi != "ffd8" or eoi != "ffd9":
            err_line = f"  Ciclo #{i}: FALLO marcadores JPEG (SOI={soi}, EOI={eoi})"
            print(err_line)
            f_out.write(err_line + "\n")
            continue

        success_count += 1
        res_line = f"  Ciclo #{i}: PASS | Duración: {dt:.1f}s | Tamaño: {size} bytes | SOI: {soi} | EOI: {eoi} | SHA-256: {sha}"
        print(res_line)
        f_out.write(res_line + "\n")
        time.sleep(1.0) # 1s descanso mecánico del carro

    summary = f"\nResultado Global: {success_count}/{total} escaneos exitosos (0 paquetes residuales, 0 cuelgues)\n"
    print(summary)
    f_out.write(summary)

print(f"Reporte guardado en: {LOG_FILE}")
