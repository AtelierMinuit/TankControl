import Foundation
import SwiftUI

/// Niveles de InkSaver alineados con los comandos PPD internos de CUPS
/// y con etiquetas amigables para el usuario.
public enum InkSaverLevel: String, CaseIterable, Identifiable {
    case off = "Off"
    case eco25 = "Eco25"
    case eco50 = "Eco50"
    case eco75 = "Eco75"
    case edgePreserve = "EdgePreserve"

    public var id: String { rawValue }

    public var friendlyLabel: String {
        switch self {
        case .off: return "Desactivado"
        case .eco25: return "Ahorro ligero"
        case .eco50: return "Equilibrado"
        case .eco75: return "Máximo"
        case .edgePreserve: return "Preservar texto"
        }
    }

    public var description: String {
        switch self {
        case .off:
            return "Renderizado estándar sin modificación de cobertura raster."
        case .eco25:
            return "Reduce moderadamente la cobertura raster."
        case .eco50:
            return "Mayor reducción manteniendo legibilidad."
        case .eco75:
            return "Para borradores internos."
        case .edgePreserve:
            return "Reduce fondos conservando bordes y tipografía."
        }
    }

    public var estimatedCoverageReduction: String {
        switch self {
        case .off: return "0%"
        case .eco25: return "~15-25% raster"
        case .eco50: return "~25-40% raster"
        case .eco75: return "~40-60% raster"
        case .edgePreserve: return "~20-30% raster"
        }
    }

    public var estimatedSavingsPercent: Int {
        switch self {
        case .off: return 0
        case .eco25: return 25
        case .eco50: return 50
        case .eco75: return 75
        case .edgePreserve: return 30
        }
    }
}

/// Servicio que gestiona la configuración de InkSaver y calcula la estimación de ahorro raster.
public final class InkSaverService: ObservableObject {
    /// Porcentaje continuo de ahorro raster (de 0 a 75, por defecto 35%).
    @Published public var savingsPercent: Int = 35 {
        didSet {
            let clamped = min(75, max(0, savingsPercent))
            if savingsPercent != clamped {
                savingsPercent = clamped
                return
            }
            updateActiveLevelFromPercent()
        }
    }

    @Published public var activeLevel: InkSaverLevel = .eco50
    @Published public var pureBlackEnabled: Bool = true
    @Published public var tacLimitPercent: Int = 260 // Total Area Coverage (200-300%)

    // Telemetría y estado de sincronización CUPS
    @Published public var isApplying: Bool = false
    @Published public var isQuerying: Bool = false
    @Published public var isCupsSynced: Bool = false
    @Published public var cupsStatusMessage: String = ""
    @Published public var lastAppliedOption: String? = nil

    public init() {
        updateActiveLevelFromPercent()
    }

    private func updateActiveLevelFromPercent() {
        switch savingsPercent {
        case 0:
            if activeLevel != .off { activeLevel = .off }
        case 1...25:
            if activeLevel != .eco25 { activeLevel = .eco25 }
        case 26...55:
            if activeLevel != .eco50 { activeLevel = .eco50 }
        case 56...75:
            if activeLevel != .eco75 { activeLevel = .eco75 }
        default:
            break
        }
    }

    /// Asigna un nivel predeterminado y actualiza el porcentaje continuo.
    public func setLevel(_ level: InkSaverLevel) {
        self.activeLevel = level
        switch level {
        case .off:
            self.savingsPercent = 0
        case .eco25:
            self.savingsPercent = 20
        case .eco50:
            self.savingsPercent = 35
        case .eco75:
            self.savingsPercent = 70
        case .edgePreserve:
            self.savingsPercent = 35
        }
    }

    /// Mapea el porcentaje al identificador de opción CUPS / PPD
    public func cupsOptionValue(for percent: Int) -> String {
        if percent <= 0 {
            return "Off"
        }
        return "Eco\(percent)"
    }

    /// Convierte cadenas de opción CUPS (ej. "Off", "Eco20", "Eco25", "Eco35", "Eco50", "Eco70", "Eco75", "EdgePreserve") a porcentaje
    public func parseOptionValue(_ raw: String) -> Int {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.caseInsensitiveCompare("Off") == .orderedSame || cleaned == "0" {
            return 0
        }
        if cleaned.caseInsensitiveCompare("EdgePreserve") == .orderedSame {
            return 35
        }
        if cleaned.lowercased().hasPrefix("eco") {
            let numStr = String(cleaned.dropFirst(3))
            if let num = Int(numStr) {
                return min(75, max(0, num))
            }
        }
        if let directNum = Int(cleaned) {
            return min(75, max(0, directNum))
        }
        return 35
    }

