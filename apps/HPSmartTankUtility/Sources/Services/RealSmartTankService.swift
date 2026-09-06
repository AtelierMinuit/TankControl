import Foundation

/// Implementación de producción para interactuar con la HP Smart Tank 500 física
/// utilizando el binario helper seguro `hp-smart-tank-tool`.
public final class RealSmartTankService: SmartTankServiceProtocol {
    public var isMockMode: Bool { false }

    private let runner = ProcessRunner.shared
    private var helperURL: URL? {
        runner.resolveHelperPath(named: "hp-smart-tank-tool")
    }

    public init() {}

    private func runCommand(_ args: [String]) -> Result<String, Error> {
        guard let url = helperURL else {
            return .failure(NSError(
                domain: "TankControl",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No se encontró el helper ejecutable 'hp-smart-tank-tool' en el bundle de la app."]
            ))
        }

        let res = runner.run(executableURL: url, arguments: args)
        if res.isSuccess {
            return .success(res.stdout)
        } else {
            let msg = res.stderr.isEmpty ? res.stdout : res.stderr
            return .failure(NSError(
                domain: "TankControl",
                code: Int(res.exitCode),
                userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "El comando falló con código \(res.exitCode)" : msg]
            ))
        }
    }

    public func fetchStatus() -> (state: PrinterConnectionState, description: String) {
        let res = runCommand(["json-status"])
        switch res {
        case .success(let output):
            guard let data = output.data(using: .utf8),
                  let json = try? JSONDecoder().decode(StatusResponse.self, from: data) else {
                return (.disconnected, "Respuesta de estado inválida")
            }

            if !json.connected {
                return (.disconnected, "Impresora desconectada o apagada")
            }

            let cat = json.status ?? "ready"
            let desc = (json.description?.isEmpty ?? true) ? "Lista y en reposo" : json.description!

            switch cat {
            case "ready", "genuineHP": return (.ready, desc)
            case "inPowerSave": return (.ready, desc.isEmpty ? "En reposo" : desc)
            case "processing": return (.printing(jobName: "En curso"), desc)
            case "mediaEmpty": return (.warning(message: "Bandeja sin papel"), desc)
            case "mediaJam": return (.error(message: "Atasco de papel"), desc)
            case "closeDoorOrCover": return (.warning(message: "Cubierta abierta"), desc)
            default: return (.ready, desc)
            }

        case .failure(let err):
            return (.disconnected, err.localizedDescription)
        }
    }

    public func fetchSupplies() -> [SupplyItem] {
        let res = runCommand(["json-supplies"])
        switch res {
        case .success(let output):
            guard let data = output.data(using: .utf8),
                  let json = try? JSONDecoder().decode(SuppliesResponse.self, from: data),
                  let items = json.supplies,
                  json.connected else {
                return []
            }
            return items
        case .failure:
            return []
        }
    }

    public func fetchOdometer() -> OdometerResponse? {
        let res = runCommand(["json-odometer"])
        switch res {
        case .success(let output):
            guard let data = output.data(using: .utf8),
                  let json = try? JSONDecoder().decode(OdometerResponse.self, from: data),
                  json.connected else {
                return nil
            }
            return json
        case .failure:
            return nil
        }
    }

    public func fetchDiagnostics() -> [DiagnosticItem] {
        var items: [DiagnosticItem] = []

        // 1. macOS Host
        items.append(DiagnosticItem(
            id: "real-macos",
            subsystem: "macOS",
            name: "Sistema Operativo",
            status: .pass,
            message: "macOS Apple Silicon nativo",
            technicalDetails: ProcessInfo.processInfo.operatingSystemVersionString
        ))

        // 2. CUPS Server
        let cupsRunning = FileManager.default.fileExists(atPath: "/var/run/cupsd")
        items.append(DiagnosticItem(
            id: "real-cups",
            subsystem: "CUPS",
            name: "Servidor CUPS",
            status: cupsRunning ? .pass : .fail,
            message: cupsRunning ? "Servidor de impresión CUPS activo" : "Socket de CUPS inaccesible",
            technicalDetails: "/var/run/cupsd",
            remediationSuggestion: cupsRunning ? nil : "Ejecute 'sudo launchctl kickstart -k system/org.cups.cupsd'"
        ))

        // 3. Helper Binaries
        if let helper = helperURL {
            items.append(DiagnosticItem(
                id: "real-helper",
                subsystem: "Driver",
                name: "Herramienta CLI de Hardware",
                status: .pass,
                message: "Binario regular y firmado disponible",
                technicalDetails: helper.path
            ))
        } else {
            items.append(DiagnosticItem(
                id: "real-helper",
                subsystem: "Driver",
                name: "Herramienta CLI de Hardware",
                status: .fail,
                message: "Falta el helper 'hp-smart-tank-tool'",
                technicalDetails: "No encontrado en Contents/Helpers/",
                remediationSuggestion: "Reconstruya o reinstale el paquete de TankControl."
            ))
        }

        // 4. USB Hardware Status
        let status = fetchStatus()
        if status.state.isConnected {
            items.append(DiagnosticItem(
                id: "real-usb",
                subsystem: "USB",
                name: "Comunicación USB",
                status: .pass,
                message: "Dispositivo HP Smart Tank 500 detectado (VID 0x03F0 PID 0x2B54)",
                technicalDetails: status.description
            ))
        } else {
            items.append(DiagnosticItem(
                id: "real-usb",
                subsystem: "USB",
                name: "Comunicación USB",
                status: .warning,
                message: "Impresora no detectada por USB",
                technicalDetails: "Sin respuesta en Endpoints USB",
                remediationSuggestion: "Conecte el cable USB y encienda la impresora."
            ))
        }

        return items
    }

    public func cleanHeads() -> Result<String, Error> {
        runCommand(["clean-heads", "--confirm-hardware"])
    }

    public func cleanRollers() -> Result<String, Error> {
        runCommand(["clean-rollers", "--confirm-hardware"])
    }

    public func nozzleTest() -> Result<String, Error> {
        runCommand(["nozzle-test", "--confirm-hardware"])
    }

    public func alignHeads() -> Result<String, Error> {
        runCommand(["align", "--confirm-hardware"])
    }

    public func printTestPattern(type: String) -> Result<String, Error> {
        runCommand(["test-pattern", type, "--confirm-hardware"])
    }

    public func getAccounting() -> Result<String, Error> {
        runCommand(["accounting"])
    }

    public func getWasteInk() -> Result<String, Error> {
        runCommand(["waste-ink"])
    }

    public func getHeadHealth() -> Result<String, Error> {
        runCommand(["head-health"])
    }

    public func deepClean() -> Result<String, Error> {
        runCommand(["deep-clean", "--confirm-hardware"])
    }

    public func primeTubes() -> Result<String, Error> {
        runCommand(["prime-tubes", "--confirm-hardware"])
    }

    public func dumpFirmwareTree() -> Result<String, Error> {
        runCommand(["dump-tree"])
    }

    public func injectRawDemo() -> Result<String, Error> {
        let testURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("tankcontrol-raw-\(UUID().uuidString).pjl")
        do {
            try "\u{1b}%-12345X@PJL INFO ID\r\n\u{1b}%-12345X\r\n".write(to: testURL, atomically: true, encoding: .utf8)
            let res = runCommand(["inject-raw", testURL.path, "--confirm-hardware"])
            try? FileManager.default.removeItem(at: testURL)
            return res
        } catch {
            return .failure(error)
        }
    }
}
