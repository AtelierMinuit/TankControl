import Cocoa
import SwiftUI
import UserNotifications

// MARK: - Modelos de Datos

struct SupplyItem: Codable, Identifiable {
    var id: String { code }
    let code: String
    let name: String
    let level: Int
    let state: String

    var color: Color {
        switch code {
        case "K": return Color.black
        case "C": return Color(red: 0.0, green: 0.7, blue: 0.9)
        case "M": return Color(red: 0.9, green: 0.1, blue: 0.6)
        case "Y": return Color(red: 0.95, green: 0.8, blue: 0.1)
        default: return Color.gray
        }
    }

    var colorName: String {
        switch code {
        case "K": return "Negro (K)"
        case "C": return "Cian (C)"
        case "M": return "Magenta (M)"
        case "Y": return "Amarillo (Y)"
        default: return name
        }
    }
}

struct SuppliesResponse: Codable {
    let connected: Bool
    let supplies: [SupplyItem]?
    let error: String?
}

struct StatusResponse: Codable {
    let connected: Bool
    let status: String?
    let description: String?
}

struct OdometerDrops: Codable {
    let k: Int?
    let c: Int?
    let m: Int?
    let y: Int?
}

struct OdometerResponse: Codable {
    let connected: Bool
    let mock: Bool?
    let total_pages: Int?
    let mono_pages: Int?
    let color_pages: Int?
    let borderless_pages: Int?
    let scans: Int?
    let jams: Int?
    let pick_failures: Int?
    let drops: OdometerDrops?
}

// MARK: - Manager de Hardware