    // MARK: - Consulta de Ajuste Actual en CUPS

    /// Consulta el ajuste actual de CUPS de forma asíncrona usando `ProcessRunner`
    /// ejecutando `lpoptions -p HP_Smart_Tank_500 -l` (buscando `*HPInkSaver/` o la opción marcada con `*`).
    public func queryCupsSetting(
        queueName: String = "HP_Smart_Tank_500",
        completion: ((Int?) -> Void)? = nil
    ) {
        isQuerying = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let lpoptionsURL = URL(fileURLWithPath: "/usr/bin/lpoptions")

            // 1. Ejecutar lpoptions -p <queueName> -l (opciones PPD)
            let result = ProcessRunner.shared.run(
                executableURL: lpoptionsURL,
                arguments: ["-p", queueName, "-l"],
                timeoutSeconds: 6.0
            )

            var parsedPercent: Int? = nil

            if result.isSuccess {
                let lines = result.stdout.components(separatedBy: .newlines)
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("HPInkSaver/") || trimmed.hasPrefix("*HPInkSaver/") || trimmed.contains("HPInkSaver") {
                        if let colonIndex = trimmed.firstIndex(of: ":") {
                            let optionsPart = trimmed[trimmed.index(after: colonIndex)...]
                            let tokens = optionsPart.split(separator: " ")
                            for token in tokens {
                                if token.hasPrefix("*") {
                                    let optionValue = String(token.dropFirst())
                                    parsedPercent = self.parseOptionValue(optionValue)
                                    break
                                }
                            }
                        }
                        if parsedPercent != nil { break }
                    }
                }
            }

            // 2. Si no se halló en -l, consultar opciones persistentes del usuario (lpoptions -p queueName)
            if parsedPercent == nil {
                let userResult = ProcessRunner.shared.run(
                    executableURL: lpoptionsURL,
                    arguments: ["-p", queueName],
                    timeoutSeconds: 6.0
                )
                if userResult.isSuccess {
                    let tokens = userResult.stdout.components(separatedBy: .whitespacesAndNewlines)
                    for token in tokens {
                        if token.hasPrefix("HPInkSaver=") {
                            let value = String(token.dropFirst("HPInkSaver=".count))
                            parsedPercent = self.parseOptionValue(value)
                            break
                        }
                    }
                }
            }

