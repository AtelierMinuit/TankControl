#!/usr/bin/env python3
"""
Tests unitarios para el Verificador de Actualizaciones de GitHub Releases y el Arranque Automático
en TankControl (HP Smart Tank 500).
Valida:
1. Comparación semántica de versiones (ej. v1.3.0 > v1.2.0).
2. Estructura del modelo GitHubReleaseResponse.
3. Existencia de UpdateCheckerService.swift y LaunchAtLoginService.swift.
4. Integración en SettingsView.swift.
"""

from __future__ import annotations

from pathlib import Path
import unittest

PROJECT_ROOT = Path(__file__).resolve().parents[1]
APP_SOURCES = PROJECT_ROOT / "apps" / "HPSmartTankUtility" / "Sources"
UPDATE_SERVICE_PATH = APP_SOURCES / "Services" / "UpdateCheckerService.swift"
LAUNCH_SERVICE_PATH = APP_SOURCES / "Services" / "LaunchAtLoginService.swift"
SETTINGS_VIEW_PATH = APP_SOURCES / "Views" / "SettingsView.swift"


def is_version_greater(v1: str, v2: str) -> bool:
    """Replica la lógica de comparación semántica de UpdateCheckerService.swift."""
    v1_clean = v1.lstrip("vV ")
    v2_clean = v2.lstrip("vV ")
    p1 = [int(x) for x in v1_clean.split(".") if x.isdigit()]
    p2 = [int(x) for x in v2_clean.split(".") if x.isdigit()]

    count = max(len(p1), len(p2))
    for i in range(count):
        num1 = p1[i] if i < len(p1) else 0
        num2 = p2[i] if i < len(p2) else 0
        if num1 > num2:
            return True
        if num1 < num2:
            return False
    return False


class TestUpdateCheckerAndLaunch(unittest.TestCase):
    """Verifica el comparador de versiones y los servicios de inicio y actualización."""

    def test_sources_exist(self):
        """Verifica que los archivos fuente existan."""
        self.assertTrue(UPDATE_SERVICE_PATH.exists(), f"UpdateCheckerService debe existir en {UPDATE_SERVICE_PATH}")
        self.assertTrue(LAUNCH_SERVICE_PATH.exists(), f"LaunchAtLoginService debe existir en {LAUNCH_SERVICE_PATH}")
        self.assertTrue(SETTINGS_VIEW_PATH.exists(), f"SettingsView debe existir en {SETTINGS_VIEW_PATH}")

    def test_version_comparisons(self):
        """Valida que la comparación de versiones semánticas sea rigurosa."""
        self.assertTrue(is_version_greater("v1.3.0", "v1.2.0"))
        self.assertTrue(is_version_greater("1.2.1", "1.2.0"))
        self.assertTrue(is_version_greater("2.0.0", "1.9.9"))
        self.assertTrue(is_version_greater("v1.2.0.1", "v1.2.0"))

        self.assertFalse(is_version_greater("v1.2.0", "v1.2.0"))
        self.assertFalse(is_version_greater("1.1.9", "1.2.0"))
        self.assertFalse(is_version_greater("v1.0.0", "v2.0.0"))

    def test_update_service_swift_content(self):
        """Valida la estructura de UpdateCheckerService.swift."""
        content = UPDATE_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("class UpdateCheckerService", content)
        self.assertIn("api.github.com/repos/AtelierMinuit/TankControl/releases/latest", content)
        self.assertIn("checkForUpdates", content)
        self.assertIn("openLatestRelease", content)

    def test_launch_at_login_service_swift_content(self):
        """Valida la estructura de LaunchAtLoginService.swift y el soporte SMAppService."""
        content = LAUNCH_SERVICE_PATH.read_text(encoding="utf-8")
        self.assertIn("class LaunchAtLoginService", content)
        self.assertIn("SMAppService.mainApp", content)
        self.assertIn("isEnabled", content)

    def test_settings_view_includes_controls(self):
        """SettingsView debe incluir controles para arranque y actualizaciones."""
        content = SETTINGS_VIEW_PATH.read_text(encoding="utf-8")
        self.assertIn("launchService", content)
        self.assertIn("updateChecker", content)
        self.assertIn("settings_launch_at_login_title", content)
        self.assertIn("settings_updates_check_btn", content)


if __name__ == "__main__":
    unittest.main()
