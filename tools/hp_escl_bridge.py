#!/usr/bin/env python3
"""
hp-escl-bridge.py
Puente eSCL (Apple AirScan) <-> USB LEDM para HP Smart Tank 500 series en macOS.
Expone el escáner USB como un servicio eSCL HTTP estándar para que macOS Image Capture
y Preview.app puedan escanear nativamente sin drivers propietarios.
"""

from __future__ import annotations

import argparse
from http.server import ThreadingHTTPServer, BaseHTTPRequestHandler
import json
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import threading
import tempfile
import time
import urllib.parse
import xml.etree.ElementTree as ET

# Importar el controlador USB
try:
    from tools.hp_smart_tank import SmartTank500, ChannelInfo
except ImportError:
    # Si se ejecuta desde el directorio tools/
    from hp_smart_tank import SmartTank500, ChannelInfo


MOCK_SCAN_CAPS_ESCL = """<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerCapabilities xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.63</pwg:Version>
  <pwg:MakeAndModel>HP Smart Tank 500 series</pwg:MakeAndModel>
  <pwg:Manufacturer>HP</pwg:Manufacturer>
  <scan:Platen>
    <scan:PlatenInputCaps>
      <scan:MinWidth>0</scan:MinWidth>
      <scan:MaxWidth>2550</scan:MaxWidth>
      <scan:MinHeight>0</scan:MinHeight>
      <scan:MaxHeight>3508</scan:MaxHeight>
      <scan:MaxScanRegions>1</scan:MaxScanRegions>
      <scan:SettingProfiles>
        <scan:SettingProfile>
          <scan:SupportedIntents>
            <scan:Intent>Document</scan:Intent>
            <scan:Intent>Photo</scan:Intent>
            <scan:Intent>Preview</scan:Intent>
            <scan:Intent>TextAndGraphic</scan:Intent>
          </scan:SupportedIntents>
          <scan:ColorModes>
            <scan:ColorMode>RGB24</scan:ColorMode>
            <scan:ColorMode>Grayscale8</scan:ColorMode>
          </scan:ColorModes>
          <scan:SupportedResolutions>
            <scan:DiscreteResolutions>
              <scan:DiscreteResolution>
                <scan:XResolution>75</scan:XResolution>
                <scan:YResolution>75</scan:YResolution>
              </scan:DiscreteResolution>
              <scan:DiscreteResolution>
                <scan:XResolution>150</scan:XResolution>
                <scan:YResolution>150</scan:YResolution>
              </scan:DiscreteResolution>
              <scan:DiscreteResolution>
                <scan:XResolution>300</scan:XResolution>
                <scan:YResolution>300</scan:YResolution>
              </scan:DiscreteResolution>
              <scan:DiscreteResolution>
                <scan:XResolution>600</scan:XResolution>
                <scan:YResolution>600</scan:YResolution>
              </scan:DiscreteResolution>
              <scan:DiscreteResolution>
                <scan:XResolution>1200</scan:XResolution>
                <scan:YResolution>1200</scan:YResolution>
              </scan:DiscreteResolution>
            </scan:DiscreteResolutions>
          </scan:SupportedResolutions>
          <scan:DocumentFormats>
            <pwg:DocumentFormat>image/jpeg</pwg:DocumentFormat>
            <scan:DocumentFormat>image/jpeg</scan:DocumentFormat>
            <scan:DocumentFormatExt>image/jpeg</scan:DocumentFormatExt>
          </scan:DocumentFormats>
        </scan:SettingProfile>
      </scan:SettingProfiles>
      <scan:SupportedIntents>
        <scan:Intent>Document</scan:Intent>
        <scan:Intent>Photo</scan:Intent>
        <scan:Intent>Preview</scan:Intent>
        <scan:Intent>TextAndGraphic</scan:Intent>
      </scan:SupportedIntents>
    </scan:PlatenInputCaps>
  </scan:Platen>
  <scan:SupportedIntents>
    <scan:Intent>Document</scan:Intent>
    <scan:Intent>Photo</scan:Intent>
    <scan:Intent>Preview</scan:Intent>
    <scan:Intent>TextAndGraphic</scan:Intent>
  </scan:SupportedIntents>
</scan:ScannerCapabilities>
"""

MOCK_SCANNER_STATUS_ESCL = """<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerStatus xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.63</pwg:Version>
  <pwg:State>Idle</pwg:State>
  <scan:Jobs/>
</scan:ScannerStatus>
"""


