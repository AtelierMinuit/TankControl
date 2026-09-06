import subprocess
import time
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
import hashlib
from pathlib import Path

OUT_DIR = Path("research/hardware-validation/20260905-110110-master")
REPORT = OUT_DIR / "escl_bridge_report.txt"

PORT = 8092
BASE_URL = f"http://127.0.0.1:{PORT}"

print("======================================================================")
print("  FASE 14 — AIRSCAN eSCL HTTP BRIDGE CON HARDWARE REAL")
print("  Hardware: HP Smart Tank 500 (VID 03f0, PID 2b54)")
print("======================================================================")

# 1. Iniciar el puente en subproceso
proc = subprocess.Popen(
    ["python3", "tools/hp_escl_bridge.py", "--port", str(PORT)],
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    text=True
)

time.sleep(1.5) # Esperar arranque del servidor HTTP

try:
    with open(REPORT, "w", encoding="utf-8") as f_out:
        f_out.write("# VALIDACIÓN DE AIRSCAN eSCL BRIDGE SOBRE HARDWARE REAL\n")
        f_out.write(f"# URL Base: {BASE_URL}\n\n")

        # 2. Test ScannerCapabilities
        print("\n[eSCL Test 1] GET /eSCL/ScannerCapabilities...")
        req = urllib.request.Request(f"{BASE_URL}/eSCL/ScannerCapabilities")
        with urllib.request.urlopen(req, timeout=5) as resp:
            caps_data = resp.read().decode("utf-8")
            status_code = resp.status
            print(f"  HTTP {status_code} ({len(caps_data)} bytes)")
            assert "<scan:ScannerCapabilities" in caps_data or "<ScannerCapabilities" in caps_data
            f_out.write(f"1. ScannerCapabilities: HTTP {status_code} | {len(caps_data)} bytes -> PASS\n")

        # 3. Test ScannerStatus
        print("\n[eSCL Test 2] GET /eSCL/ScannerStatus...")
        req = urllib.request.Request(f"{BASE_URL}/eSCL/ScannerStatus")
        with urllib.request.urlopen(req, timeout=5) as resp:
            status_data = resp.read().decode("utf-8")
            status_code = resp.status
            print(f"  HTTP {status_code} ({len(status_data)} bytes): {status_data.strip()}")
            assert "<scan:ScannerStatus" in status_data or "<ScannerStatus" in status_data
            f_out.write(f"2. ScannerStatus: HTTP {status_code} | {len(status_data)} bytes -> PASS\n")

        # 4. Enviar trabajo de escaneo (ScanJobs)
        print("\n[eSCL Test 3] POST /eSCL/ScanJobs (150 DPI Color)...")
        scan_xml = (
            "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            "<scan:ScanSettings xmlns:scan=\"http://schemas.hp.com/imaging/escl/2011/05/03\">\n"
            "  <scan:Version>2.0</scan:Version>\n"
            "  <scan:Intent>Document</scan:Intent>\n"
            "  <scan:XResolution>150</scan:XResolution>\n"
            "  <scan:YResolution>150</scan:YResolution>\n"
            "  <scan:XOffset>0</scan:XOffset>\n"
            "  <scan:YOffset>0</scan:YOffset>\n"
            "  <scan:Width>1275</scan:Width>\n"
            "  <scan:Height>1754</scan:Height>\n"
            "  <scan:ColorMode>RGB24</scan:ColorMode>\n"
            "  <scan:InputSource>Platen</scan:InputSource>\n"
            "  <scan:Format>image/jpeg</scan:Format>\n"
            "</scan:ScanSettings>"
        ).encode("utf-8")

        req = urllib.request.Request(
            f"{BASE_URL}/eSCL/ScanJobs",
            data=scan_xml,
            headers={"Content-Type": "text/xml"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=60) as resp:
            job_status = resp.status
            job_loc = resp.headers.get("Location")
            print(f"  POST Job HTTP {job_status} -> Location: {job_loc}")
            assert job_status == 201
            assert job_loc is not None
            f_out.write(f"3. ScanJobs POST: HTTP {job_status} | Location: {job_loc} -> PASS\n")

        # 5. Descargar imagen escaneada de NextDocument
        next_doc_url = f"{job_loc}/NextDocument"
        print(f"\n[eSCL Test 4] GET {next_doc_url}...")
        req = urllib.request.Request(next_doc_url)
        with urllib.request.urlopen(req, timeout=30) as resp:
            doc_status = resp.status
            img_bytes = resp.read()
            soi = img_bytes[:2].hex()
            eoi = img_bytes[-2:].hex()
            sha = hashlib.sha256(img_bytes).hexdigest()
            print(f"  HTTP {doc_status} | {len(img_bytes)} bytes | SOI={soi}, EOI={eoi}")
            assert doc_status == 200
            assert soi == "ffd8"
            assert eoi == "ffd9"
            out_jpg = OUT_DIR / "escl_airscan_verified.jpg"
            out_jpg.write_bytes(img_bytes)
            f_out.write(f"4. NextDocument GET: HTTP {doc_status} | {len(img_bytes)} bytes | SOI={soi} | EOI={eoi} | SHA-256: {sha} -> PASS\n")

        print("\n¡AirScan eSCL Bridge VERIFICADO SOBRE HARDWARE REAL CON ÉXITO!")
        f_out.write("\nResultado Global: eSCL AirScan Bridge 100% OPERACIONAL con hardware físico.\n")

finally:
    proc.terminate()
    proc.wait(timeout=5)
    print(f"Puente eSCL detenido. Reporte en: {REPORT}")
