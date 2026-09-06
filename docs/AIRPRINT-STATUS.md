# AirPrint & IPP Architecture Status (HP Smart Tank 500)

**Project:** HP Smart Tank 500 macOS Native Driver (`0x03f0:0x2b54`)  
**Status:** CANONICAL DOCUMENTATION — IPP & AIRPRINT EMULATION  
**Version:** 0.1.0-alpha  
**Date:** 2026-09-04  

---

## 1. Executive Summary

The HP Smart Tank 500 is fundamentally a **USB-only, non-networked** all-in-one printer. It lacks built-in Ethernet, Wi-Fi, and native AirPrint/IPP firmware.

To provide AirPrint capability to macOS and iOS clients on the local network, this project implements a host-based IPP emulation bridge that exposes the USB printer as an Apple AirPrint-compliant print service over mDNS/DNS-SD.

---

## 2. Capability & Verification Status Matrix

In compliance with the project's formal verification taxonomy:

| Subsystem Component | Implementation State | Verification State | Operational Condition |
| :--- | :--- | :--- | :--- |
| **IPP 2.0 Core Protocol** | `IMPLEMENTED` | `UNIT VERIFIED` / `INTEGRATION VERIFIED` | Fully verified against RFC 8010/8011 spec |
| **IPP Print Job Pipeline** | `IMPLEMENTED` | `MOCK VERIFIED` | PDF/Raster to PCL3GUI conversion tested end-to-end |
| **mDNS / Bonjour Broadcast** | `IMPLEMENTED` | `INTEGRATION VERIFIED` | `_ipp._tcp`, `_universal._sub._ipp._tcp` verified via `dns-sd` |
| **macOS Native Print Client** | `IMPLEMENTED` | `INTEGRATION VERIFIED` | macOS CUPS client can discover and spool to local bridge |
| **iOS AirPrint Client (Physical)**| `PARTIAL` | `HARDWARE REQUIRED` | Requires physical iOS device + real USB printer attached |
| **Hardware Raster Output** | `IMPLEMENTED` | `HARDWARE REQUIRED` | Requires physical HP Smart Tank 500 to confirm paper output |

---

## 3. Architecture of the IPP Bridge

```
[iOS / iPadOS / macOS AirPrint Client]
                │
                ▼ (mDNS Discovery: _ipp._tcp, URF=W8,SRGB24,CP1,DM1)
        [dns-sd / mDNSResponder]
                │
                ▼ (IPP/2.0 over HTTP/1.1: Print-Job, Get-Printer-Attributes)
    [IPP Emulation Host Service]
    ├── Option A: /usr/bin/ippeveprinter (LaunchAgent: org.openprinting.smarttank.ipp.plist)
    ├── Option B: Embedded Pure Python IPP Server (tools/hp_ipp_server.py)
    └── Option C: Native CUPS Shared Queue (cupsctl --share-printers)
                │
                ▼ (Spools PDF / Apple Raster / PWG Raster)
        [tools/rastertopcl3gui]
                │
                ▼ (Mode 10 Compressed PCL3GUI Stream)
      [tools/cups_backend_smarttank]
                │
                ▼ (USB Bulk OUT Endpoint 0x05)
      [HP Smart Tank 500 USB Device]
```

---

## 4. Host Service Strategies & Portability

### Strategy A: System `ippeveprinter` (Current Production Path)
- **Path:** `/usr/bin/ippeveprinter`
- **Availability:** Shipped by Apple in macOS 12 (Monterey), 13 (Ventura), 14 (Sonoma), and 15 (Sequoia).
- **Service Configuration:** Managed via `Library/LaunchAgents/com.hp.smarttank500.ipp.plist`.
- **Command Invocation:**
  ```bash
  /usr/bin/ippeveprinter -p 8631 -n "HP Smart Tank 500 (AirPrint)" \
      -K /Library/Printers/HP/SmartTank500/HP_Smart_Tank_500.ppd \
      -c /Library/Printers/HP/SmartTank500/rastertopcl3gui \
      "HP Smart Tank 500"
  ```
- **Pros:** Native Apple binary, minimal footprint, full PWG/AirPrint conformance.
- **Cons:** Dependent on Apple's ongoing inclusion of CUPS command-line utilities in future macOS versions.

### Strategy B: Embedded IPP Micro-Server (Portable Fallback)
- **Implementation:** Python-based minimal IPP responder (`tools/hp_ipp_server.py`) using `socketserver` and pure Python IPP framing.
- **Availability:** Fully autonomous, zero external dependencies.
- **Pros:** Platform-independent, immune to macOS CUPS CLI deprecations.
- **Cons:** Requires active Python runtime; slightly higher memory footprint.

### Strategy C: Native CUPS Queue Sharing (Enterprise Path)
- **Implementation:**
  ```bash
  cupsctl --share-printers --remote-any
  lpadmin -p "HP_Smart_Tank_500" -o printer-is-shared=true
  ```
- **Availability:** Standard CUPS capability.
- **Pros:** Completely managed by macOS `cupsd`.
- **Cons:** Requires macOS printer sharing to be enabled globally in System Settings, which users frequently keep disabled for security.

---

## 5. AirPrint URF / PWG Raster Attributes

For complete AirPrint compatibility with iOS clients, the printer advertises the following DNS-SD TXT record keys:

```text
txtvers=1
qtotal=1
rp=ipp/print
pdl=application/pdf,image/urf,image/pwg-raster
URF=W8,SRGB24,CP1,DM1
ty=HP Smart Tank 500 Series
product=(HP Smart Tank 500)
adminurl=http://localhost:8631/
priority=10
usb_MDL=Smart Tank 500 series
usb_MFG=HP
Color=T
Duplex=F
Scan=T
```

---

## 6. Physical Hardware Validation Checklist (Pending Hardware)

When the HP Smart Tank 500 hardware is connected:
1. Start IPP service via `launchctl load ~/Library/LaunchAgents/com.hp.smarttank500.ipp.plist`.
2. Verify discovery on an iPhone/iPad running iOS 17/18 on the same Wi-Fi subnet.
3. Submit 1-page text job from iOS Notes app. Verify printout.
4. Submit multi-page mixed photo/text job from iOS Photos app. Verify printout.
5. Verify job accounting and completion signaling back to the iOS device.
