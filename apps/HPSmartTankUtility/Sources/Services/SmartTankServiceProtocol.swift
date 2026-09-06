import Foundation

/// Protocolo que abstrae todas las operaciones sobre la HP Smart Tank 500.
/// Permite intercambiar de forma transparente la implementación real por un mock completo.
public protocol SmartTankServiceProtocol: AnyObject {
    var isMockMode: Bool { get }

    // Consultas de Estado y Telemetría
    func fetchStatus() -> (state: PrinterConnectionState, description: String)
    func fetchSupplies() -> [SupplyItem]
    func fetchOdometer() -> OdometerResponse?
    func fetchDiagnostics() -> [DiagnosticItem]

    // Acciones de Mantenimiento Seguras
    func cleanHeads() -> Result<String, Error>
    func cleanRollers() -> Result<String, Error>
    func nozzleTest() -> Result<String, Error>
    func alignHeads() -> Result<String, Error>
    func printTestPattern(type: String) -> Result<String, Error>

    // Consultas Informativas
    func getAccounting() -> Result<String, Error>
    func getWasteInk() -> Result<String, Error>
    func getHeadHealth() -> Result<String, Error>

    // Operaciones Críticas / Developer Mode
    func deepClean() -> Result<String, Error>
    func primeTubes() -> Result<String, Error>
    func dumpFirmwareTree() -> Result<String, Error>
    func injectRawDemo() -> Result<String, Error>
}
