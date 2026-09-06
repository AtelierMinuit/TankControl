import Foundation

/// Categoría de error estructurado para la aplicación.
public enum SmartTankErrorCategory: String, Codable {
    case connection
    case print
    case scan
    case cups
    case permission
    case hardware
    case unknown
}

/// Error enriquecido con recomendaciones paso a paso para el usuario.
public struct SmartTankError: Identifiable, Equatable {
    public var id = UUID()
    public let category: SmartTankErrorCategory
    public let title: String
    public let userMessage: String
    public let technicalDetails: String?
    public let recoveryAction: String?

    public init(
        category: SmartTankErrorCategory,
        title: String,
        userMessage: String,
        technicalDetails: String? = nil,
        recoveryAction: String? = nil
    ) {
        self.category = category
        self.title = title
        self.userMessage = userMessage
        self.technicalDetails = technicalDetails
        self.recoveryAction = recoveryAction
    }

    public static func usbDisconnected() -> SmartTankError {
        SmartTankError(
            category: .connection,
            title: "Impresora Desconectada",
            userMessage: "No se detecta la HP Smart Tank 500 en los puertos USB de este Mac.",
            technicalDetails: "No matching USB vendor=0x03f0, product=0x2b54 found via IOKit.",
            recoveryAction: "1. Verifique que el cable USB esté firmemente conectado al Mac.\n2. Asegúrese de que la impresora esté encendida con el display iluminado.\n3. Si usa un hub USB-C, conéctelo directamente a un puerto Thunderbolt/USB-C del Mac."
        )
    }

    public static func cupsDaemonUnavailable() -> SmartTankError {
        SmartTankError(
            category: .cups,
            title: "Servidor CUPS Inaccesible",
            userMessage: "No es posible comunicarse con el subsistema de impresión de macOS.",
            technicalDetails: "Socket /var/run/cupsd not responding.",
            recoveryAction: "Reinicie el servicio de impresión ejecutando: sudo launchctl kickstart -k system/org.cups.cupsd"
        )
    }

    public static func helperMissing(path: String) -> SmartTankError {
        SmartTankError(
            category: .permission,
            title: "Componente de Driver Ausente",
            userMessage: "Falta un binario auxiliar requerido para comunicarse con la impresora.",
            technicalDetails: "Helper not executable or missing at: \(path)",
            recoveryAction: "Reinstale la aplicación TankControl o verifique los permisos de /Contents/Helpers/."
        )
    }
}
