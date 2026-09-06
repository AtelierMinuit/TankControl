import SwiftUI

/// Representación de un tanque de tinta CISS (K, C, M, Y).
public struct SupplyItem: Codable, Identifiable, Equatable {
    public var id: String { code }
    public let code: String          // "K", "C", "M", "Y"
    public let name: String          // Nombre localizado
    public var level: Int            // 0 - 100
    public let state: String         // "inSensorRange", "ok", "low", etc.
    public var isDemo: Bool = false  // Indica si es dato de simulación

    public enum CodingKeys: String, CodingKey {
        case code, name, level, state
    }

    public init(code: String, name: String, level: Int, state: String, isDemo: Bool = false) {
        self.code = code
        self.name = name
        self.level = max(0, min(100, level))
        self.state = state
        self.isDemo = isDemo
    }

    public var color: Color {
        switch code.uppercased() {
        case "K": return DesignTokens.Colors.inkBlack
        case "C": return DesignTokens.Colors.inkCyan
        case "M": return DesignTokens.Colors.inkMagenta
        case "Y": return DesignTokens.Colors.inkYellow
        default: return Color.gray
        }
    }

    public var colorName: String {
        switch code.uppercased() {
        case "K": return "Negro (K)"
        case "C": return "Cian (C)"
        case "M": return "Magenta (M)"
        case "Y": return "Amarillo (Y)"
        default: return name
        }
    }

    /// Símbolo geométrico para accesibilidad (diferenciación sin depender solo de color).
    public var shapeSymbol: String {
        switch code.uppercased() {
        case "K": return "square.fill"
        case "C": return "triangle.fill"
        case "M": return "diamond.fill"
        case "Y": return "circle.fill"
        default: return "circle"
        }
    }

    /// Etiqueta completa para VoiceOver / Accesibilidad.
    public var accessibilityLabel: String {
        let demoNotice = isDemo ? ", modo demostración" : ""
        return "Tanque de tinta \(colorName): \(level) por ciento restante. Estado: \(sensorDescription)\(demoNotice)."
    }

    public var sensorDescription: String {
        if level <= 0 { return "Sin lectura o agotado" }
        if state == "inSensorRange" { return "En rango de sensor" }
        if level <= 15 { return "Nivel bajo" }
        return "Nivel óptimo"
    }
}

public struct SuppliesResponse: Codable {
    public let connected: Bool
    public let supplies: [SupplyItem]?
    public let error: String?
}
