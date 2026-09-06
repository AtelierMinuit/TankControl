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

    /// Simula o inicia un escaneo o previsualización directa guardando un documento de muestra
    public func performScan(isMock: Bool, isPreview: Bool = false, completion: @escaping (Result<URL, Error>) -> Void) {
        guard isMock else {
            completion(.failure(NSError(domain: "ScannerService", code: 501,
                userInfo: [NSLocalizedDescriptionKey: "El escáner físico requiere Captura de Imagen de macOS o conexión USB activa."])))
            return
        }
        isScanning = true
        scanStatusMessage = isPreview ? "Generando vista previa..." : "Digitalizando a \(selectedResolution.label)..."

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + (isMock ? 1.5 : 4.0)) { [weak self] in
            DispatchQueue.main.async {
                self?.isScanning = false
                // En modo offline/mock, creamos una previsualización de documento de prueba
                let tempDir = FileManager.default.temporaryDirectory
                let outputURL = tempDir.appendingPathComponent("TankControl-Scan-\(UUID().uuidString.prefix(8)).png")

                // Crear imagen bitmap de prueba (A4 en ratio)
                let rep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: 600,
                    pixelsHigh: 850,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .calibratedRGB,
                    bytesPerRow: 600 * 4,
                    bitsPerPixel: 32
                )
                if let rep = rep {
                    NSGraphicsContext.saveGraphicsState()
                    let ctx = NSGraphicsContext(bitmapImageRep: rep)
                    NSGraphicsContext.current = ctx

                    // Fondo de hoja
                    NSColor.white.setFill()
                    NSRect(x: 0, y: 0, width: 600, height: 850).fill()

                    // Contenido de muestra escaneado
                    let title = "MOCK STATE — Documento de demostración" as NSString
                    title.draw(at: NSPoint(x: 50, y: 760), withAttributes: [
                        .font: NSFont.boldSystemFont(ofSize: 22),
                        .foregroundColor: NSColor.black
                    ])

                    let meta = "HP Smart Tank 500 — Resolución: \(self?.selectedResolution.label ?? "300 DPI") — \(self?.selectedColorMode.rawValue ?? "Color")" as NSString
                    meta.draw(at: NSPoint(x: 50, y: 730), withAttributes: [
                        .font: NSFont.systemFont(ofSize: 13),
                        .foregroundColor: NSColor.darkGray
                    ])

                    // Dibujar marcas de calibración
                    NSColor.systemBlue.setStroke()
                    let path = NSBezierPath()
                    path.move(to: NSPoint(x: 50, y: 700))
                    path.line(to: NSPoint(x: 550, y: 700))
                    path.lineWidth = 2
                    path.stroke()

                    NSGraphicsContext.restoreGraphicsState()

                    if let pngData = rep.representation(using: .png, properties: [:]) {
                        try? pngData.write(to: outputURL)
                        self?.lastScanResultURL = outputURL
                        completion(.success(outputURL))
                        return
                    }
                }

                completion(.failure(NSError(domain: "ScannerService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Error al generar imagen de escaneo"])))
            }
        }
    }
}
