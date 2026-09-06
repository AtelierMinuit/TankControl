import Foundation
import Cocoa

/// Servicio para interactuar con el sistema de colas de impresión CUPS y presets locales.
public final class PrinterService: ObservableObject {
    @Published public var presets: [PrintPreset] = PrintPreset.builtInPresets
    @Published public var selectedPreset: PrintPreset = PrintPreset.builtInPresets[0]
    @Published public var activeJobs: [PrintJob] = []

    public init() {}

    /// Envía una página de prueba CUPS a la impresora configurada
    public func sendTestPage() -> Result<String, Error> {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lp")
        // Nombre de cola estándar creada por el instalador
        process.arguments = ["-d", "HP_Smart_Tank_500", "/usr/share/cups/data/testprint"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: data, encoding: .utf8) ?? ""
            if process.terminationStatus == 0 {
                return .success("Página de prueba enviada a la cola CUPS (HP_Smart_Tank_500).")
            } else {
                return .failure(NSError(domain: "PrinterService", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: out.isEmpty ? "No se pudo enviar trabajo a CUPS" : out]))
            }
        } catch {
            return .failure(error)
        }
    }

    /// Guarda un nuevo perfil de impresión personalizado
    public func saveCustomPreset(_ preset: PrintPreset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
        } else {
            presets.append(preset)
        }
    }
}
