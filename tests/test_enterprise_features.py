#!/usr/bin/env python3
"""
Test Suite: Enterprise Driver Features
Verifica:
1. Retina Photorealistic Icon (.icns) multi-resolución.
2. Perfiles ColorSync Multi-Stock (Plain, Glossy, Matte).
3. PPD localizado en español y sintaxis aceptada por cupstestppd.
4. LaunchAgent IOKit USB Hardware Matching (0% CPU / 0 MB RAM).
"""

import unittest
import os
import subprocess
import plistlib
import re
from pathlib import Path
import tempfile

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILDS_DIR = os.path.join(BASE_DIR, "research", "builds")
PPD_PATH = os.path.join(BUILDS_DIR, "hp-smart_tank_500_series_mac.ppd")

class TestEnterpriseFeatures(unittest.TestCase):
    def test_01_retina_icon_validity(self):
        icon_path = os.path.join(BUILDS_DIR, "HP_Smart_Tank_500.icns")
        self.assertTrue(os.path.exists(icon_path), "Falta el archivo de icono HP_Smart_Tank_500.icns")
        self.assertGreater(os.path.getsize(icon_path), 20000, "Icono .icns sospechosamente pequeño")
        res = subprocess.run(["file", icon_path], capture_output=True, text=True)
        self.assertIn("Mac OS X icon", res.stdout)

    def test_02_colorsync_multi_paper_profiles(self):
        papers = ["HP_Smart_Tank_Plain.icc", "HP_Smart_Tank_Glossy.icc", "HP_Smart_Tank_Matte.icc"]
        for paper in papers:
            p_path = os.path.join(BUILDS_DIR, paper)
            self.assertTrue(os.path.exists(p_path), f"Falta el perfil ICC: {paper}")
            self.assertGreater(os.path.getsize(p_path), 500)
            res = subprocess.run(["sips", "-g", "all", p_path], capture_output=True, text=True)
            self.assertEqual(res.returncode, 0)
            self.assertIn("typeIdentifier: icc", res.stdout)
            self.assertIn("format: icc", res.stdout)

    def test_03_ppd_conformance_and_localization(self):
        self.assertTrue(os.path.exists(PPD_PATH), "Falta el archivo PPD")
        with open(PPD_PATH, "r", encoding="utf-8") as f:
            content = f.read()

        # Verificar headers clave
        self.assertIn('*cupsLanguages: "en es"', content)
        self.assertIn('*APPrinterIconPath: "/Library/Printers/hp/Icons/HP_Smart_Tank_500.icns"', content)
        self.assertIn('*cupsICCProfile .Plain.600dpi', content)
        self.assertIn('*cupsICCProfile .Glossy.600dpi', content)
        self.assertIn('*cupsICCProfile .CoatedMatte.600dpi', content)

        # Verificar traducciones al español
        self.assertIn('*es.Translation ColorModel/Output Mode: "Modo de Color"', content)
        self.assertIn('*es.ColorModel RGB/Color: "Color Completo (sRGB)"', content)
        self.assertIn('*es.ColorModel KGray/Black Only Grayscale: "Solo Tinta Negra (GT51 Ahorro)"', content)
        self.assertIn('*es.ColorModel CMYGray/High Quality Grayscale: "Escala de Grises Fotografica (Fine-Art)"', content)
        self.assertIn('*es.Translation MediaType/Media Type: "Tipo de Papel"', content)
        self.assertIn('*es.MediaType Glossy/HP Photo Papers: "Papel Fotografico HP"', content)
        self.assertIn('*es.Translation OutputMode/Print Quality: "Calidad de Impresion"', content)
        self.assertIn('*es.PageSize 4x6in.FB/4x6in(10x15cm) Borderless: "10x15 cm (4x6 pulg) Sin Bordes"', content)

        # Verificar conformidad cupstestppd
        res = subprocess.run(["cupstestppd", "-W", "all", PPD_PATH], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        self.assertIn("PASA", res.stdout)

    def test_04_iokit_usb_matching_configuration(self):
        packages = sorted(Path(BUILDS_DIR).glob("HP_Smart_Tank_500_Native_Apple_Silicon-*.pkg"), key=lambda p: p.stat().st_mtime)
        self.assertTrue(packages, "Falta el instalador .pkg para validar LaunchEvents")
        with tempfile.TemporaryDirectory(prefix="hp-plist-test-") as expanded:
            expanded_path = Path(expanded) / "unpacked"
            result = subprocess.run(["pkgutil", "--expand-full", str(packages[-1]), str(expanded_path)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            plist_path = expanded_path / "Payload" / "Library" / "LaunchAgents" / "com.hp.smarttank.airscan.plist"
            self.assertTrue(plist_path.is_file(), "El paquete no contiene el LaunchAgent esperado")
            with plist_path.open("rb") as stream:
                dict_data = plistlib.load(stream)
        self.assertEqual(dict_data["Label"], "com.hp.smarttank.airscan")
        self.assertEqual(dict_data["ProgramArguments"], [
            "/usr/bin/python3",
            "/usr/local/share/hp-smart-tank/hp_escl_bridge.py",
            "--port",
            "8089"
        ])
        self.assertTrue(dict_data["RunAtLoad"])
        self.assertEqual(dict_data["LaunchEvents"]["com.apple.iokit.matching"]["com.hp.smarttank.usbdevice"]["idVendor"], 1008)
        self.assertEqual(dict_data["LaunchEvents"]["com.apple.iokit.matching"]["com.hp.smarttank.usbdevice"]["idProduct"], 11092)

    def test_05_package_integrity_and_backend(self):
        packages = sorted(Path(BUILDS_DIR).glob("HP_Smart_Tank_500_Native_Apple_Silicon-*.pkg"), key=lambda p: p.stat().st_mtime)
        self.assertTrue(packages, "Falta el instalador .pkg auditado")
        pkg_path = str(packages[-1])
        self.assertTrue(os.path.exists(pkg_path), "Falta el instalador .pkg")
        self.assertGreater(os.path.getsize(pkg_path), 50000, "Instalador .pkg sospechosamente pequeño")
        
        # Verificar payload con pkgutil
        res = subprocess.run(["pkgutil", "--payload-files", pkg_path], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0)
        payload = res.stdout
        self.assertIn("./Library/Printers/hp/cups/backend/smarttank", payload)
        self.assertIn("./Library/Printers/hp/cups/filters/rastertopcl3gui", payload)
        self.assertIn("./Applications/HP Smart Tank Utility.app/Contents/MacOS/HP Smart Tank Utility", payload)
        self.assertIn("./Library/Printers/hp/Icons/HP_Smart_Tank_500.icns", payload)
        self.assertIn("./Library/LaunchAgents/com.hp.smarttank.airscan.plist", payload)
        self.assertIn("./usr/local/lib/libusb-1.0.0.dylib", payload)
        self.assertIn("./usr/local/share/hp-smart-tank/uninstall.sh", payload)
        with tempfile.TemporaryDirectory(prefix="hp-pkg-test-") as expanded:
            expanded_path = Path(expanded) / "unpacked"
            expand = subprocess.run(["pkgutil", "--expand-full", pkg_path, str(expanded_path)], capture_output=True, text=True)
            self.assertEqual(expand.returncode, 0, expand.stderr)
            materialized = list((expanded_path / "Payload").rglob("*") )
            self.assertFalse(any(p.name.startswith("._") for p in materialized))
            materialized_text = "\n".join(str(p) for p in materialized)
            for forbidden in ("/opt/homebrew", "/Users/jorge", "research/", "scratch/", "Downloads/"):
                self.assertNotIn(forbidden, materialized_text)

        uninstall = (Path(BASE_DIR) / "uninstall.sh").read_text(encoding="utf-8")
        for owned in (
            "/usr/local/lib/libusb-1.0.0.dylib",
            "/usr/local/share/hp-smart-tank/hp_smart_tank.py",
            "/Applications/HP Smart Tank Utility.app",
            "/Library/Printers/hp/cups/backend/smarttank",
            "/usr/local/share/hp-smart-tank/uninstall.sh",
        ):
            self.assertIn(owned, uninstall)

if __name__ == "__main__":
    unittest.main()
