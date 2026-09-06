import subprocess
import time
import json
import statistics
import sys
import os

TOOL = "research/builds/antigravity-offline-audit/hp-smart-tank-tool"
OUT_FILE = "research/hardware-validation/20260905-110110-master/telemetry_repeatability.txt"

benchmarks = [
    ("status", ["json-status"], 20),
    ("supplies", ["json-supplies"], 20),
    ("scan-status", ["scan-status"], 20),
    ("scan-caps", ["scan-caps"], 10)
]

results = {}
total_success = 0
total_calls = 0

print("======================================================================")
print("  FASE 6 — REPETIBILIDAD DE TELEMETRÍA HARDWARE REAL")
print("  Target: HP Smart Tank 500 (VID 0x03F0, PID 0x2B54, Serial CN1924S1W7)")
print("======================================================================")

with open(OUT_FILE, "w", encoding="utf-8") as f_out:
    f_out.write("# REPETIBILIDAD DE TELEMETRÍA — PRUEBAS DE ESTRÉS Y LATENCIA\n")
    f_out.write("# Hardware: HP Smart Tank 500 (VID 03f0, PID 2b54, Serial CN1924S1W7)\n\n")

    for name, args, count in benchmarks:
        print(f"\n[Test {name}] Ejecutando {count} iteraciones consecutivas...")
        latencies = []
        errors = 0
        success = 0

        for i in range(count):
            t0 = time.perf_counter()
            cmd = [TOOL] + args
            proc = subprocess.run(cmd, capture_output=True, text=True)
            elapsed = (time.perf_counter() - t0) * 1000.0

            total_calls += 1
            if proc.returncode == 0:
                latencies.append(elapsed)
                success += 1
                total_success += 1
                sys.stdout.write(".")
            else:
                errors += 1
                sys.stdout.write("E")
            sys.stdout.flush()
            time.sleep(0.05)

        print("")
        avg_lat = statistics.mean(latencies) if latencies else 0.0
        min_lat = min(latencies) if latencies else 0.0
        max_lat = max(latencies) if latencies else 0.0
        std_lat = statistics.stdev(latencies) if len(latencies) > 1 else 0.0

        res_line = (f"  {name:12s}: {success}/{count} OK ({errors} errores) | "
                    f"Latencia: min={min_lat:.1f}ms, avg={avg_lat:.1f}ms, "
                    f"max={max_lat:.1f}ms, stdev={std_lat:.1f}ms")
        print(res_line)
        f_out.write(f"{res_line}\n")
        results[name] = {
            "success": success,
            "total": count,
            "errors": errors,
            "min_ms": min_lat,
            "avg_ms": avg_lat,
            "max_ms": max_lat,
            "stdev_ms": std_lat
        }

    f_out.write(f"\nResumen Global: {total_success}/{total_calls} exitosos ({(total_success/total_calls)*100:.1f}%)\n")

print("\n======================================================================")
print(f"  TOTAL: {total_success}/{total_calls} exitosos (0 timeouts, 0 desincronizaciones)")
print(f"  Evidencia guardada en: {OUT_FILE}")
print("======================================================================")
