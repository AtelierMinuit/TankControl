import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class TestSecurityHardening(unittest.TestCase):
    def test_usb_locks_reject_symlinks(self):
        sources = (
            ROOT / "tools" / "cups_backend_smarttank.c",
            ROOT / "tools" / "hp_scan.c",
            ROOT / "tools" / "hp-smart-tank-tool.c",
        )
        for source in sources:
            text = source.read_text(encoding="utf-8")
            self.assertIn(
                "O_RDWR | O_CREAT | O_NOFOLLOW",
                text,
                f"falta O_NOFOLLOW en {source.name}",
            )

    def test_escl_bridge_is_not_bound_to_wildcard(self):
        text = (ROOT / "tools" / "hp_escl_bridge.py").read_text(encoding="utf-8")
        self.assertNotIn("0.0.0.0", text)
        self.assertIn("127.0.0.1", text)

    def test_escl_jobs_use_private_temp_directories(self):
        text = (ROOT / "tools" / "hp_escl_bridge.py").read_text(encoding="utf-8")
        self.assertIn("tempfile.mkdtemp", text)
        self.assertNotIn("NamedTemporaryFile", text)

    def test_native_scanner_requires_explicit_output(self):
        text = (ROOT / "tools" / "hp_scan.c").read_text(encoding="utf-8")
        self.assertIn("if (argc < 2)", text)
        self.assertIn("ruta de salida explícita", text)
        self.assertNotIn("hp_smart_tank_scan.jpg", text)

    def test_terminal_wrapper_requires_explicit_hardware_confirmation(self):
        text = (ROOT / "tools" / "hp-smart-tank").read_text(encoding="utf-8")
        self.assertIn('read -r -p "Escribe CONFIRMAR', text)
        self.assertIn("--confirm-hardware", text)
        self.assertIn("Uso: hp-smart-tank scan <ruta-salida>", text)
        self.assertNotIn("/tmp/escaneo.jpg", text)

    def test_icc_calibration_uses_private_temp_directory(self):
        text = (ROOT / "tools" / "calibrate_icc.py").read_text(encoding="utf-8")
        self.assertIn("tempfile.mkdtemp(prefix=\"hp-icc-scan-\")", text)
        self.assertNotIn('Path("/tmp/calibration_scan.ppm")', text)

    def test_terminal_wrapper_uses_packaged_share_scripts(self):
        text = (ROOT / "tools" / "hp-smart-tank").read_text(encoding="utf-8")
        self.assertIn('"${SHARE_DIR}/generate_color_target.py"', text)
        self.assertIn('"${SHARE_DIR}/calibrate_icc.py"', text)
        self.assertNotIn('"${SCRIPT_DIR}/generate_color_target.py"', text)
        self.assertNotIn('"${SCRIPT_DIR}/calibrate_icc.py"', text)

    def test_icon_generator_uses_private_temp_directory(self):
        text = (ROOT / "tools" / "generate_printer_icon.py").read_text(encoding="utf-8")
        self.assertIn('tempfile.mkdtemp(prefix="hp-smart-tank-icon-")', text)
        self.assertNotIn('Path("/tmp/hp_smart_tank_iconset.iconset")', text)

    def test_wrapper_calibration_scan_uses_private_temp_directory(self):
        text = (ROOT / "tools" / "hp-smart-tank").read_text(encoding="utf-8")
        self.assertIn('mktemp -d "${TMPDIR:-/tmp}/hp-smart-tank-scan.XXXXXX"', text)
        self.assertNotIn('/tmp/calib_scan.jpg', text)

    def test_python_usb_client_limits_http_responses(self):
        text = (ROOT / "tools" / "hp_smart_tank.py").read_text(encoding="utf-8")
        self.assertIn("MAX_HTTP_RESPONSE = 1024 * 1024", text)
        self.assertIn("Respuesta HTTP USB sin Content-Length", text)
        self.assertIn("Content-Length HTTP USB demasiado grande", text)

    def test_backend_sanitizes_debug_log_fields(self):
        text = (ROOT / "tools" / "cups_backend_smarttank.c").read_text(encoding="utf-8")
        self.assertIn("char safe_options[512]", text)
        self.assertIn("sanitize_log_field(options, safe_options", text)
        self.assertIn("safe_job, safe_title, safe_user, copies, safe_options", text)

    def test_app_passes_cli_confirmation_after_visual_confirmation(self):
        text = (ROOT / "apps" / "HPSmartTankUtility" / "Sources" / "main.swift").read_text(encoding="utf-8")
        self.assertIn('runToolCommand([command, "--confirm-hardware"])', text)
        self.assertIn('runToolCommand(["inject-raw", testFile, "--confirm-hardware"])', text)
        self.assertIn('runToolCommand(["test-pattern", type, "--confirm-hardware"])', text)
        self.assertIn('runToolCommand(["prime-tubes", "--confirm-hardware"])', text)

    def test_package_rejects_incomplete_builds_before_staging(self):
        text = (ROOT / "package_dist.sh").read_text(encoding="utf-8")
        self.assertIn("set -Eeuo pipefail", text)
        self.assertIn("bundle SwiftUI ausente o incompleto", text)
        self.assertIn("helper requerido ausente o no ejecutable", text)
        self.assertIn("codesign --verify --deep --strict", text)
        self.assertIn("binario requerido ausente o no ejecutable", text)

    def test_scan_read_commands_propagate_transport_failure(self):
        text = (ROOT / "tools" / "hp-smart-tank-tool.c").read_text(encoding="utf-8")
        self.assertIn("No se recibieron capacidades del escáner desde el hardware", text)
        self.assertIn("No se recibió estado del escáner desde el hardware", text)
        self.assertGreaterEqual(text.count("command_exit_code = 1;"), 5)

    def test_backend_validates_copy_count_strictly(self):
        text = (ROOT / "tools" / "cups_backend_smarttank.c").read_text(encoding="utf-8")
        self.assertIn("static int parse_copies", text)
        self.assertIn("parsed < 1 || parsed > 10000", text)
        self.assertNotIn("int copies = atoi(argv[4]);", text)

    def test_backend_handles_monitor_thread_creation_failure(self):
        text = (ROOT / "tools" / "cups_backend_smarttank.c").read_text(encoding="utf-8")
        self.assertIn("int monitor_started = (pthread_create", text)
        self.assertIn("if (monitor_started)", text)


if __name__ == "__main__":
    unittest.main()