class ESCLBridgeHandler(BaseHTTPRequestHandler):
    bridge = None  # referencia a ESCLBridge
    MAX_REQUEST_BODY = 1024 * 1024
    CLIENT_TIMEOUT_SECONDS = 15

    def setup(self):
        super().setup()
        self.connection.settimeout(self.CLIENT_TIMEOUT_SECONDS)

    def log_message(self, format, *args):
        # Log simplificado
        sys.stderr.write(f"[eSCL] {self.address_string()} - {format % args}\n")

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/eSCL/ScannerCapabilities", "/ScannerCapabilities"):
            try:
                content = self.bridge.get_capabilities()
            except RuntimeError as exc:
                self.send_error(503, str(exc))
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/xml")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content.encode("utf-8"))
        elif path in ("/eSCL/ScannerStatus", "/ScannerStatus"):
            try:
                content = self.bridge.get_status()
            except RuntimeError as exc:
                self.send_error(503, str(exc))
                return
            self.send_response(200)
            self.send_header("Content-Type", "text/xml")
            self.send_header("Content-Length", str(len(content)))
            self.end_headers()
            self.wfile.write(content.encode("utf-8"))
        elif "/NextDocument" in path or "/Pages/" in path or "/Binary" in path:
            data = self.bridge.get_document(path)
            if data:
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            else:
                self.send_error(404, "Document not ready")
        elif path in ("/", "/index.html"):
            msg = "<html><body><h1>HP Smart Tank 500 AirScan / eSCL Bridge</h1><p>Status: OK</p></body></html>"
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg.encode("utf-8"))
        else:
            self.send_error(404, "Endpoint not found")

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path

        if path in ("/eSCL/ScanJobs", "/ScanJobs"):
            raw_cl = self.headers.get("Content-Length")
            if raw_cl is None:
                self.send_error(411, "Content-Length required")
                return
            try:
                cl = int(raw_cl, 10)
            except ValueError:
                self.send_error(400, "Invalid Content-Length")
                return
            if cl < 0 or cl > self.MAX_REQUEST_BODY:
                self.send_error(413, "Request body too large")
                return
            body = self.rfile.read(cl)
            if len(body) != cl:
                self.send_error(400, "Incomplete request body")
                return
            job_url = self.bridge.create_scan_job(body)
            self.send_response(201)
            self.send_header("Location", job_url)
            self.send_header("Content-Length", "0")
            self.end_headers()
        else:
            self.send_error(404, "Endpoint not found")

    def do_DELETE(self):
        parsed = urllib.parse.urlparse(self.path)
        job_id = parsed.path.split("/")[-1]
        self.bridge.delete_job(job_id)
        self.send_response(200)
        self.send_header("Content-Length", "0")
        self.end_headers()


