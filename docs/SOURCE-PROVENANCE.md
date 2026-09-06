# Source Code Provenance & Component Classification (HP Smart Tank 500)

**Project:** HP Smart Tank 500 macOS Native Driver (`0x03f0:0x2b54`)  
**Status:** CANONICAL AUDIT DOCUMENT  
**Version:** 0.1.0-alpha  
**Date:** 2026-09-04  

---

## 1. Provenance Classification Taxonomy

To ensure intellectual property integrity, legal clarity, and adherence to software licensing standards, all files in this repository are categorized into one of four distinct provenance classes:

1. **`CLEAN-ROOM`**: Developed entirely from public technical standards, RFCs, reverse-engineered USB packet captures, and original algorithms without copying proprietary or GPL source code.
2. **`DERIVED`**: Developed using architectural structures or data layouts from open-source reference implementations (such as HPLIP or CUPS) with original code modifications.
3. **`ADAPTED`**: Adapted from standard open-source utility templates (e.g., standard CUPS filter loops or SANE backend templates) to match the target device.
4. **`VENDOR`**: Original third-party binary, firmware, or proprietary package from OEM vendors (HP, Apple). Strictly segregated in `research/` and never included in the distributed driver payload.

---

## 2. Component Provenance Inventory

| Component / File Path | Provenance Class | Origin / Reference | License | Purpose / Description |
| :--- | :--- | :--- | :--- | :--- |
| **`tools/rastertopcl3gui.c`** | `CLEAN-ROOM` | PCL3GUI Technical Reference & Mode 10 Run-Length RFC | MIT | Native CUPS raster to PCL3GUI converter with InkSaver, RGBW support, and Mode 10 compressor. |
| **`tools/cups_backend_smarttank.c`** | `CLEAN-ROOM` | CUPS Backend Interface Specification & libusb-1.0 API | MIT | Native USB bulk transport backend with dynamic endpoint discovery and error recovery. |
| **`tools/hp-smart-tank-tool.c`** | `CLEAN-ROOM` | USB LEDM Protocol Reverse Engineering & libusb-1.0 | MIT | Hardware inspection, LEDM status querying, and head maintenance CLI utility. |
| **`tools/hp_scan.c`** | `CLEAN-ROOM` | USB LEDM Scan Interface Re-engineering | MIT | Standalone USB scanner driver for Flatbed scan capture and JPEG reconstruction. |
| **`tools/hp_escl_bridge.py`** | `CLEAN-ROOM` | eSCL 2.0 / 2.6 Specification & AirScan RFC | MIT | HTTP microserver providing eSCL/AirScan capability to Apple Image Capture. |
| **`tools/virtual_smart_tank.py`** | `CLEAN-ROOM` | Project Architecture & LEDM Protocol Spec | MIT | Full software digital twin / mock USB simulator for offline hardware emulation. |
| **`tools/run_hardware_validation.sh`** | `CLEAN-ROOM` | Project Test Plan | MIT | Strict offline/online hardware validation harness with Device Safety Gate. |
| **`tools/generate_smoke_test_page.py`** | `CLEAN-ROOM` | Project Test Plan | MIT | Autonomous PDF/Raster test page generator with calibration targets. |
| **`tools/calibrate_icc.py`** | `CLEAN-ROOM` | ICC.1:2010 Specification & Colorimetry Math | MIT | Algorithmic generator for sRGB-targeted synthetic ICC profiles. |
| **`research/builds/...ppd`** | `ADAPTED` | CUPS PPD Specification 4.3 & HPLIP PPD templates | GPL-2.0+ / MIT | PostScript Printer Description file defining resolutions, media, and ink controls. |
| **`io/hpmud/musb.c`** | `DERIVED` | HPLIP (HP Linux Imaging and Printing) v3.23 | GPL-2.0+ | Reference implementation for HP USB multi-channel multiplexing (reference only). |
| **`packaging/postinstall`** | `CLEAN-ROOM` | Apple Installer Package Specification | MIT | Post-installation hook configuring CUPS printers and LaunchAgents. |
| **`packaging/preremove`** | `CLEAN-ROOM` | Apple Installer Package Specification | MIT | Cleanup hook removing printers, LaunchAgents, and driver files. |
| **`tests/*`** | `CLEAN-ROOM` | Python `unittest` standard library | MIT | 170+ unit, integration, and mock tests verifying all subsystems offline. |
| **`research/extracted/*`** | `VENDOR` | Official HP Drivers & Apple Printer Updates | Proprietary (OEM) | Reference vendor installers used for reverse engineering and comparative audit only. |

---

## 3. Clean-Room Implementation Verification

### 3.1 PCL3GUI Mode 10 Compression
The compression algorithm implemented in `tools/rastertopcl3gui.c` (`pcl3_compress_mode10`) was implemented strictly from algorithmic specifications:
- Run-length encoding of identical bytes.
- Command byte encoding: `(count - 1)` for literals, `-(count - 1)` for repeats.
- Row-to-row XOR delta compression against the seed row.
- Verified by independent decoder `tools/pcl3gui-decode.py`.

### 3.2 USB LEDM Scan Protocol
The LEDM scanner protocol implemented in `tools/hp_scan.c` and `tools/hp_escl_bridge.py`:
- Protocol discovered through USB packet analysis of the P15_CISS ASIC.
- Commands sent over Interface 0 (`0xff/0xcc/0x00`) using raw HTTP-over-bulk framing.
- No closed-source HP binary libraries or SANE proprietary plugins (`hpijs`, `hpaio` blobs) are linked or required.

---

## 4. Vendor Isolation Policy

To strictly adhere to copyright and licensing regulations:
1. No binary files from `research/extracted/` are packaged into the final `.pkg` distribution.
2. The runtime distribution relies exclusively on:
   - User-space code compiled from source (`rastertopcl3gui`, `cups_backend_smarttank`, `hp_scan`).
   - Open-source dynamic libraries (`libusb-1.0.dylib` under LGPL-2.1).
   - Standard macOS system frameworks (`IOKit`, `CoreFoundation`, `Security`).
