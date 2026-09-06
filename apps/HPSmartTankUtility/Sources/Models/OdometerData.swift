import Foundation

public struct OdometerDrops: Codable, Equatable {
    public let k: Int?
    public let c: Int?
    public let m: Int?
    public let y: Int?

    public init(k: Int? = 0, c: Int? = 0, m: Int? = 0, y: Int? = 0) {
        self.k = k
        self.c = c
        self.m = m
        self.y = y
    }

    public var totalDrops: Int {
        return (k ?? 0) + (c ?? 0) + (m ?? 0) + (y ?? 0)
    }

    /// Estimación teórica de volumen en mililitros (aprox 12 pl por gota en PCL3GUI)
    public var estimatedVolumeMilliliters: Double {
        let picoliters = Double(totalDrops) * 12.0
        return picoliters / 1_000_000_000.0
    }
}

public struct OdometerResponse: Codable, Equatable {
    public let connected: Bool
    public let mock: Bool?
    public let total_pages: Int?
    public let mono_pages: Int?
    public let color_pages: Int?
    public let borderless_pages: Int?
    public let scans: Int?
    public let jams: Int?
    public let pick_failures: Int?
    public let drops: OdometerDrops?

    public init(
        connected: Bool,
        mock: Bool? = false,
        total_pages: Int? = 0,
        mono_pages: Int? = 0,
        color_pages: Int? = 0,
        borderless_pages: Int? = 0,
        scans: Int? = 0,
        jams: Int? = 0,
        pick_failures: Int? = 0,
        drops: OdometerDrops? = nil
    ) {
        self.connected = connected
        self.mock = mock
        self.total_pages = total_pages
        self.mono_pages = mono_pages
        self.color_pages = color_pages
        self.borderless_pages = borderless_pages
        self.scans = scans
        self.jams = jams
        self.pick_failures = pick_failures
        self.drops = drops
    }

    /// Retorna el total de páginas considerando mono_pages + color_pages si total_pages es 0 en el firmware
    public var calculatedTotalPages: Int {
        if let total = total_pages, total > 0 {
            return total
        }
        let sum = (mono_pages ?? 0) + (color_pages ?? 0)
        return sum > 0 ? sum : (total_pages ?? 0)
    }
}

public struct StatusResponse: Codable {
    public let connected: Bool
    public let status: String?
    public let description: String?

    public init(connected: Bool, status: String?, description: String?) {
        self.connected = connected
        self.status = status
        self.description = description
    }
}
