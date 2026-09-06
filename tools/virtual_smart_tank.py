#!/usr/bin/env python3
"""
virtual_smart_tank.py
Gemelo Digital / Emulador de Hardware para HP Smart Tank 500.
Simula en bucle local (loopback) las interfaces de la impresora física:
  - Interfaz 1 (07/01/02): Spooler Raw PCL3GUI (puerto 9100 / stdin / PTY)
  - Interfaz 0 (ff/cc/00): Escáner LEDM / eSCL
  - Interfaz 2 (ff/04/01): EWS / Consumibles y Mantenimiento
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from http.server import HTTPServer, BaseHTTPRequestHandler
import importlib.util
import io
import os
from pathlib import Path
import socket
import sys
import threading
import time

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Cargar decodificador semántico PCL3GUI
DECODER_PATH = PROJECT_ROOT / "tools" / "pcl3gui-decode.py"
SPEC_DEC = importlib.util.spec_from_file_location("pcl3gui_decode", DECODER_PATH)
DECODER = importlib.util.module_from_spec(SPEC_DEC)
sys.modules[SPEC_DEC.name] = DECODER
SPEC_DEC.loader.exec_module(DECODER)


@dataclass
class VirtualPrinterState:
    status_category: str = "ready"
    total_pages_printed: int = 0
    ink_c: int = 85
    ink_m: int = 90
    ink_y: int = 80
    ink_k: int = 95
    cleaning_cycles: int = 0
    alignment_sessions: int = 0
    jobs_received: int = 0


STATE = VirtualPrinterState()


class VirtualEWSHandler(BaseHTTPRequestHandler):
    MAX_BODY = 1024 * 1024

    def log_message(self, format, *args):
        sys.stderr.write(f"[VirtualEWS] {format % args}\n")

    def do_GET(self):
        if self.path == "/DevMgmt/ProductStatusDyn.xml":
            xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<psdyn:ProductStatusDyn xmlns:psdyn="http://www.hp.com/schemas/imaging/con/ledm/productstatusdyn/2008/03/21">
  <psdyn:StatusCategory>{STATE.status_category}</psdyn:StatusCategory>
  <psdyn:TotalPagesPrinted>{STATE.total_pages_printed}</psdyn:TotalPagesPrinted>
</psdyn:ProductStatusDyn>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))

        elif self.path == "/DevMgmt/ConsumableConfigDyn.xml":
            xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<ccdyn:ConsumableConfigDyn xmlns:ccdyn="http://www.hp.com/schemas/imaging/con/ledm/consumableconfigdyn/2007/11/19">
  <ccdyn:ConsumableInfo>
    <ccdyn:ConsumableLabelCode>K</ccdyn:ConsumableLabelCode>
    <ccdyn:ConsumablePercentageLevelRemaining>{STATE.ink_k}</ccdyn:ConsumablePercentageLevelRemaining>
    <ccdyn:ConsumableState>ok</ccdyn:ConsumableState>
  </ccdyn:ConsumableInfo>
  <ccdyn:ConsumableInfo>
    <ccdyn:ConsumableLabelCode>C</ccdyn:ConsumableLabelCode>
    <ccdyn:ConsumablePercentageLevelRemaining>{STATE.ink_c}</ccdyn:ConsumablePercentageLevelRemaining>
    <ccdyn:ConsumableState>ok</ccdyn:ConsumableState>
  </ccdyn:ConsumableInfo>
  <ccdyn:ConsumableInfo>
    <ccdyn:ConsumableLabelCode>M</ccdyn:ConsumableLabelCode>
    <ccdyn:ConsumablePercentageLevelRemaining>{STATE.ink_m}</ccdyn:ConsumablePercentageLevelRemaining>
    <ccdyn:ConsumableState>ok</ccdyn:ConsumableState>
  </ccdyn:ConsumableInfo>
  <ccdyn:ConsumableInfo>
    <ccdyn:ConsumableLabelCode>Y</ccdyn:ConsumableLabelCode>
    <ccdyn:ConsumablePercentageLevelRemaining>{STATE.ink_y}</ccdyn:ConsumablePercentageLevelRemaining>
    <ccdyn:ConsumableState>ok</ccdyn:ConsumableState>
  </ccdyn:ConsumableInfo>
</ccdyn:ConsumableConfigDyn>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/Calibration/State":
            xml = """<?xml version="1.0" encoding="UTF-8"?>
