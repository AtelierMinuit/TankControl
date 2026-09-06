import SwiftUI

/// Máquina de estados de conexión y ciclo de vida de la impresora.
public enum PrinterConnectionState: Equatable {
    case disconnected
    case connecting
    case ready
    case printing(jobName: String)
    case scanning
    case busy(reason: String)
    case warning(message: String)
    case error(message: String)

    public var label: String {
        switch self {
        case .disconnected:
            return "Desconectada o en espera"
        case .connecting:
            return "Detectando dispositivo..."
        case .ready:
            return "Impresora disponible"
        case .printing(let job):
            return "Imprimiendo: \(job)"
        case .scanning:
            return "Escaneo en progreso..."
        case .busy(let reason):
            return reason
        case .warning(let msg):
            return msg
        case .error(let msg):
            return msg
        }
    }

    public var shortBadge: String {
        switch self {
        case .disconnected: return "Desconectado"
        case .connecting: return "Conectando"
        case .ready: return "USB Activo"
        case .printing: return "Imprimiendo"
        case .scanning: return "Escaneando"
        case .busy: return "Ocupado"
        case .warning: return "Atención"
        case .error: return "Error"
        }
    }

    public var statusColor: Color {
        switch self {
        case .disconnected: return DesignTokens.Colors.statusOffline
        case .connecting: return DesignTokens.Colors.statusProcessing
        case .ready: return DesignTokens.Colors.statusReady
        case .printing, .scanning: return DesignTokens.Colors.brandTeal
        case .busy: return DesignTokens.Colors.statusProcessing
        case .warning: return DesignTokens.Colors.statusWarning
        case .error: return DesignTokens.Colors.statusError
        }
    }

    public var iconName: String {
        switch self {
        case .disconnected: return "printer.slash"
        case .connecting: return "arrow.triangle.2.circlepath"
        case .ready: return "checkmark.circle.fill"
        case .printing: return "printer.fill"
        case .scanning: return "scanner.fill"
        case .busy: return "hourglass"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    public var isConnected: Bool {
        switch self {
        case .disconnected, .connecting:
            return false
        default:
            return true
        }
    }
}
