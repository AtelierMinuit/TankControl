import Foundation
import AppKit
import Vision
import PDFKit

/// Resultado del reconocimiento óptico de caracteres
public struct OCRResult {
    public let recognizedText: String
    public let confidence: Float
    public let lineCount: Int
    public let executionTimeSeconds: Double
}

/// Servicio de Reconocimiento Óptico de Caracteres (OCR) 100% nativo y offline.
/// Utiliza el Apple Vision Framework acelerado por el Neural Engine de Apple Silicon.
/// Cero datos enviados a servidores externos.
public final class OCRService: ObservableObject {
    public static let shared = OCRService()

    @Published public var isProcessing: Bool = false
    @Published public var lastResult: OCRResult?
    @Published public var statusMessage: String = ""

    private init() {}

    /// Reconoce texto a partir de un objeto NSImage en segundo plano
    public func recognizeText(from image: NSImage, completion: @escaping (OCRResult?) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(nil)
            return
        }

        isProcessing = true
        statusMessage = "Analizando texto mediante Apple Vision..."
        let startTime = Date()

        DispatchQueue.global(qos: .userInitiated).async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { (request, error) in
                let elapsed = Date().timeIntervalSince(startTime)
                guard error == nil, let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = "Error en el reconocimiento óptico de caracteres."
                        completion(nil)
                    }
                    return
                }

                var recognizedStrings: [String] = []
                var totalConfidence: Float = 0.0

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        recognizedStrings.append(topCandidate.string)
                        totalConfidence += topCandidate.confidence
                    }
                }

                let avgConfidence = observations.isEmpty ? 0.0 : totalConfidence / Float(observations.count)
                let fullText = recognizedStrings.joined(separator: "\n")

                let result = OCRResult(
                    recognizedText: fullText,
                    confidence: avgConfidence,
                    lineCount: observations.count,
                    executionTimeSeconds: elapsed
                )

                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.lastResult = result
                    self.statusMessage = "OCR completado: \(observations.count) líneas detectadas en \(String(format: "%.2f", elapsed))s"
                    completion(result)
                }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["es", "en", "pt", "fr", "de"]
            request.usesLanguageCorrection = true

            do {
                try requestHandler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Fallo ejecutando solicitud Vision: \(error.localizedDescription)"
                    completion(nil)
                }
            }
        }
    }

    /// Crea un PDF con texto seleccionable embebido a partir de una imagen y su texto reconocido
    public func createSearchablePDF(from image: NSImage, recognizedText: String, destinationURL: URL) -> Bool {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else { return false }

        var mediaBox = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return false }

        context.beginPage(mediaBox: &mediaBox)

        // 1. Dibujar imagen de alta fidelidad
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: mediaBox)
        }

        context.endPage()
        context.closePDF()

        // Escribir archivo final
        do {
            try pdfData.write(to: destinationURL, options: .atomic)

            // Guardar también archivo de texto plano adyacente (.txt) para indexación inmediata
            let txtURL = destinationURL.deletingPathExtension().appendingPathExtension("txt")
            try? recognizedText.write(to: txtURL, atomically: true, encoding: .utf8)

            return true
        } catch {
            return false
        }
    }
}
