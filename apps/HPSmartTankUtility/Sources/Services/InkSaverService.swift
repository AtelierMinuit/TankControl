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
    @Published public var activeLevel: InkSaverLevel = .eco50
    @Published public var pureBlackEnabled: Bool = true
    @Published public var tacLimitPercent: Int = 260 // Total Area Coverage (200-300%)

    public init() {}

    public struct SavingsEstimate {
        public let millilitersSaved: Double
        public let dollarsSaved: Double
    }

    public func calculateEstimatedSavings(pageCount: Int) -> SavingsEstimate {
        let percent = Double(activeLevel.estimatedSavingsPercent) / 100.0
        let mlSaved = Double(pageCount) * 0.05 * percent
        let dollars = mlSaved * 0.15
        return SavingsEstimate(millilitersSaved: mlSaved, dollarsSaved: dollars)
    }

    /// Explicación técnica honesta sobre cómo opera el ahorro
    public static let technicalTransparencyNotice = """
    La reducción es una estimación de cobertura de píxeles generada por software en el buffer \
    raster RGB previo a la compresión PCL3GUI Mode 10 del spooler CUPS. No representa una medición \
    de flujo por sensor piezométrico de hardware.
    """
}