class PrinterManager: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var statusDescription: String = "Detectando impresora..."
    @Published var statusCategory: String = "unknown"
    @Published var supplies: [SupplyItem] = []
    @Published var odometer: OdometerResponse? = nil
    @Published var isBusy: Bool = false
    @Published var busyMessage: String = ""
    @Published var useMock: Bool = false
    var onUpdate: (() -> Void)?

    private var refreshTimer: Timer?
    private var refreshInFlight = false

    init() {
        scheduleRefresh(after: 0.0)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func toolBinaryPath() -> String? {
        let bundlePath = Bundle.main.bundlePath
        let possiblePaths = [
            Bundle.main.path(forResource: "hp-smart-tank-tool", ofType: nil),
            bundlePath + "/Contents/Helpers/hp-smart-tank-tool",
            "/usr/local/bin/hp-smart-tank-tool"
        ]
        for p in possiblePaths {
            if let p = p,
               FileManager.default.isExecutableFile(atPath: p),
               let values = try? URL(fileURLWithPath: p).resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
               values.isRegularFile == true,
               values.isSymbolicLink != true {
                return URL(fileURLWithPath: p).standardizedFileURL.path
            }
        }
        return nil
    }

    func runToolCommand(_ args: [String]) -> String {
        guard let bin = toolBinaryPath() else {
            return "[ERROR] No se encontró un helper regular y ejecutable dentro del bundle."
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: bin)
        var finalArgs = args
        if useMock && !finalArgs.contains("--mock") {
            finalArgs.append("--mock")
        }
        task.arguments = finalArgs
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            let timeout = DispatchWorkItem {
                if task.isRunning {
                    task.terminate()
                }
            }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 30.0, execute: timeout)
            task.waitUntilExit()
            timeout.cancel()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            if task.terminationStatus != 0 {
                return "[ERROR] El comando terminó con código \(task.terminationStatus).\n\(output)"
            }
            return output
        } catch {
            return "[ERROR] No se pudo ejecutar la herramienta: \(error.localizedDescription)"
        }
    }

    func refresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.refreshInFlight else { return }
            self.refreshInFlight = true
            self.performRefresh()
        }
    }

    private func scheduleRefresh(after interval: TimeInterval) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
    }

    private func performRefresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 1. Estado
            let statusRaw = self.runToolCommand(["json-status"])
            var newStatus = "Desconectada o apagada"
            var newCat = "disconnected"
            var newConnected = false

            if let data = statusRaw.data(using: .utf8),
               let resp = try? JSONDecoder().decode(StatusResponse.self, from: data) {
                newConnected = resp.connected
                newStatus = resp.description ?? "Listo"
                newCat = resp.status ?? "ready"
            }

            // 2. Suministros
            let suppliesRaw = self.runToolCommand(["json-supplies"])
            var newSupplies: [SupplyItem] = []

            if let data = suppliesRaw.data(using: .utf8),
               let resp = try? JSONDecoder().decode(SuppliesResponse.self, from: data),
               let items = resp.supplies {
                newSupplies = items
                if resp.connected { newConnected = true }
            }

            // 3. Odómetro / Telemetría
            let odoRaw = self.runToolCommand(["json-odometer"])
            var newOdo: OdometerResponse? = nil
            if let data = odoRaw.data(using: .utf8),
               let resp = try? JSONDecoder().decode(OdometerResponse.self, from: data) {
                newOdo = resp
                if resp.connected { newConnected = true }
            }

            DispatchQueue.main.async {
                self.refreshInFlight = false
                self.isConnected = newConnected
                self.statusDescription = newStatus
                self.statusCategory = newCat
                self.odometer = newOdo
                // Una respuesta ausente no es un nivel cero: limpiar la lectura
                // evita representar desconexión o error de transporte como tinta agotada.
                self.supplies = newSupplies
                self.onUpdate?()
                // USB ausente no debe generar polling agresivo; conectado permite
                // detectar cambios de estado con menor latencia.
                self.scheduleRefresh(after: newConnected ? 4.0 : 15.0)
            }
        }
    }

    func executeAction(name: String, command: String, completionDesc: String) {
        isBusy = true
        busyMessage = "\(name) en progreso..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            // La confirmación visual precede a este punto; el binario CLI
            // conserva además su propia barrera explícita.
            let output = self.runToolCommand([command, "--confirm-hardware"])
            let failed = output.hasPrefix("[ERROR]")
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                if failed {
                    let alert = NSAlert()
                    alert.messageText = "Operación no completada"
                    alert.informativeText = output
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Entendido")
                    alert.runModal()
                }
                self.refresh()
            }
        }
    }

    @discardableResult
    func confirmRiskyAction(_ title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancelar")
        alert.addButton(withTitle: "Continuar")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func cleanHeads() {
        guard confirmRiskyAction("Limpieza básica", message: "Esta operación consume tinta y actúa físicamente sobre los cabezales. ¿Deseas continuar?") else { return }
        executeAction(name: "Limpieza Nivel 1", command: "clean-heads", completionDesc: "Limpieza completada")
    }

    func deepClean() {
        guard confirmRiskyAction("Purga profunda", message: "Esta operación puede consumir tinta y someter la impresora a un ciclo intensivo. ¿Deseas continuar?") else { return }
        executeAction(name: "Purga Nivel 2", command: "deep-clean", completionDesc: "Purga completada")
    }

    func cleanRollers() {
        guard confirmRiskyAction("Limpieza de rodillos", message: "Esta operación mueve el mecanismo y puede consumir material. ¿Deseas continuar?") else { return }
        executeAction(name: "Limpieza Rodillos", command: "clean-rollers", completionDesc: "Limpieza completada")
    }

    func nozzleTest() {
        guard confirmRiskyAction("Patrón de inyectores", message: "Esta operación imprime una página de diagnóstico y consume tinta. ¿Deseas continuar?") else { return }
        executeAction(name: "Patrón Inyectores", command: "nozzle-test", completionDesc: "Página enviada")
    }

    func printDiagPage() {
        guard confirmRiskyAction("Página de diagnóstico", message: "Esta operación imprime una página de diagnóstico. ¿Deseas continuar?") else { return }
        executeAction(name: "Página Diagnóstico", command: "diag-page", completionDesc: "Trabajo enviado")
    }

    func alignHeads() {
        guard confirmRiskyAction("Alineación de cabezales", message: "La impresora puede imprimir un patrón y modificar su calibración. ¿Deseas continuar?") else { return }
        executeAction(name: "Alineación Óptica", command: "align", completionDesc: "Alineación iniciada")
    }

    func openImageCapture() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Image Capture.app"))
    }

    func dumpFirmwareTree() {
        isBusy = true
        busyMessage = "Volcando capacidades de firmware..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["dump-tree"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Diagnóstico Profundo: Árbol XML de Firmware"
                let lines = output.components(separatedBy: "\n").prefix(35).joined(separator: "\n")
                alert.informativeText = lines.isEmpty ? "No se obtuvo respuesta del firmware." : lines
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Entendido")
                alert.runModal()
            }
        }
    }

    func injectRawDemo() {
        guard confirmRiskyAction("Inyección RAW", message: "Esta función envía bytes directamente al puerto USB y no está validada para este firmware. ¿Deseas continuar?") else { return }
        isBusy = true
        busyMessage = "Enviando paquete RAW de prueba..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let testURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("hp-raw-\(UUID().uuidString)", isDirectory: false)
                .appendingPathExtension("pjl")
            let testFile = testURL.path
            var output = ""
            do {
                try "\u{1b}%-12345X@PJL INFO ID\r\n\u{1b}%-12345X\r\n"
                    .write(to: testURL, atomically: true, encoding: .utf8)
                output = self.runToolCommand(["inject-raw", testFile, "--confirm-hardware"])
            } catch {
                output = "No se pudo preparar el archivo temporal RAW: \(error.localizedDescription)"
            }
            try? FileManager.default.removeItem(at: testURL)
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Inyección Raw USB (EP 0x02)"
                alert.informativeText = output.isEmpty ? "Transferencia de prueba completada." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Aceptar")
                alert.runModal()
            }
        }
    }

    func showAccounting() {
        isBusy = true
        busyMessage = "Consultando contabilidad y costes..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["accounting"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Auditoría de Costes y Consumo"
                alert.informativeText = output.isEmpty ? "Sin historial de impresión registrado aún." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Entendido")
                alert.runModal()
            }
        }
    }

    func printTestPattern(type: String) {
        guard confirmRiskyAction("Patrón de prueba", message: "Esta operación imprimirá un patrón y consumirá tinta. ¿Deseas continuar?") else { return }
        isBusy = true
        busyMessage = "Imprimiendo patrón de prueba (\(type))..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["test-pattern", type, "--confirm-hardware"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Patrón Profesional de Calibración"
                alert.informativeText = output.isEmpty ? "Patrón enviado a la impresora." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Aceptar")
                alert.runModal()
            }
        }
    }

    func primeTubes() {
        guard confirmRiskyAction("Cebado CISS", message: "Esta operación puede consumir tinta y no está validada físicamente en este proyecto. ¿Deseas continuar?") else { return }
        isBusy = true
        busyMessage = "Cebando tubos CISS (purgando aire)..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["prime-tubes", "--confirm-hardware"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Cebado y Purga de Tubos CISS"
                alert.informativeText = output.isEmpty ? "Cebado completado." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Aceptar")
                alert.runModal()
            }
        }
    }

    func showWasteInk() {
        isBusy = true
        busyMessage = "Consultando estado de almohadillas..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["waste-ink"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Auditoría de Almohadillas de Desecho"
                alert.informativeText = output.isEmpty ? "Sin datos de almohadillas." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Entendido")
                alert.runModal()
            }
        }
    }

    func showHeadHealth() {
        isBusy = true
        busyMessage = "Consultando salud térmica de cabezales..."
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let output = self.runToolCommand(["head-health"])
            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""
                let alert = NSAlert()
                alert.messageText = "Diagnóstico Térmico y Eléctrico de Cabezales"
                alert.informativeText = output.isEmpty ? "Sin datos de cabezales." : output
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Aceptar")
                alert.runModal()
            }
        }
    }
}

