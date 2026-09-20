import Cocoa
import SwiftUI

/// Secciones canónicas de la barra lateral nativa de macOS para TankControl.
public enum SidebarSection: String, CaseIterable, Identifiable {
    case general = "General"
    case printing = "Impresión"
    case scanner = "Escáner"
    case ink = "Tinta"
    case inkSaver = "InkSaver"
    case calibration = "Calibración ICC"
    case maintenance = "Mantenimiento"
    case activity = "Actividad"
    case developer = "Desarrollo"
    case settings = "Configuración"
    case about = "Acerca de"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .general: return "printer"
        case .printing: return "doc.text"
        case .scanner: return "scanner"
        case .ink: return "drop.fill"
        case .inkSaver: return "leaf.fill"
        case .calibration: return "paintpalette.fill"
        case .maintenance: return "wrench.and.screwdriver"
        case .activity: return "chart.bar"
        case .developer: return "hammer.fill"
        case .settings: return "gearshape"
        case .about: return "info.circle"
        }
    }

    public var localizedTitle: String {
        switch self {
        case .general: return LocalizationService.shared.t("section_general")
        case .printing: return LocalizationService.shared.t("section_print")
        case .scanner: return LocalizationService.shared.t("section_scan")
        case .ink: return LocalizationService.shared.t("section_ink")
        case .inkSaver: return LocalizationService.shared.t("section_inksaver")
        case .calibration: return LocalizationService.shared.t("section_calibration")
        case .maintenance: return LocalizationService.shared.t("section_maintenance")
        case .activity: return LocalizationService.shared.t("section_activity")
        case .developer: return LocalizationService.shared.t("section_developer")
        case .settings: return LocalizationService.shared.t("section_settings")
        case .about: return LocalizationService.shared.t("section_about")
        }
    }
}

/// Gestor central observable de la aplicación TankControl / HP Smart Tank Utility.
public final class PrinterManager: ObservableObject {
    @Published public var connectionState: PrinterConnectionState = .connecting
    @Published public var statusDescription: String = "Detectando impresora..."
    @Published public var supplies: [SupplyItem] = []
    @Published public var odometer: OdometerResponse? = nil
    @Published public var diagnostics: [DiagnosticItem] = []
    @Published public var isBusy: Bool = false
    @Published public var busyMessage: String = ""
    public var pauseAutoRefresh: Bool = false
    @Published public var developerMode: Bool = false
    @Published public var selectedSection: SidebarSection? = .general

    public var onUpdate: (() -> Void)?

    private var service: SmartTankServiceProtocol
    private var refreshTimer: Timer?
    private var refreshInFlight: Bool = false

    public init() {
        // La aplicación opera EXCLUSIVAMENTE con hardware real. Jamás en modo demo/mock.
        self.service = RealSmartTankService()
        scheduleRefresh(after: 0.1)
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func updateService() {
        self.service = RealSmartTankService()
    }

    public func scheduleRefresh(after interval: TimeInterval) {
        guard !pauseAutoRefresh else { return }
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
    }

    public func refresh() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.refreshInFlight, !self.pauseAutoRefresh else { return }
            self.refreshInFlight = true
            self.performRefresh()
        }
    }

    private func performRefresh() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let statusResult = self.service.fetchStatus()
            let suppliesResult = self.service.fetchSupplies()
            let odoResult = self.service.fetchOdometer()
            let diagResult = self.service.fetchDiagnostics()

            DispatchQueue.main.async {
                self.refreshInFlight = false
                self.connectionState = statusResult.state
                self.statusDescription = statusResult.description
                self.supplies = suppliesResult
                self.odometer = odoResult
                self.diagnostics = diagResult
                self.onUpdate?()

                // Intervalo de sondeo adaptativo: 4s si está conectado, 15s si está offline
                let interval = self.connectionState.isConnected ? 4.0 : 15.0
                self.scheduleRefresh(after: interval)
            }
        }
    }

    // MARK: - Ejecución de Acciones Asíncronas

    public func runAction(name: String, action: @escaping (SmartTankServiceProtocol) -> Result<String, Error>) {
        isBusy = true
        busyMessage = "\(name) en curso..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let result = action(self.service)

            DispatchQueue.main.async {
                self.isBusy = false
                self.busyMessage = ""

                switch result {
                case .success(let msg):
                    let alert = NSAlert()
                    alert.messageText = "\(name) Completado"
                    alert.informativeText = msg
                    alert.alertStyle = .informational
                    alert.addButton(withTitle: "Aceptar")
                    alert.runModal()
                case .failure(let err):
                    let alert = NSAlert()
                    alert.messageText = "Error en \(name)"
                    alert.informativeText = err.localizedDescription
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "Entendido")
                    alert.runModal()
                }

                self.refresh()
            }
        }
    }

    // Métodos cotidianos de hardware
    public func cleanHeads() {
        runAction(name: "Limpieza Básica de Cabezales") { $0.cleanHeads() }
    }

    public func cleanRollers() {
        runAction(name: "Limpieza de Rodillos") { $0.cleanRollers() }
    }

    public func nozzleTest() {
        runAction(name: "Comprobar Inyectores") { $0.nozzleTest() }
    }

    public func alignHeads() {
        runAction(name: "Alineación de Cabezales") { $0.alignHeads() }
    }

    public func printTestPattern(type: String) {
        runAction(name: "Patrón de Calibración (\(type))") { $0.printTestPattern(type: type) }
    }

    public func showAccounting() {
        runAction(name: "Auditoría de Costes y Consumo") { $0.getAccounting() }
    }

    public func showWasteInk() {
        runAction(name: "Estado de Almohadillas") { $0.getWasteInk() }
    }

    public func showHeadHealth() {
        runAction(name: "Salud de Cabezales") { $0.getHeadHealth() }
    }

    // Operaciones Críticas (Developer Mode)
    public func deepClean() {
        runAction(name: "Limpieza Profunda Nivel 2") { $0.deepClean() }
    }

    public func primeTubes() {
        runAction(name: "Cebado Forzado CISS") { $0.primeTubes() }
    }

    public func dumpFirmwareTree() {
        runAction(name: "Volcado de Firmware XML") { $0.dumpFirmwareTree() }
    }

    public func injectRawDemo() {
        runAction(name: "Inyección Raw USB") { $0.injectRawDemo() }
    }
}
