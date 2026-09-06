#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
tests/test_app_architecture.py
Auditoría y pruebas unitarias automatizadas para la arquitectura de TankControl.app.
Valida la integridad del bundle, Info.plist, iconos, firmas ad-hoc y seguridad de subprocesos.
"""

import json
import os
import plistlib
import subprocess
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
BUILD_DIR = os.environ.get("HP_AUDIT_BUILD_DIR", os.path.join(REPO_ROOT, "research/builds/audit-clean/night-20260904"))
APP_PATH = os.path.join(BUILD_DIR, "TankControl.app")
LEGACY_APP_PATH = os.path.join(BUILD_DIR, "HP Smart Tank Utility.app")
SOURCES_DIR = os.path.join(REPO_ROOT, "apps/HPSmartTankUtility/Sources")
BRAND_DIR = os.path.join(REPO_ROOT, "Brand")


class TestAppBundleStructure(unittest.TestCase):
    """Verifica que el bundle de macOS cumpla con los estándares Apple Silicon."""

    def test_app_bundle_exists(self):
        self.assertTrue(os.path.isdir(APP_PATH), f"No existe el bundle oficial: {APP_PATH}")

    def test_legacy_app_bundle_exists_for_backwards_compat(self):
        self.assertTrue(os.path.isdir(LEGACY_APP_PATH), f"No existe el bundle de compatibilidad: {LEGACY_APP_PATH}")

    def test_executable_is_arm64_macho(self):
        binary = os.path.join(APP_PATH, "Contents/MacOS/TankControl")
        self.assertTrue(os.path.isfile(binary), f"Falta el binario principal: {binary}")
        self.assertTrue(os.access(binary, os.X_OK), "El binario no tiene permisos de ejecución")

        file_out = subprocess.check_output(["file", binary], text=True)
        self.assertIn("Mach-O 64-bit executable arm64", file_out)

    def test_info_plist_metadata(self):
        plist_path = os.path.join(APP_PATH, "Contents/Info.plist")
        self.assertTrue(os.path.isfile(plist_path), "Falta Contents/Info.plist")

        with open(plist_path, "rb") as f:
            plist = plistlib.load(f)

        self.assertEqual(plist.get("CFBundleExecutable"), "TankControl")
        self.assertEqual(plist.get("CFBundleName"), "TankControl")
        self.assertEqual(plist.get("CFBundleIdentifier"), "org.openprinting.tankcontrol")
        self.assertEqual(plist.get("CFBundleShortVersionString"), "0.1.0-alpha")
        self.assertEqual(plist.get("CFBundleIconFile"), "AppIcon")
        self.assertEqual(plist.get("LSMinimumSystemVersion"), "12.0")

    def test_helpers_present_and_regular_files(self):
        helpers_dir = os.path.join(APP_PATH, "Contents/Helpers")
        self.assertTrue(os.path.isdir(helpers_dir))

        for helper in ["hp-smart-tank-tool", "hp_scan"]:
            h_path = os.path.join(helpers_dir, helper)
            if os.path.exists(h_path):
                self.assertFalse(os.path.islink(h_path), f"El helper {helper} no debe ser symlink")
                self.assertTrue(os.path.isfile(h_path))
                self.assertTrue(os.access(h_path, os.X_OK))

    def test_codesign_adhoc_integrity(self):
        cmd = ["codesign", "--verify", "--deep", "--strict", APP_PATH]
        res = subprocess.run(cmd, capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, f"Error en verificación codesign: {res.stderr}")


class TestBrandAndIconography(unittest.TestCase):
    """Verifica los assets visuales, iconset y formato .icns oficial."""

    def test_icns_file_exists_and_not_empty(self):
        icns_path = os.path.join(BRAND_DIR, "AppIcon/AppIcon.icns")
        self.assertTrue(os.path.isfile(icns_path), f"Falta archivo .icns: {icns_path}")
        self.assertGreater(os.path.getsize(icns_path), 500000, "El .icns es demasiado pequeño")

    def test_master_icon_resolution(self):
        master_png = os.path.join(BRAND_DIR, "AppIcon/AppIcon_1024x1024.png")
        self.assertTrue(os.path.isfile(master_png), f"Falta icono maestro: {master_png}")

        # Comprobar dimensiones con sips
        out = subprocess.check_output(["sips", "-g", "pixelWidth", "-g", "pixelHeight", master_png], text=True)
        self.assertIn("pixelWidth: 2048", out)
        self.assertIn("pixelHeight: 2048", out)

    def test_appiconset_contents_json(self):
        json_path = os.path.join(BRAND_DIR, "AppIcon/AppIcon.appiconset/Contents.json")
        self.assertTrue(os.path.isfile(json_path))

        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        self.assertIn("images", data)
        self.assertGreaterEqual(len(data["images"]), 10)
        idioms = {img.get("idiom") for img in data["images"]}
        self.assertIn("mac", idioms)


class TestSourceCodeSecurityAndArchitecture(unittest.TestCase):
    """Audita el código fuente de la aplicación para prevenir vulnerabilidades."""

    def test_no_shell_invocation_in_swift_sources(self):
        """Verifica que ningún archivo Swift invoque shells tipo /bin/sh o /bin/bash con -c."""
        for root, _, files in os.walk(SOURCES_DIR):
            for file in files:
                if file.endswith(".swift"):
                    file_path = os.path.join(root, file)
                    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                    self.assertNotIn('"/bin/sh"', content, f"Posible invocación de shell insegura en {file}")
                    self.assertNotIn('"/bin/bash"', content, f"Posible invocación de shell insegura en {file}")

    def test_modular_structure_completeness(self):
        """Verifica la existencia de los módulos requeridos por la arquitectura."""
        expected_modules = [
            "Design/DesignTokens.swift",
            "Design/Components/StatusBadge.swift",
            "Design/Components/InkTankGauge.swift",
            "Design/Components/ActionCard.swift",
            "Design/Components/ConfirmationSheet.swift",
            "Design/Components/DiagnosticRow.swift",
            "Design/Components/MetricCard.swift",
            "Models/PrinterConnectionState.swift",
            "Models/SupplyItem.swift",
            "Models/OdometerData.swift",
            "Models/SmartTankError.swift",
            "Models/Preset.swift",
            "Models/DiagnosticItem.swift",
            "Services/ProcessRunner.swift",
            "Services/SmartTankServiceProtocol.swift",
            "Services/MockSmartTankService.swift",
            "Services/RealSmartTankService.swift",
            "Services/PrinterManager.swift",
            "Services/InkSaverService.swift",
            "Services/ScannerService.swift",
            "Views/MainSplitView.swift",
            "Views/DashboardView.swift",
            "Views/PrintCenterView.swift",
            "Views/ScannerView.swift",
            "Views/InkSaverCenterView.swift",
            "Views/StatusView.swift",
            "Views/MaintenanceView.swift",
            "Views/DiagnosticsView.swift",
            "Views/SettingsView.swift",
            "Views/HelpView.swift",
            "main.swift"
        ]
        for rel_path in expected_modules:
            full_path = os.path.join(SOURCES_DIR, rel_path)
            self.assertTrue(os.path.isfile(full_path), f"Módulo Swift faltante: {rel_path}")


if __name__ == "__main__":
    unittest.main()
