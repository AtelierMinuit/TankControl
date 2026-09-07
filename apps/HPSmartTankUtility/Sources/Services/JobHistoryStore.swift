import Foundation

/// Almacén persistente y sincronizador del historial de trabajos de impresión para TankControl.
/// Lee los registros completados del subsistema CUPS de macOS y los persiste en Application Support.
public final class JobHistoryStore: ObservableObject {
    public static let shared = JobHistoryStore()

    @Published public var jobs: [PrintJob] = []

    private let storageURL: URL

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let tankDir = appSupport.appendingPathComponent("TankControl", isDirectory: true)
        try? FileManager.default.createDirectory(at: tankDir, withIntermediateDirectories: true)
        self.storageURL = tankDir.appendingPathComponent("jobs_history.json")

        loadJobs()
        syncWithCups()
    }

    public func loadJobs() {
        guard let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode([PrintJob].self, from: data) else {
            return
        }
        self.jobs = loaded
    }

    public func saveJobs() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    public func clearJobs() {
        jobs.removeAll()
        try? FileManager.default.removeItem(at: storageURL)
    }

    public func addJob(_ job: PrintJob) {
        if !jobs.contains(where: { $0.id == job.id && $0.title == job.title }) {
            jobs.insert(job, at: 0)
            saveJobs()
        }
    }

    public func syncWithCups() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let parsed = self.fetchCupsCompletedJobs()
            DispatchQueue.main.async {
                for job in parsed {
                    if !self.jobs.contains(where: { $0.id == job.id }) {
                        self.jobs.append(job)
                    }
                }
                self.jobs.sort { $0.date > $1.date }
                self.saveJobs()
            }
        }
    }

    private func fetchCupsCompletedJobs() -> [PrintJob] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-W", "completed"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        var results: [PrintJob] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "EEE MMM d HH:mm:ss yyyy"

        for line in output.split(separator: "\n") {
            let parts = line.split(whereSeparator: { $0.isWhitespace })
            guard parts.count >= 8 else { continue }

            let fullJobId = String(parts[0])
            guard fullJobId.contains("Smart_Tank") || fullJobId.contains("HP") else { continue }

            let jobIdNum: Int
            if let dashIdx = fullJobId.lastIndex(of: "-"),
               let num = Int(fullJobId[fullJobId.index(after: dashIdx)...]) {
                jobIdNum = num
            } else {
                continue
            }

            let user = String(parts[1])
            let sizeBytes = Int(parts[2]) ?? 0

            let dateStr = "\(parts[3]) \(parts[4]) \(parts[5]) \(parts[6]) \(parts[7])"
            let date = dateFormatter.date(from: dateStr) ?? Date()

            let job = PrintJob(
                id: jobIdNum,
                title: "Trabajo #\(jobIdNum) (PCL3GUI)",
                user: user,
                pages: 1,
                sizeBytes: sizeBytes,
                state: .completed,
                date: date
            )
            results.append(job)
        }

        return results
    }
}