            DispatchQueue.main.async {
                self.isQuerying = false
                if let percent = parsedPercent {
                    self.savingsPercent = percent
                    self.isCupsSynced = true
                    let opt = self.cupsOptionValue(for: percent)
                    self.lastAppliedOption = opt
                    self.cupsStatusMessage = "Ajuste actual de CUPS: HPInkSaver=\(opt) (\(percent)%)"
                }
                completion?(parsedPercent)
            }
        }
    }

    /// Variante async/await de consulta de CUPS
    @discardableResult
    public func queryCupsSettingAsync(queueName: String = "HP_Smart_Tank_500") async -> Int? {
        await withCheckedContinuation { continuation in
            queryCupsSetting(queueName: queueName) { percent in
                continuation.resume(returning: percent)
            }
        }
    }

    // MARK: - Aplicación Persistente en CUPS

    /// Aplica persistentemente el ajuste a CUPS ejecutando `lpoptions -p HP_Smart_Tank_500 -o HPInkSaver=EcoXX`
    /// de forma asíncrona sin bloquear el hilo principal de la UI.
    public func applyCupsSetting(
        queueName: String = "HP_Smart_Tank_500",
        completion: ((Result<String, Error>) -> Void)? = nil
    ) {
        let percent = self.savingsPercent
        let optionValue = cupsOptionValue(for: percent)
        self.isApplying = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let lpoptionsURL = URL(fileURLWithPath: "/usr/bin/lpoptions")
            let result = ProcessRunner.shared.run(
                executableURL: lpoptionsURL,
                arguments: ["-p", queueName, "-o", "HPInkSaver=\(optionValue)"],
                timeoutSeconds: 8.0
            )

            DispatchQueue.main.async {
                self.isApplying = false
                if result.isSuccess {
                    self.isCupsSynced = true
                    self.lastAppliedOption = optionValue
                    let msg = "Ajuste aplicado a la cola \(queueName)"
                    self.cupsStatusMessage = msg
                    completion?(.success(msg))
                } else {
                    let errDesc = result.stderr.isEmpty ? "Error ejecutando lpoptions (código \(result.exitCode))" : result.stderr
                    let error = NSError(
                        domain: "InkSaverService",
                        code: Int(result.exitCode),
                        userInfo: [NSLocalizedDescriptionKey: errDesc]
                    )
                    self.cupsStatusMessage = "Error al aplicar ajuste: \(errDesc)"
                    completion?(.failure(error))
                }
            }
        }
    }

    /// Variante async/await de aplicación en CUPS
    @discardableResult
    public func applyCupsSettingAsync(queueName: String = "HP_Smart_Tank_500") async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            applyCupsSetting(queueName: queueName) { result in
                switch result {
                case .success(let msg):
                    continuation.resume(returning: msg)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
        }
    }

    // MARK: - Estimación de Ahorro GT51 / GT52 / GT53

    /// Estructura detallada del ahorro proyectado
    public struct SavingsEstimate {
        public let millilitersSaved: Double      // Total de mililitros ahorrados
        public let blackMlSaved: Double          // Tinta negra GT51 / GT53 (pigmentada)
        public let colorMlSaved: Double          // Tintas color GT52 (cian, magenta, amarillo)
        public let dollarsSaved: Double          // Dinero proyectado ahorrado en USD
        public let blackBottleFraction: Double   // Fracción de botella GT53XL (135 ml) preservada
        public let colorBottleFraction: Double   // Fracción de botella GT52 (70 ml) preservada

        public init(
            millilitersSaved: Double,
            blackMlSaved: Double,
            colorMlSaved: Double,
            dollarsSaved: Double,
            blackBottleFraction: Double,
            colorBottleFraction: Double
        ) {
            self.millilitersSaved = millilitersSaved
            self.blackMlSaved = blackMlSaved
            self.colorMlSaved = colorMlSaved
            self.dollarsSaved = dollarsSaved
            self.blackBottleFraction = blackBottleFraction
            self.colorBottleFraction = colorBottleFraction
        }
    }

    /// Calcula con precisión el ahorro en ml de tinta GT51/GT52/GT53 y dinero proyectado según el volumen de páginas.
    public func calculateEstimatedSavings(pageCount: Int) -> SavingsEstimate {
        let percentRatio = Double(savingsPercent) / 100.0
        let pages = Double(max(0, pageCount))

        // Consumo nominal calibrado para documentos estándar (5% cobertura ISO):
        // - Negro pigmentado GT51/GT53: ~0.028 ml por página.
        // - Tintas colorante dye GT52 (C, M, Y compuesto): ~0.022 ml por página.
        // Total nominal sin ahorro = ~0.050 ml por página.
        let blackSaved = pages * 0.028 * percentRatio
        let colorSaved = pages * 0.022 * percentRatio
        let totalMl = blackSaved + colorSaved

        // Costo por ml según precios oficiales de referencia de botellas CISS:
        // - Botella GT53XL Negro (135 ml a ~$13.99 USD) -> ~$0.1037 / ml
        // - Botellas GT52 Color (70 ml a ~$10.99 USD) -> ~$0.1571 / ml
        let dollars = (blackSaved * 0.1037) + (colorSaved * 0.1571)

        let blackFraction = blackSaved / 135.0
        let colorFraction = (colorSaved / 3.0) / 70.0

        return SavingsEstimate(
            millilitersSaved: totalMl,
            blackMlSaved: blackSaved,
            colorMlSaved: colorSaved,
            dollarsSaved: dollars,
            blackBottleFraction: blackFraction,
            colorBottleFraction: colorFraction
        )
    }

    /// Explicación técnica honesta sobre cómo opera el ahorro
    public static let technicalTransparencyNotice = """
    La reducción es una estimación de cobertura de píxeles generada por software en el buffer \
    raster RGB previo a la compresión PCL3GUI Mode 10 del spooler CUPS. No representa una medición \
    de flujo por sensor piezométrico de hardware.
    """
}
