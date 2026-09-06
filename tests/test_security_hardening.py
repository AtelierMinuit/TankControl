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
        self.assertIn("complete = False", text)
        self.assertIn("if not complete:", text)

    def test_backend_sanitizes_debug_log_fields(self):
        text = (ROOT / "tools" / "cups_backend_smarttank.c").read_text(encoding="utf-8")
        self.assertIn("char safe_options[512]", text)
        self.assertIn("sanitize_log_field(options, safe_options", text)
        self.assertIn("safe_job, safe_title, safe_user, copies, safe_options", text)

    def test_app_passes_cli_confirmation_after_visual_confirmation(self):
        text = (ROOT / "apps" / "HPSmartTankUtility" / "Sources" / "main.swift").read_text(encoding="utf-8")
        self.assertIn('runToolCommand([command, "--confirm-hardware"])', text)
        self.assertIn('func toolBinaryPath() -> String?', text)
        self.assertNotIn('/usr/local/bin/hp-smart-tank-tool', text)
        self.assertIn('return nil', text)
        self.assertIn('No se encontró un helper regular y ejecutable dentro del bundle', text)
        self.assertIn('runToolCommand(["inject-raw", testFile, "--confirm-hardware"])', text)
        self.assertIn('runToolCommand(["test-pattern", type, "--confirm-hardware"])', text)
        self.assertIn('runToolCommand(["prime-tubes", "--confirm-hardware"])', text)
        self.assertIn('private var activeAlertKeys = Set<String>()', text)
        self.assertIn('if !activeAlertKeys.contains(key)', text)
        self.assertIn('activeAlertKeys = currentAlertKeys', text)

    def test_package_rejects_incomplete_builds_before_staging(self):
        text = (ROOT / "package_dist.sh").read_text(encoding="utf-8")
        self.assertIn("set -Eeuo pipefail", text)
        self.assertIn("bundle SwiftUI ausente o incompleto", text)
        self.assertIn("helper requerido ausente o no ejecutable", text)
        self.assertIn("codesign --verify --deep --strict", text)
        self.assertIn("binario requerido ausente o no ejecutable", text)

    def test_manual_installer_requires_explicit_build_and_installs_backend(self):
        text = (ROOT / "install_native.sh").read_text(encoding="utf-8")
        self.assertIn('HP_AUDIT_BUILD_DIR', text)
        self.assertIn('define HP_AUDIT_BUILD_DIR', text)
        self.assertIn('BACKEND_BIN="$BUILD_DIR/smarttank"', text)
        self.assertIn('TARGET_BACKEND="$TARGET_BACKEND_DIR/smarttank"', text)
        self.assertIn('smarttank://HP/Smart%20Tank%20500%20series', text)
        self.assertIn('ya existe un componente destino', text)

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

    def test_terminal_wrapper_protects_diagnostic_page(self):
        text = (ROOT / "tools" / "hp-smart-tank").read_text(encoding="utf-8")
        self.assertIn('if confirm_hardware; then "${BIN_TOOL}" diag-page --confirm-hardware;', text)
        self.assertNotIn('"${BIN_TOOL}" diag-page\n', text)

    def test_terminal_wrapper_rejects_non_regular_tool(self):
        text = (ROOT / "tools" / "hp-smart-tank").read_text(encoding="utf-8")
        self.assertIn('[ -L "${BIN_TOOL}" ]', text)
        self.assertIn('[ ! -x "${BIN_TOOL}" ]', text)

    def test_uninstaller_preserves_foreign_queue_and_app(self):
        text = (ROOT / "uninstall.sh").read_text(encoding="utf-8")
        self.assertIn('lpstat -v "HP_Smart_Tank_500"', text)
        self.assertIn("smarttank://", text)
        self.assertIn('pkgutil --pkg-info "com.hp.smarttank500.driver.applesilicon"', text)
        self.assertIn("Preservando app", text)

    def test_postinstall_does_not_recurse_into_foreign_icons(self):
        text = (ROOT / "research" / "package_scripts" / "postinstall").read_text(encoding="utf-8")
        self.assertIn("require_regular_owned_path", text)
        self.assertIn('HP_Smart_Tank_500.icns', text)
        self.assertNotIn('chown -R root:wheel "$ICON_DIR"', text)

    def test_native_installer_preserves_existing_queue(self):
        text = (ROOT / "install_native.sh").read_text(encoding="utf-8")
        self.assertIn('lpstat -p "HP_Smart_Tank_500"', text)
        self.assertIn("no se reconfigurará automáticamente", text)
        self.assertIn('MODE="${1:-}"', text)
        self.assertIn('MODO DRY-RUN', text)
        self.assertIn('SE INSTALARÍA:', text)

    def test_postinstall_preserves_existing_queue(self):
        text = (ROOT / "research" / "package_scripts" / "postinstall").read_text(encoding="utf-8")
        self.assertIn('lpstat -p "HP_Smart_Tank_500"', text)
        self.assertIn("ya existe; se preserva", text)


if __name__ == "__main__":
    unittest.main()
