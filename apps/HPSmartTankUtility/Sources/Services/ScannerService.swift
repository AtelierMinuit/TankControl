import Foundation
import Cocoa

public enum ScanColorMode: String, CaseIterable, Identifiable {
    case color = "Color (24-bit)"
    case grayscale = "Escala de Grises (8-bit)"
    case monochrome = "Monocromo (1-bit)"

    public var id: String { rawValue }
}

public enum ScanResolution: Int, CaseIterable, Identifiable {
    case dpi75 = 75
    case dpi150 = 150
    case dpi300 = 300
    case dpi600 = 600
    case dpi1200 = 1200

    public var id: Int { rawValue }
    public var label: String { "\(rawValue) DPI" }
}

public enum ScanPaperSize: String, CaseIterable, Identifiable {
    case a4 = "A4 (210 × 297 mm)"
    case letter = "Carta (8.5 × 11 in)"
    case photo = "Foto 10 × 15 cm"

    public var id: String { rawValue }
}

public enum ScanFormat: String, CaseIterable, Identifiable {
    case pdf = "PDF"
    case png = "PNG"
    case jpeg = "JPEG"

    public var id: String { rawValue }
}

/// Servicio para controlar el escáner nativo mediante eSCL o Image Capture.
public final class ScannerService: ObservableObject {
    @Published public var selectedColorMode: ScanColorMode = .color
    @Published public var selectedResolution: ScanResolution = .dpi300
    @Published public var selectedPaperSize: ScanPaperSize = .a4
    @Published public var selectedFormat: ScanFormat = .pdf
    @Published public var destinationFolder: String = "Descargas"
    @Published public var isScanning: Bool = false
    @Published public var scanStatusMessage: String = ""
    @Published public var lastScanResultURL: URL? = nil

    public init() {}

    /// Abre la aplicación nativa Image Capture (AirScan/eSCL) de macOS
    public func openImageCapture() {
        let appURL = URL(fileURLWithPath: "/System/Applications/Image Capture.app")
        NSWorkspace.shared.open(appURL)
    }

    /// Ejecuta una digitalización real en el hardware físico de la HP Smart Tank 500 usando `hp_scan`.
    public func performScan(isMock: Bool = false, isPreview: Bool = false, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let helperURL = ProcessRunner.shared.resolveHelperPath(named: "hp_scan") else {
            completion(.failure(NSError(
                domain: "ScannerService",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "No se encontró el helper 'hp_scan' en el bundle de la aplicación."]
            )))
            return
        }

        isScanning = true
        let dpi = isPreview ? 75 : selectedResolution.rawValue
        scanStatusMessage = isPreview ? "Generando previsualización óptica (\(dpi) DPI)..." : "Digitalizando documento (\(dpi) DPI)..."

        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Downloads")
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let baseFilename = isPreview ? "TankControl_Preview_\(timestamp)" : "HP_Smart_Tank_Scan_\(timestamp)"
        let tempJpgURL = downloadsDir.appendingPathComponent("\(baseFilename).jpg")

        let modeArg = (selectedColorMode == .grayscale) ? "gray" : "color"
        let width = (selectedPaperSize == .photo) ? 1200 : 2480
        let height = (selectedPaperSize == .photo) ? 1800 : 3508

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let res = ProcessRunner.shared.run(
                executableURL: helperURL,
                arguments: [
                    tempJpgURL.path,
                    "\(dpi)",
                    modeArg,
                    "0", "0",
                    "\(width)", "\(height)"
                ]
            )

            DispatchQueue.main.async {
                self.isScanning = false
                if res.isSuccess && FileManager.default.fileExists(atPath: tempJpgURL.path) {
                    if self.selectedFormat == .pdf && !isPreview {
                        // Convertir a PDF mediante sips
                        let pdfURL = downloadsDir.appendingPathComponent("\(baseFilename).pdf")
                        let sipsRes = ProcessRunner.shared.run(
                            executableURL: URL(fileURLWithPath: "/usr/bin/sips"),
                            arguments: ["-s", "format", "pdf", tempJpgURL.path, "--out", pdfURL.path]
                        )
                        if sipsRes.isSuccess && FileManager.default.fileExists(atPath: pdfURL.path) {
                            try? FileManager.default.removeItem(at: tempJpgURL)
                            self.lastScanResultURL = pdfURL
                            completion(.success(pdfURL))
                            return
                        }
                    }

                    self.lastScanResultURL = tempJpgURL
                    completion(.success(tempJpgURL))
                } else {
                    let rawErr = res.stderr.isEmpty ? res.stdout : res.stderr
                    let errMsg = rawErr.isEmpty ? "El escáner no respondió en el bus USB. Comprueba que el equipo esté encendido." : rawErr
                    completion(.failure(NSError(
                        domain: "ScannerService",
                        code: Int(res.exitCode),
                        userInfo: [NSLocalizedDescriptionKey: errMsg]
                    )))
                }
            }
        }
    }
}
