import Foundation

public enum PrintJobState: String, Codable {
    case pending
    case processing
    case completed
    case cancelled
    case stopped

    public var localizedName: String {
        switch self {
        case .pending: return "En espera"
        case .processing: return "Imprimiendo..."
        case .completed: return "Completado"
        case .cancelled: return "Cancelado"
        case .stopped: return "Detenido"
        }
    }
}

public struct PrintJob: Identifiable, Codable, Equatable {
    public var id: Int
    public var title: String
    public var user: String
    public var pages: Int
    public var sizeBytes: Int
    public var state: PrintJobState
    public var date: Date

    public init(
        id: Int,
        title: String,
        user: String,
        pages: Int,
        sizeBytes: Int,
        state: PrintJobState,
        date: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.user = user
        self.pages = pages
        self.sizeBytes = sizeBytes
        self.state = state
        self.date = date
    }

    public var formattedSize: String {
        let kb = Double(sizeBytes) / 1024.0
        if kb < 1024.0 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.2f MB", kb / 1024.0)
        }
    }
}