// MARK: - Vista de Tanque de Tinta Individual

struct InkTankView: View {
    let item: SupplyItem

    var body: some View {
        VStack(spacing: 8) {
            // Tanque de visualización cilíndrico
            ZStack(alignment: .bottom) {
                // Fondo del tanque
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1.5)
                    )
                    .frame(width: 65, height: 110)

                // Líquido de nivel
                let fillHeight = CGFloat(max(5, min(100, item.level))) * 1.05
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [item.color.opacity(0.8), item.color]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 59, height: fillHeight)
                    .padding(3)
                    .animation(.spring(), value: item.level)

                // Reflejo de cristal frontal
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.white.opacity(0.25), Color.clear]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 25, height: 100)
                    .offset(x: -12, y: -5)
            }
            .shadow(color: item.color.opacity(0.2), radius: 4, x: 0, y: 2)

            // Porcentaje y Código
            VStack(spacing: 2) {
                Text("\(item.level)%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(item.colorName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Estado del sensor
            Text(item.state == "inSensorRange" ? "Nivel OK" : (item.level > 0 ? "Sensor OK" : "Sin señal"))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(item.level > 0 ? .green : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(item.level > 0 ? Color.green.opacity(0.12) : Color.gray.opacity(0.12))
                .cornerRadius(4)
        }
    }
}

