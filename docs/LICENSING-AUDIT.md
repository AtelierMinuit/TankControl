# Licensing Audit & Legal Compliance (HP Smart Tank 500)

**Project:** HP Smart Tank 500 macOS Native Driver (`0x03f0:0x2b54`)  
**Status:** CANONICAL AUDIT DOCUMENT  
**Version:** 0.1.0-alpha  
**Date:** 2026-09-04  

---

## 1. Executive Summary

This document provides a comprehensive legal and software licensing audit of all components comprising the HP Smart Tank 500 macOS driver project. It establishes the licensing framework, verifies license compatibility across linked binaries, and documents compliance with open-source obligations (including LGPL and GPL requirements).

---

## 2. License Compatibility & Matrix

The driver architecture maintains strict boundaries between differing open-source licenses to prevent inadvertent viral license contagion while fulfilling all distribution obligations.

| Component | Target Binary / Distribution | Assigned License | Linked Libraries | Effective Binary License |
| :--- | :--- | :--- | :--- | :--- |
| **`tools/rastertopcl3gui.c`** | `/usr/libexec/cups/filter/rastertopcl3gui` | MIT License | `libcups.2.dylib` (Apache-2.0 w/ Exception) | Permissive / Compatible |
| **`tools/cups_backend_smarttank.c`** | `/usr/libexec/cups/backend/smarttank` | MIT License | `libcups.2.dylib`, `libusb-1.0.dylib` (LGPL-2.1) | Permissive with LGPL Dynamic Linking |
| **`tools/hp_scan.c`** | `/Library/Printers/HP/SmartTank500/bin/hp_scan` | MIT License | `libusb-1.0.dylib` (LGPL-2.1) | Permissive with LGPL Dynamic Linking |
| **`tools/hp-smart-tank-tool.c`** | CLI Diagnostic Tool | MIT License | `libusb-1.0.dylib` (LGPL-2.1) | Permissive with LGPL Dynamic Linking |
| **`tools/hp_escl_bridge.py`** | Background Service Daemon | MIT License | Standard Python 3 Runtime | Permissive (MIT) |
| **`research/builds/...ppd`** | `/Library/Printers/PPDs/Contents/Resources/...` | GPL-2.0+ / MIT | None (Configuration Data) | GPL-2.0+ / MIT Compatible |
| **`io/hpmud/musb.c`** | Non-distributed Reference | GPL-2.0+ (HPLIP) | Not compiled into release payload | N/A (Research Reference Only) |

---

## 3. LGPL-2.1 Compliance Analysis (`libusb-1.0.dylib`)

The USB communication in `smarttank`, `hp_scan`, and `hp-smart-tank-tool` relies on `libusb-1.0`, licensed under the **GNU Lesser General Public License v2.1 (LGPL-2.1)**.

### 3.1 Requirements for LGPL Compliance
Under Section 6 of the LGPL-2.1, a distributor of a work that uses an LGPL library must:
1. Allow reverse engineering for the customer's own use and debugging.
2. Provide a mechanism that allows the user to replace or relink against a modified version of the library.

### 3.2 Verification of Compliance
- **Dynamic Linking:** All binaries link dynamically against `libusb-1.0.0.dylib` rather than statically embedding `libusb.a`:
  ```bash
  otool -L /usr/libexec/cups/backend/smarttank
  # Output: @rpath/libusb-1.0.0.dylib (compatibility version 4.0.0, current version 4.0.0)
  ```
- **RPATH Resolution:** The binary defines `@loader_path/../lib`, `/usr/local/lib`, and `/opt/homebrew/lib` in its `LC_RPATH` load commands.
- **Relinkability:** Any end user can substitute `libusb-1.0.0.dylib` with a custom-compiled version without modifying or recompiling the proprietary or MIT-licensed driver binaries.
- **Source Availability:** A pointer to the official `libusb` source repository and exact build flags is included in the package documentation (`docs/BUILD.md`).

---

## 4. CUPS License Analysis (`libcups.2.dylib`)

Apple macOS ships `/usr/lib/libcups.2.dylib`. Modern CUPS is licensed under the **Apache License 2.0 with the CUPS Exception** (granting permission to link against standard libraries and distribute without source disclosure requirements for external filters). Older versions were under GPL-2.0/LGPL-2.0 with Apple exceptions.

- The CUPS filter (`rastertopcl3gui`) and backend (`smarttank`) communicate via the standard CUPS filter execution interface (stdin raster, stdout/bulk out, stderr logging) and C API.
- Dynamic linking to macOS system `libcups.2.dylib` conforms fully to Apple's SDK agreements and Apache 2.0 terms.

---

## 5. Clean Separation of GPL Reference Code

The directory `io/hpmud/` contains source code from HPLIP licensed under GPL-2.0+.
- **Isolation:** No code from `io/hpmud/` is linked, compiled, or included in any binary distributed within the driver installer (`.pkg`).
- **Research Status:** These files serve solely as reference material for USB protocol reverse engineering and timing analysis.
- **Distribution Rule:** The installer payload build script (`packaging/build_package.sh`) strictly excludes the `io/` directory from the package component payload.

---

## 6. Trademarks and Disclaimers

1. **HP & Hewlett-Packard:** "HP", "Hewlett-Packard", "Smart Tank", and "PCL" are trademarks or registered trademarks of HP Inc.
2. **Apple & macOS:** "Apple", "macOS", "AirPrint", and "ColorSync" are registered trademarks of Apple Inc.
3. **OpenPrinting & CUPS:** "CUPS" is a trademark of OpenPrinting / The Linux Foundation.
4. **Disclaimer of Affiliation:** This project is an independent, community-driven open-source initiative. It is neither developed, sponsored, endorsed, nor certified by HP Inc. or Apple Inc. All trademarks are used strictly for compatibility identification purposes under nominative fair use.