<cal:CalibrationState xmlns:cal="http://www.hp.com/schemas/imaging/con/cnx/markingagentcalibration/2009/04/08">Idle</cal:CalibrationState>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/DevMgmt/ProductUsageDyn.xml":
            xml = f"""<?xml version="1.0" encoding="UTF-8"?>
<pudyn:ProductUsageDyn xmlns:pudyn="http://www.hp.com/schemas/imaging/con/ledm/productusagedyn/2007/11/05">
  <pudyn:PrintUsage>
    <pudyn:TotalImpressions>{STATE.total_pages_printed + 1248}</pudyn:TotalImpressions>
    <pudyn:MonochromeImpressions>830</pudyn:MonochromeImpressions>
    <pudyn:ColorImpressions>{STATE.total_pages_printed + 418}</pudyn:ColorImpressions>
    <pudyn:BorderlessImpressions>94</pudyn:BorderlessImpressions>
    <pudyn:JamEvents>2</pudyn:JamEvents>
    <pudyn:PickFailures>1</pudyn:PickFailures>
  </pudyn:PrintUsage>
  <pudyn:ScanUsage>
    <pudyn:FlatbedScans>156</pudyn:FlatbedScans>
  </pudyn:ScanUsage>
  <pudyn:ConsumableUsage>
    <pudyn:TotalDropsFiredK>48291000</pudyn:TotalDropsFiredK>
    <pudyn:TotalDropsFiredC>12400000</pudyn:TotalDropsFiredC>
    <pudyn:TotalDropsFiredM>13100000</pudyn:TotalDropsFiredM>
    <pudyn:TotalDropsFiredY>11800000</pudyn:TotalDropsFiredY>
  </pudyn:ConsumableUsage>
</pudyn:ProductUsageDyn>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/DevMgmt/DiscoveryTree.xml":
            xml = """<?xml version="1.0" encoding="UTF-8"?>
<DiscoveryTree xmlns="http://www.hp.com/schemas/imaging/con/ledm/discoverytree/2008/03/21">
  <Service name="DevMgmt" url="/DevMgmt/"/>
  <Service name="Scan" url="/Scan/"/>
  <Service name="Print" url="/Print/"/>
  <Service name="Calibration" url="/Calibration/"/>
</DiscoveryTree>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/DevMgmt/ProductConfigDyn.xml":
            xml = """<?xml version="1.0" encoding="UTF-8"?>
<ProductConfigDyn xmlns="http://www.hp.com/schemas/imaging/con/ledm/productconfigdyn/2008/03/21">
  <ProductInformation>
    <MakeAndModel>HP Smart Tank 500 series</MakeAndModel>
    <ProductSerialNumber>TH01234567</ProductSerialNumber>
    <FirmwareVersion>VER3_2024A</FirmwareVersion>
    <HardwareArchitecture>ASIC-P15_CISS</HardwareArchitecture>
  </ProductInformation>
</ProductConfigDyn>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/DevMgmt/MediaCapabilities.xml":
            xml = """<?xml version="1.0" encoding="UTF-8"?>
<MediaCapabilities xmlns="http://www.hp.com/schemas/imaging/con/ledm/mediacapabilities/2008/03/21">
  <SupportedMediaTypes>
    <Type>Plain</Type><Type>Glossy</Type><Type>FastGlossy</Type><Type>Brochure</Type><Type>Matte</Type>
  </SupportedMediaTypes>
  <SupportedSizes>
    <Size borderless="true">A4</Size><Size borderless="true">Letter</Size><Size borderless="true">Photo4x6</Size>
  </SupportedSizes>