// MARK: - Telemetría de Hardware (Odómetro)

struct OdometerStatItem: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(tint)
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct OdometerBarView: View {
    let odo: OdometerResponse?

    var body: some View {
        HStack(spacing: 0) {
            OdometerStatItem(
                icon: "doc.text.fill",
                value: "\(odo?.total_pages ?? 0)",
                label: "Páginas (\(odo?.mono_pages ?? 0) B/N - \(odo?.color_pages ?? 0) Col)",
                tint: .blue
            )
            Divider().frame(height: 26)
            OdometerStatItem(
                icon: "photo.fill",
                value: "\(odo?.borderless_pages ?? 0)",
                label: "Sin Bordes",
                tint: .purple
            )
            Divider().frame(height: 26)
            OdometerStatItem(
                icon: "scanner.fill",
                value: "\(odo?.scans ?? 0)",
                label: "Escaneos",
                tint: .teal
            )
            Divider().frame(height: 26)
            OdometerStatItem(
                icon: "exclamationmark.triangle.fill",
                value: "\(odo?.jams ?? 0)",
                label: "Atascos",
                tint: (odo?.jams ?? 0) > 0 ? .orange : .gray
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.7))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Botón de Acción de Mantenimiento

struct MaintenanceCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonLabel: String
    let tintColor: Color
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tintColor)
                    .frame(width: 28, height: 28)
                    .background(tintColor.opacity(0.12))
                    .cornerRadius(7)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Button(action: action) {
                HStack {
                    Spacer()
                    Text(buttonLabel)
                        .font(.system(size: 10, weight: .medium))
                    Spacer()
                }
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(tintColor)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Vista Principal

struct ContentView: View {
    @ObservedObject var printer: PrinterManager

    var statusColor: Color {
        switch printer.statusCategory {
        case "ready": return .green
        case "processing": return .blue
        case "mediaEmpty", "closeDoorOrCover": return .orange
        case "mediaJam", "error": return .red
        default: return printer.isConnected ? .green : .gray
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Encabezado Superior
            HStack(spacing: 14) {
                Image(systemName: "printer.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HP Smart Tank 500 series")
                        .font(.system(size: 17, weight: .bold))
                    Text("Controlador Nativo Apple Silicon (ARM64)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Pastilla de Estado USB
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(printer.isConnected ? "USB Activo" : "Desconectado")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(printer.isConnected ? .primary : .secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12))
                .cornerRadius(16)

                // Botón Simulación (Mock Toggle)
                Button(action: {
                    printer.useMock.toggle()
                    printer.refresh()
                }) {
                    Image(systemName: printer.useMock ? "sparkles.rectangle.stack.fill" : "sparkles.rectangle.stack")
                        .font(.system(size: 12))
                        .foregroundColor(printer.useMock ? .purple : .secondary)
                }
                .help(printer.useMock ? "Modo simulador activo (clic para volver a USB en vivo)" : "Activar modo simulador para pruebas")
                .buttonStyle(.plain)

                // Botón Refrescar
                Button(action: { printer.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .semibold))
                }
                .help("Actualizar estado ahora")
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)

            // Banner de Estado del Dispositivo
            HStack(spacing: 10) {
                Image(systemName: printer.statusCategory == "ready" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundColor(statusColor)
                    .font(.system(size: 13))
                Text(printer.statusDescription)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if printer.isBusy {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                    Text(printer.busyMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.08))
            .cornerRadius(8)
            .padding(.horizontal, 20)

            // Sección 1: Tanques de Tinta
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Niveles de Tinta y Suministros")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("Verifique nivel visual en ventanas frontales")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 24) {
                    Spacer()
                    ForEach(printer.supplies) { item in
                        InkTankView(item: item)
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .padding(.horizontal, 20)

            // Sección 2: Telemetría de Hardware (Odómetro)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Telemetría de Hardware")
                        .font(.system(size: 12, weight: .bold))
                    Spacer()
                    if let odo = printer.odometer, odo.connected {
                        Text("Contadores oficiales EWS")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                OdometerBarView(odo: printer.odometer)
            }
            .padding(.horizontal, 20)

            Divider()
                .padding(.horizontal, 20)

            // Sección 3: Centro de Mantenimiento y Calibración (6 Cards)
            VStack(alignment: .leading, spacing: 8) {
                Text("Centro de Mantenimiento y Calibración")
                    .font(.system(size: 12, weight: .bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    MaintenanceCard(
                        icon: "sparkles",
                        title: "Limpieza Básica",
                        description: "Nivel 1: purga de inyectores",
                        buttonLabel: "Limpiar Cabezales",
                        tintColor: .blue,
                        action: { printer.cleanHeads() }
                    )

                    MaintenanceCard(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Purga Profunda",
                        description: "Nivel 2: vacío para inyectores secos",
                        buttonLabel: "Iniciar Purga",
                        tintColor: .red,
                        action: { printer.deepClean() }
                    )

                    MaintenanceCard(
                        icon: "circle.grid.cross.fill",
                        title: "Limpiar Rodillos",
                        description: "Nivel 3: elimina manchas de papel",
                        buttonLabel: "Limpiar Rodillos",
                        tintColor: .orange,
                        action: { printer.cleanRollers() }
                    )

                    MaintenanceCard(
                        icon: "doc.text.viewfinder",
                        title: "Patrón Inyectores",
                        description: "Página de prueba de calidad",
                        buttonLabel: "Imprimir Patrón",
                        tintColor: .indigo,
                        action: { printer.nozzleTest() }
                    )

                    MaintenanceCard(
                        icon: "slider.horizontal.3",
                        title: "Alineación Óptica",
                        description: "Calibra registro y desfase",
                        buttonLabel: "Alinear Cabezales",
                        tintColor: .green,
                        action: { printer.alignHeads() }
                    )

                    MaintenanceCard(
                        icon: "scanner.fill",
                        title: "Escáner Óptico",
                        description: "Captura de Imagen nativo (AirScan)",
                        buttonLabel: "Abrir Escáner",
                        tintColor: .teal,
                        action: { printer.openImageCapture() }
                    )

                    MaintenanceCard(
                        icon: "network",
                        title: "Árbol Firmware",
                        description: "Vuelca capacidades XML ocultas",
                        buttonLabel: "Volcar Firmware",
                        tintColor: .purple,
                        action: { printer.dumpFirmwareTree() }
                    )

                    MaintenanceCard(
                        icon: "terminal.fill",
                        title: "Inyección Raw",
                        description: "Diagnóstico directo Bulk EP 0x02",
                        buttonLabel: "Inyectar Test",
                        tintColor: .secondary,
                        action: { printer.injectRawDemo() }
                    )

                    MaintenanceCard(
                        icon: "dollarsign.circle.fill",
                        title: "Costes & Facturación",
                        description: "Auditoría de ml, gotas y coste/pág",
                        buttonLabel: "Ver Costes",
                        tintColor: .orange,
                        action: { printer.showAccounting() }
                    )

                    MaintenanceCard(
                        icon: "checkerboard.rectangle",
                        title: "Patrón CMYK & Grid",
                        description: "Prueba geométrica y micro-paso",
                        buttonLabel: "Imprimir Test",
                        tintColor: .blue,
                        action: { printer.printTestPattern(type: "cmyk") }
                    )

                    MaintenanceCard(
                        icon: "drop.triangle.fill",
                        title: "Cebado CISS",
                        description: "Purga de burbujas en mangueras",
                        buttonLabel: "Cebar Tubos",
                        tintColor: .pink,
                        action: { printer.primeTubes() }
                    )

                    MaintenanceCard(
                        icon: "archivebox.fill",
                        title: "Almohadillas",
                        description: "Saturación de esponja absorbedora",
                        buttonLabel: "Ver Almohadilla",
                        tintColor: .brown,
                        action: { printer.showWasteInk() }
                    )

                    MaintenanceCard(
                        icon: "waveform.path.ecg",
                        title: "Salud Cabezales",
                        description: "Diagnóstico térmico y contactos flex",
                        buttonLabel: "Ver Salud",
                        tintColor: .green,
                        action: { printer.showHeadHealth() }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 550, height: 780)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Entrada de la Aplicación y Agente Residente en Barra de Menú

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var statusItem: NSStatusItem!
    let printer = PrinterManager()
    private var activeAlertKeys = Set<String>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                NSLog("No se pudo solicitar autorización de notificaciones: %@", error.localizedDescription)
            } else if !granted {
                NSLog("Notificaciones no autorizadas por el usuario")
            }
        }
        // 1. Configurar Ventana Principal
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 780),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "HP Smart Tank Utility"
        window.contentView = NSHostingView(rootView: ContentView(printer: printer))
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // 2. Configurar Menú Residente en Barra de Menú de macOS
        setupStatusItem()
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "printer.fill", accessibilityDescription: "HP Smart Tank")
            button.imagePosition = .imageLeft
            button.title = " Smart Tank"
        }
        updateStatusMenu()

        printer.onUpdate = { [weak self] in
            self?.updateStatusMenu()
        }
    }

    func updateStatusMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "HP Smart Tank 500: \(printer.statusDescription)", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let suppliesStr: String
        if !printer.supplies.isEmpty {
            suppliesStr = printer.supplies.map { "\($0.code): \($0.level)%" }.joined(separator: " | ")
        } else {
            suppliesStr = "No disponible (sin lectura física)"
        }
        let suppliesItem = NSMenuItem(title: "Niveles: \(suppliesStr)", action: nil, keyEquivalent: "")
        suppliesItem.isEnabled = false
        menu.addItem(suppliesItem)

        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Abrir Panel de Control...", action: #selector(showMainWindow), keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let cleanItem = NSMenuItem(title: "Limpieza Básica de Cabezales", action: #selector(menuCleanHeads), keyEquivalent: "")
        cleanItem.target = self
        menu.addItem(cleanItem)

        let primeItem = NSMenuItem(title: "Cebado Forzado de Tubos CISS...", action: #selector(menuPrimeTubes), keyEquivalent: "")
        primeItem.target = self
        menu.addItem(primeItem)

        let wasteItem = NSMenuItem(title: "Auditoría de Almohadillas...", action: #selector(menuWasteInk), keyEquivalent: "")
        wasteItem.target = self
        menu.addItem(wasteItem)

        let healthItem = NSMenuItem(title: "Diagnóstico de Cabezales...", action: #selector(menuHeadHealth), keyEquivalent: "")
        healthItem.target = self
        menu.addItem(healthItem)

        let accItem = NSMenuItem(title: "Auditoría de Costes y Ahorro...", action: #selector(menuAccounting), keyEquivalent: "")
        accItem.target = self
        menu.addItem(accItem)

        let scanItem = NSMenuItem(title: "Escanear Documento (AirScan)...", action: #selector(menuScan), keyEquivalent: "s")
        scanItem.target = self
        menu.addItem(scanItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu

        checkAlerts()
    }

    func checkAlerts() {
        var currentAlertKeys = Set<String>()
        func notifyOnce(key: String, title: String, body: String) {
            currentAlertKeys.insert(key)
            if !activeAlertKeys.contains(key) {
                sendNotification(title: title, body: body)
            }
        }
        if printer.statusCategory == "mediaJam" {
            notifyOnce(key: "status:mediaJam", title: "Atasco de Papel", body: "Se detectó un atasco de papel en la HP Smart Tank 500.")
        } else if printer.statusCategory == "mediaEmpty" {
            notifyOnce(key: "status:mediaEmpty", title: "Sin Papel", body: "La bandeja de la HP Smart Tank 500 está vacía.")
        } else if printer.statusCategory == "closeDoorOrCover" {
            notifyOnce(key: "status:closeDoorOrCover", title: "Cubierta Abierta", body: "La cubierta frontal de la impresora está abierta.")
        }
        for item in printer.supplies {
            if item.level > 0 && item.level <= 12 {
                notifyOnce(key: "supply-low:\(item.code)", title: "Nivel de Tinta Bajo", body: "El tanque \(item.colorName) está al \(item.level)%. Por favor recargue el depósito.")
            }
        }
        activeAlertKeys = currentAlertKeys
    }

    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
            if let error = error {
                NSLog("No se pudo entregar notificación: %@", error.localizedDescription)
            }
        }
    }

    @objc func showMainWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func menuCleanHeads() {
        printer.cleanHeads()
    }

    @objc func menuPrimeTubes() {
        printer.primeTubes()
    }

    @objc func menuWasteInk() {
        printer.showWasteInk()
    }

    @objc func menuHeadHealth() {
        printer.showHeadHealth()
    }

    @objc func menuAccounting() {
        printer.showAccounting()
    }

    @objc func menuScan() {
        printer.openImageCapture()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Mantener la app activa en la barra de menú
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
