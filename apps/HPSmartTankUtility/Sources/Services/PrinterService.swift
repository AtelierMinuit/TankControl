import Foundation
import Cocoa

/// Servicio para interactuar con el sistema de colas de impresión CUPS y presets locales.
public final class PrinterService: ObservableObject {
    @Published public var presets: [PrintPreset] = PrintPreset.builtInPresets
    @Published public var selectedPreset: PrintPreset = PrintPreset.builtInPresets[0]
    @Published public var activeJobs: [PrintJob] = []

    public init() {}

    /// Envía una página de prueba CUPS a la impresora configurada de forma asíncrona
    public func sendTestPageAsync(completion: @escaping (Result<String, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let res = ProcessRunner.shared.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/lp"),
                arguments: ["-d", "HP_Smart_Tank_500", "/usr/share/cups/data/testprint"]
            )
            DispatchQueue.main.async {
                if res.isSuccess {
                    completion(.success("Página de prueba enviada a la cola CUPS (HP_Smart_Tank_500)."))
                } else {
                    let out = res.stderr.isEmpty ? res.stdout : res.stderr
                    completion(.failure(NSError(
                        domain: "PrinterService",
                        code: Int(res.exitCode),
                        userInfo: [NSLocalizedDescriptionKey: out.isEmpty ? "No se pudo enviar trabajo a CUPS" : out]
                    )))
                }
            }
        }
    }

    /// Versión síncrona delegada a ProcessRunner seguro
    public func sendTestPage() -> Result<String, Error> {
        let res = ProcessRunner.shared.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/lp"),
            arguments: ["-d", "HP_Smart_Tank_500", "/usr/share/cups/data/testprint"]
        )
        if res.isSuccess {
            return .success("Página de prueba enviada a la cola CUPS (HP_Smart_Tank_500).")
        } else {
            let out = res.stderr.isEmpty ? res.stdout : res.stderr
            return .failure(NSError(domain: "PrinterService", code: Int(res.exitCode), userInfo: [NSLocalizedDescriptionKey: out.isEmpty ? "No se pudo enviar trabajo a CUPS" : out]))
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
