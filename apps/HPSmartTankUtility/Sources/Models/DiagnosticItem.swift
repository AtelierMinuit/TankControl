import SwiftUI

public enum DiagnosticStatus: String, Codable {
    case pass
    case warning
    case fail
    case skipped
    case running

    public var color: Color {
        switch self {
        case .pass: return DesignTokens.Colors.statusReady
        case .warning: return DesignTokens.Colors.statusWarning
        case .fail: return DesignTokens.Colors.statusError
        case .skipped: return Color.secondary
        case .running: return DesignTokens.Colors.statusProcessing
        }
    }

    public var iconName: String {
        switch self {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .fail: return "xmark.octagon.fill"
        case .skipped: return "minus.circle"
        case .running: return "arrow.triangle.2.circlepath"
        }
    }

    public var localizedLabel: String {
        switch self {
        case .pass: return "Correcto"
        case .warning: return "Advertencia"
        case .fail: return "Fallo"
        case .skipped: return "Omitido"
        case .running: return "Verificando..."
        }
    }
}

public struct DiagnosticItem: Identifiable, Equatable {
    public var id: String
    public var subsystem: String        // "macOS", "CUPS", "Driver", "PPD", "USB", "Escáner", "eSCL", "ColorSync"
    public var name: String
    public var status: DiagnosticStatus
    public var message: String
    public var technicalDetails: String?
    public var remediationSuggestion: String?

    public init(
        id: String,
        subsystem: String,
        name: String,
        status: DiagnosticStatus,
        message: String,
        technicalDetails: String? = nil,
        remediationSuggestion: String? = nil
    ) {
        self.id = id
        self.subsystem = subsystem
        self.name = name
        self.status = status
        self.message = message
        self.technicalDetails = technicalDetails
        self.remediationSuggestion = remediationSuggestion
    }
}