</MediaCapabilities>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        elif self.path == "/DevMgmt/IOConfig.xml":
            xml = """<?xml version="1.0" encoding="UTF-8"?>
<IOConfig xmlns="http://www.hp.com/schemas/imaging/con/ledm/ioconfig/2008/03/21">
  <Interface id="0" type="LEDM_Scan" ep_in="0x81" ep_out="0x01"/>
  <Interface id="1" type="PCL3GUI_Print" ep_in="0x82" ep_out="0x02"/>
  <Interface id="2" type="EWS_DevMgmt" ep_in="0x83" ep_out="0x03"/>
</IOConfig>"""
            self._respond(200, "text/xml", xml.encode("utf-8"))
        else:
            self.send_error(404, "Endpoint no encontrado")

    def do_POST(self):
        raw_cl = self.headers.get("Content-Length")
        try:
            cl = int(raw_cl) if raw_cl is not None else -1
        except (TypeError, ValueError):
            self.send_error(400, "Content-Length inválido")
            return
        if cl < 0 or cl > self.MAX_BODY:
            self.send_error(413 if cl > self.MAX_BODY else 411, "Content-Length fuera de rango")
            return
        raw_body = self.rfile.read(cl)
        if len(raw_body) != cl:
            self.send_error(400, "Cuerpo incompleto")
            return
        body = raw_body.decode("utf-8", errors="ignore")

        if self.path == "/DevMgmt/InternalPrintDyn.xml":
            if "cleaningPage" in body:
                STATE.cleaning_cycles += 1
                STATE.ink_k = max(0, STATE.ink_k - 1)
                STATE.ink_c = max(0, STATE.ink_c - 1)
                STATE.ink_m = max(0, STATE.ink_m - 1)
                STATE.ink_y = max(0, STATE.ink_y - 1)
                print(f"[VirtualSmartTank] Limpieza ejecutada! Ciclo #{STATE.cleaning_cycles}")
            elif "cleaningVerificationPage" in body:
                STATE.total_pages_printed += 1
                print(f"[VirtualSmartTank] Impresa página de diagnóstico. Total páginas: {STATE.total_pages_printed}")
            self._respond(200, "text/xml", b"<response>OK</response>")

        elif self.path == "/Calibration/Session":
            STATE.alignment_sessions += 1
            print(f"[VirtualSmartTank] Alineación iniciada! Sesión #{STATE.alignment_sessions}")
            self._respond(200, "text/xml", b"<response>Alignment Started</response>")
        else:
            self.send_error(404, "Endpoint no encontrado")

    def _respond(self, code: int, ctype: str, body: bytes):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def process_print_job(raw_data: bytes, job_id: int) -> dict:
    """Procesa e inspecciona semánticamente un flujo PCL3GUI recibido en el motor de impresión."""
    STATE.jobs_received += 1
    STATE.total_pages_printed += 1
    out_dir = PROJECT_ROOT / "scratch"
    out_dir.mkdir(exist_ok=True)

    dump_path = out_dir / f"virtual_job_{job_id}.pcl3gui"
    dump_path.write_bytes(raw_data)

    print(f"\n[VirtualEngine] === NUEVO TRABAJO DE IMPRESIÓN #{job_id} ({len(raw_data)} bytes) ===")

    # Validar cabecera PJL
    if not raw_data.startswith(b"\x1b%-12345X"):
        print("[VirtualEngine] ERROR: Secuencia UEL inicial ausente!")
        return {"ok": False, "error": "Missing UEL"}

    if b"@PJL ENTER LANGUAGE=PCL3GUI" not in raw_data:
        print("[VirtualEngine] ERROR: Comando @PJL ENTER LANGUAGE=PCL3GUI no encontrado!")
        return {"ok": False, "error": "Invalid PJL language"}

    # Decodificar raster con el motor Mode 10
    try:
        # Por defecto asumir A4 600dpi (5100x6600) si no se especifica
        rows, counts, stats, ending_y = DECODER.decode_stream_mode10(raw_data, 5100, 6600)
        bbox, colors = DECODER.content_summary(rows, 5100)

        ppm_path = out_dir / f"virtual_job_{job_id}.ppm"
        DECODER.write_ppm(ppm_path, rows, 5100, ending_y)

        summary = {
            "ok": True,
            "bytes": len(raw_data),
            "event_counts": counts,
            "ending_y": ending_y,
            "bbox": bbox,
            "colors_count": len(colors),
            "ppm_path": str(ppm_path),
        }
        print(f"[VirtualEngine] Trabajo procesado con ÉXITO: {counts.get('W', 0)} bloques W, Y_fin={ending_y}")
        print(f"[VirtualEngine] Bounding box de contenido: {bbox}")
        print(f"[VirtualEngine] Imagen renderizada guardada en: {ppm_path.name}")
        return summary
    except Exception as e:
        print(f"[VirtualEngine] Error decodificando flujo PCL3GUI: {e}")
        return {"ok": False, "error": str(e)}


def run_raw_printer_server(port: int = 9100) -> None:
    """Servidor socket RAW JetDirect (puerto 9100) para recibir impresiones directas."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind(("127.0.0.1", port))
    sock.listen(5)
    print(f"[VirtualSmartTank] Motor de impresión RAW escuchando en 127.0.0.1:{port}")

    job_counter = 0
    while True:
        try:
            conn, addr = sock.accept()
            job_counter += 1
            data = bytearray()
            while True:
                chunk = conn.recv(65536)
                if not chunk:
                    break
                data.extend(chunk)
            conn.close()
            process_print_job(bytes(data), job_counter)
        except Exception as e:
            break


def main() -> int:
    parser = argparse.ArgumentParser(description="Gemelo Digital de HP Smart Tank 500")
    parser.add_argument("--ews-port", type=int, default=8082, help="Puerto HTTP EWS (default 8082)")
    parser.add_argument("--raw-port", type=int, default=9100, help="Puerto RAW impresión (default 9100)")
    parser.add_argument("--inspect-file", type=Path, help="Procesa directamente un archivo PCL3GUI offline")
    args = parser.parse_args()

    if args.inspect_file:
        data = args.inspect_file.read_bytes()
        res = process_print_job(data, 1)
        return 0 if res.get("ok") else 1

    # Iniciar servidor EWS
    ews_server = HTTPServer(("127.0.0.1", args.ews_port), VirtualEWSHandler)
    ews_thread = threading.Thread(target=ews_server.serve_forever, daemon=True)
    ews_thread.start()
    print(f"[VirtualSmartTank] Canal EWS escuchando en http://127.0.0.1:{args.ews_port}/")

    # Iniciar servidor RAW Spooler
    raw_thread = threading.Thread(target=run_raw_printer_server, args=(args.raw_port,), daemon=True)
    raw_thread.start()

    print("[VirtualSmartTank] Gemelo Digital ACTIVO y listo para recibir pruebas de macOS.")
    print("Presiona Ctrl+C para detener.")

    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\n[VirtualSmartTank] Deteniendo Gemelo Digital...")
        ews_server.shutdown()

    return 0


if __name__ == "__main__":
    sys.exit(main())