class ESCLBridge:
    def __init__(self, port: int = 8089, mock: bool = False) -> None:
        self.port = port
        self.mock = mock
        self.bonjour_proc = None
        self.bonjour_print_proc = None
        self.last_scan_file: str | None = None
        self.is_scanning = False
        self.jobs = {}
        self.jobs_lock = threading.Lock()
        self.job_counter = 0

    def start(self) -> None:
        ESCLBridgeHandler.bridge = self
        # El puente sólo está implementado como servicio local. No publicarlo en
        # la LAN hasta existir un servidor IPP/eSCL completo y auditado.
        server = ThreadingHTTPServer(("127.0.0.1", self.port), ESCLBridgeHandler)
        print(f"[eSCL Bridge] Servidor escuchando en http://127.0.0.1:{self.port}/eSCL/")
        print(f"[eSCL Bridge] Modo: {'SIMULADOR MOCK' if self.mock else 'HARDWARE USB VIVO'}")

        # Anuncio Bonjour en macOS
        self.advertise_bonjour()

        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\n[eSCL Bridge] Deteniendo servidor...")
        finally:
            if self.bonjour_proc:
                self.bonjour_proc.terminate()
            if self.bonjour_print_proc:
                self.bonjour_print_proc.terminate()

    def advertise_bonjour(self) -> None:
        # 1. Anuncio de Escáner AirScan (eSCL)
        cmd_scan = [
            "dns-sd", "-R", "HP Smart Tank 500 (AirScan)", "_uscan._tcp", "local",
            str(self.port), "vers=2.63", "rs=eSCL", "txtvers=1", "pdl=image/jpeg",
            "ty=HP Smart Tank 500 series", f"adminurl=http://127.0.0.1:{self.port}/"
        ]
        try:
            self.bonjour_proc = subprocess.Popen(cmd_scan, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            print(f"[eSCL Bridge] Anuncio AirScan local (_uscan._tcp:{self.port}) registrado en Bonjour")
        except Exception as e:
            print(f"[eSCL Bridge] No se pudo lanzar dns-sd ({e})")

    def get_capabilities(self) -> str:
        return MOCK_SCAN_CAPS_ESCL

    def get_status(self) -> str:
        jobs_xml = []
        with self.jobs_lock:
            state = "Processing" if self.is_scanning else "Idle"
            jobs_snapshot = [dict(job) for job in self.jobs.values()]
        for j in jobs_snapshot:
            age = int(time.time() - j["created_at"])
            jobs_xml.append(f"""
    <scan:JobInfo>
      <pwg:JobUri>/eSCL/ScanJobs/{j["id"]}</pwg:JobUri>
      <pwg:JobUuid>{j["id"]}</pwg:JobUuid>
      <scan:Age>{age}</scan:Age>
      <pwg:ImagesCompleted>{j["images_completed"]}</pwg:ImagesCompleted>
      <pwg:JobState>{j["state"]}</pwg:JobState>
      <pwg:JobStateReasons>
        <pwg:JobStateReason>{'JobCompletedSuccessfully' if j["state"] == 'Completed' else 'JobScanning'}</pwg:JobStateReason>
      </pwg:JobStateReasons>
    </scan:JobInfo>""")
        jobs_str = "".join(jobs_xml)
        return f"""<?xml version="1.0" encoding="UTF-8"?>
<scan:ScannerStatus xmlns:scan="http://schemas.hp.com/imaging/escl/2011/05/03" xmlns:pwg="http://www.pwg.org/schemas/2010/12/sm">
  <pwg:Version>2.63</pwg:Version>
  <pwg:State>{state}</pwg:State>
  <scan:Jobs>{jobs_str}
  </scan:Jobs>
</scan:ScannerStatus>
"""

    def create_scan_job(self, escl_body: bytes) -> str:
        with self.jobs_lock:
            self.job_counter += 1
            job_id = f"job-{self.job_counter}"
        res = 300
        mode = "color"
        intent = "Document"
        x_offset = 0
        y_offset = 0
        region_w = 0
        region_h = 0
        if escl_body:
            try:
                # No registrar el XML completo: puede contener preferencias del
                # usuario y no aporta valor operativo al log por defecto.
                print("[eSCL Bridge] Ajustes de escaneo recibidos de macOS")
                lowered_body = escl_body.lower()
                if b"<!doctype" in lowered_body or b"<!entity" in lowered_body:
                    raise ValueError("DOCTYPE/ENTITY no permitido")
                root = ET.fromstring(escl_body)
                for el in root.iter():
                    tag = el.tag.split("}")[-1] if "}" in el.tag else el.tag
                    if tag == "XResolution" and el.text:
                        res = int(el.text)
                    elif tag == "ColorMode" and el.text:
                        if "Gray" in el.text or "BlackAndWhite" in el.text:
                            mode = "gray"
                    elif tag == "Intent" and el.text:
                        intent = el.text
                    elif tag == "XOffset" and el.text:
                        x_offset = int(el.text)
                    elif tag == "YOffset" and el.text:
                        y_offset = int(el.text)
                    elif tag == "Width" and el.text:
                        region_w = int(el.text)
                    elif tag == "Height" and el.text:
                        region_h = int(el.text)
            except Exception as e:
                print(f"[eSCL Bridge] Nota: XML de ajustes: {e}")

        # Validar y restringir resolución a límites físicos del escáner
        if res < 75 or res > 1200:
            res = 300

        # Escalar coordenadas eSCL (base 300 DPI) a píxeles de resolución solicitada
        scale = res / 300.0
        max_w = int(8.5 * res)
        max_h = int(11.69 * res)

        x_start = int(x_offset * scale) if x_offset > 0 else 0
        y_start = int(y_offset * scale) if y_offset > 0 else 0
        pix_w = int(region_w * scale) if region_w > 0 else max_w
        pix_h = int(region_h * scale) if region_h > 0 else max_h

        if x_start >= max_w:
            x_start = 0
        if y_start >= max_h:
            y_start = 0
        if x_start + pix_w > max_w or pix_w <= 0:
            pix_w = max(1, max_w - x_start)
        if y_start + pix_h > max_h or pix_h <= 0:
            pix_h = max(1, max_h - y_start)

        scan_dir = Path(tempfile.mkdtemp(prefix="hp-airscan-", dir=tempfile.gettempdir()))
        scan_out = str(scan_dir / "scan.jpg")
        job = {
            "id": job_id,
            "res": res,
            "mode": mode,
            "intent": intent,
            "file": scan_out,
            "region": (x_start, y_start, pix_w, pix_h),
            "state": "Processing",
            "images_completed": 0,
            "created_at": time.time()
        }
        with self.jobs_lock:
            self.jobs[job_id] = job

        bin_path = None
        candidates = [
            os.environ.get("HP_SCAN_BIN"),
            "/usr/local/bin/hp_scan",
            str(Path(__file__).resolve().parent.parent / "research/builds/antigravity-offline-audit/hp_scan"),
            str(Path(__file__).resolve().parent / "hp_scan")
        ]
        for c in candidates:
            if c and Path(c).is_file() and os.access(c, os.X_OK):
                bin_path = Path(c)
                break

        if not self.mock and bin_path:
            print(f"[eSCL Bridge] Ejecutando escaneo ({res} DPI, modo {mode}, región {x_start},{y_start} {pix_w}x{pix_h}) con {bin_path}...")
            with self.jobs_lock:
                self.is_scanning = True
            try:
                cmd = [
                    str(bin_path), scan_out, str(res), mode,
                    str(x_start), str(y_start), str(pix_w), str(pix_h)
                ]
                subprocess.run(cmd, check=True, timeout=180)
                with self.jobs_lock:
                    job["state"] = "Completed"
                    job["images_completed"] = 1
                    self.last_scan_file = scan_out
                print(f"[eSCL Bridge] Escaneo completado: {scan_out} ({Path(scan_out).stat().st_size} bytes)")
            except subprocess.TimeoutExpired:
                print("[eSCL Bridge] Timeout esperando a hp_scan; job cancelado")
                with self.jobs_lock:
                    job["state"] = "Canceled"
            except Exception as e:
                print(f"[eSCL Bridge] Error en hp_scan: {e}")
                job["state"] = "Canceled"
                try:
                    Path(scan_out).unlink(missing_ok=True)
                    Path(scan_out).parent.rmdir()
                except OSError:
                    pass
            finally:
                with self.jobs_lock:
                    self.is_scanning = False
                if job["state"] == "Canceled":
                    try:
                        Path(scan_out).unlink(missing_ok=True)
                        Path(scan_out).parent.rmdir()
                    except OSError:
                        pass
        else:
            # El mock debe producir explícitamente un artefacto de prueba;
            # nunca depender de un archivo residual o compartido en /tmp.
            Path(scan_out).write_bytes(
                b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00"
                b"\xff\xd9"
            )
            job["state"] = "Completed"
            job["images_completed"] = 1

        return f"http://127.0.0.1:{self.port}/eSCL/ScanJobs/{job_id}"

    def get_document(self, path: str) -> bytes:
        parts = path.strip("/").split("/")
        job_id = None
        for i, part in enumerate(parts):
            if part == "ScanJobs" and i + 1 < len(parts):
                job_id = parts[i + 1]
                break

        with self.jobs_lock:
            job = self.jobs.get(job_id) if job_id else None
        if job:
            job_file = job["file"]
            if Path(job_file).exists():
                print(f"[eSCL Bridge] Entregando imagen de {job_id} ({Path(job_file).stat().st_size} bytes)")
                return Path(job_file).read_bytes()

        if self.last_scan_file and Path(self.last_scan_file).exists():
            print(f"[eSCL Bridge] Entregando última imagen ({Path(self.last_scan_file).stat().st_size} bytes)")
            return Path(self.last_scan_file).read_bytes()

        return b""

    def delete_job(self, job_id: str) -> None:
        with self.jobs_lock:
            job = self.jobs.pop(job_id, None)
        if job:
            print(f"[eSCL Bridge] Cliente finalizó trabajo {job_id}")
            try:
                Path(job["file"]).unlink(missing_ok=True)
                Path(job["file"]).parent.rmdir()
            except OSError:
                pass


def main() -> int:
    parser = argparse.ArgumentParser(description="Puente eSCL (AirScan) para HP Smart Tank 500")
    parser.add_argument("--port", type=int, default=8089, help="Puerto HTTP local (default 8089)")
    parser.add_argument("--mock", action="store_true", help="Forzar modo mock simulado")
    args = parser.parse_args()

    bridge = ESCLBridge(port=args.port, mock=args.mock)
    bridge.start()
    return 0


if __name__ == "__main__":
    sys.exit(main())
