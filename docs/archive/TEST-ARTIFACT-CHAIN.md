# Test Artifact Chain & Evidence Traceability (HP Smart Tank 500)

**Project:** HP Smart Tank 500 macOS Native Driver (`0x03f0:0x2b54`)  
**Status:** CANONICAL DOCUMENTATION — OFFLINE & HARDWARE VALIDATION  
**Version:** 0.1.0-alpha  
**Date:** 2026-09-04  

---

## 1. Overview & Architecture

To guarantee strict scientific reproducibility and zero false positives during testing, every execution of the validation harness (`tools/run_hardware_validation.sh`) produces a cryptographically sealed chain of artifacts.

Every transformation stage—from input document to USB transmission and scan capture—is hashed with SHA-256 and registered in `manifest.txt`. Any alteration, data corruption, or silent failure breaks the cryptographic chain.

---

## 2. Print Transformation Pipeline

The print pipeline transforms input vector documents into native HP PCL3GUI binary streams transmitted over USB Bulk OUT.

```
[Input Vector PDF] 
       │
       ▼ (cgpdftops / pdftoraster or test pattern generator)
[CUPS Raster Stream] (cupsColorSpace: RGB=1, RGBA=2, RGBW=17, K=3)
       │
       ▼ (rastertopcl3gui)
[PCL3GUI Stream] (UEL, PJL, Esc*r#A, Mode 10 Compression, Esc*rB)
       │
       ▼ (cups_backend_smarttank)
[USB Bulk OUT Stream] (Interface 1, Endpoint 0x05, 512-byte bulk packets)
       │
       ▼
[HP P15_CISS Hardware or virtual_smart_tank.py]
```

### 2.1 Print Stages and Hash Verification

| Stage | Format | Generator / Tool | Checksum Location | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **0. Test Input** | PDF 1.4 (`hardware-smoke-test.pdf`) | `tools/generate_smoke_test_page.py` | `print/smoke-test.pdf.sha256` | Static generation; sha256 checked against harness manifest |
| **1. CUPS Raster** | CUPS Raster v2 / PWG Raster | CUPS core or `tools/generate_smoke_test_page.py` | `print/raster.raw.sha256` | Header validation (`RaSt` or `RaS2`), dimension and color space check |
| **2. PCL3GUI Stream** | PCL3GUI Binary | `tools/rastertopcl3gui` | `print/output.pcl.sha256` | Validated by `tools/pcl3gui-decode.py`; verify PJL headers and Mode 10 rows |
| **3. Packet Trace** | USB Bulk Frame Capture | `cups_backend_smarttank` (or mock backend) | `print/usb_stream.bin.sha256` | Packet-level delta analysis; identical to PCL3GUI in pure streaming |
| **4. Device Ingestion** | Hardware Buffer | HP Smart Tank 500 (P15_CISS ASIC) | Device Status Response | Status polling via Interface 1 Endpoint 0x84 or Interface 2 LEDM |

---

## 3. Scan Transformation Pipeline

The scan pipeline coordinates between the host eSCL/AirScan daemon or CLI scan utility and the device's LEDM scanning engine.

```
[Client / Image Capture / eSCL Client]
       │
       ▼ (HTTP POST /eSCL/ScanJobs)
[hp_escl_bridge.py / hp_scan]
       │
       ▼ (HTTP XML LEDM ScannerCapabilities & ScanJob)
[USB Bulk OUT Interface 0 / Endpoint 0x02]
       │
       ▼
[Hardware Optical Carriage & Cis Sensor]
       │
       ▼
[USB Bulk IN Interface 0 / Endpoint 0x81]
       │
       ▼ (Chunked Raw / JPEG Stream with SOI 0xFFD8 ... EOI 0xFFD9)
[Extracted Image Artifact] (scan/scan_YYYYMMDD_HHMMSS.jpg)
       │
       ▼
[Converted Artifact] (scan/scan_YYYYMMDD_HHMMSS.pdf or .tiff)
```

### 3.1 Scan Stages and Hash Verification

| Stage | Format | Handler | Checksum Location | Verification Method |
| :--- | :--- | :--- | :--- | :--- |
| **0. Scan Job Spec** | eSCL XML / HTTP Payload | `hp_escl_bridge.py` | `scan/job_spec.xml.sha256` | Schema validation against eSCL 2.0 / 2.6 schema |
| **1. LEDM Request** | LEDM Scan Command XML | `tools/hp_scan.c` | `scan/ledm_request.xml.sha256` | LEDM ScanJob XML schema verification |
| **2. Raw USB Stream** | Binary Chunk Stream | USB Bulk IN 0x81 | `scan/raw_stream.bin.sha256` | Boundary parsing; verify chunk headers and byte count |
| **3. Extracted JPEG** | JFIF / JPEG (`image/jpeg`) | `hp_scan.c` / `hp_escl_bridge.py` | `scan/image.jpg.sha256` | Verification of JPEG magic headers: starts with `0xFFD8`, ends with `0xFFD9` |
| **4. Client Output** | PDF / TIFF / PNG | Client Application | `scan/output.pdf.sha256` | Standard image parser verification |

---

## 4. Manifest Integrity Architecture (`manifest.txt`)

During each validation run, the harness records metadata and SHA-256 hashes of all artifacts into `manifest.txt`:

```text
# HP Smart Tank 500 Hardware Validation Manifest
# Session: <SESSION_ID>
# Date: <ISO_8601_TIMESTAMP>
# Mode: <OFFLINE | DRY_RUN | MOCK | LIVE>

<SHA256_HASH>  print/hardware-smoke-test.pdf
<SHA256_HASH>  print/smoke-test.raster
<SHA256_HASH>  print/smoke-test.pcl
<SHA256_HASH>  scan/scan_001.jpg
<SHA256_HASH>  telemetry/usb_descriptors.txt
<SHA256_HASH>  telemetry/ledm_status.xml
<SHA256_HASH>  logs/session.log
<SHA256_HASH>  summary.json
```

### 4.1 Automated Validation Check
The harness verifies this chain using:
```bash
shasum -a 256 -c manifest.txt
```
Any modification to logs, intermediate files, or outputs causes an immediate hash mismatch.
