import Foundation
import AppKit
import PDFKit

/// Estados del flujo de impresión doble cara manual
public enum DuplexStep: Equatable {
    case idle
    case printingOdds(progress: String)
    case waitingForFlip(totalPages: Int, oddCount: Int, evenCount: Int)
    case printingEvens(progress: String)
    case completed(totalPages: Int)
    case error(message: String)
}

/// Servicio que gestiona la impresión a doble cara manual asistida para la HP Smart Tank 500.
/// Soluciona la ausencia de dúplex automático dividiendo los documentos en dos tandas coordinadas.
public final class DuplexPrintService: ObservableObject {
    public static let shared = DuplexPrintService()

    @Published public var currentStep: DuplexStep = .idle
    @Published public var selectedPdfURL: URL?
    @Published public var totalPages: Int = 0
    @Published public var reverseEvenPages: Bool = true
    @Published public var isBusy: Bool = false
    @Published public var statusMessage: String = ""

    private let printerQueue = "HP_Smart_Tank_500"

    private init() {}

    /// Carga y analiza un archivo PDF
    public func loadPDF(url: URL) -> Bool {
        guard let doc = PDFDocument(url: url) else {
            currentStep = .error(message: "No se pudo leer el archivo PDF.")
            return false
        }
        self.selectedPdfURL = url
        self.totalPages = doc.pageCount
        self.currentStep = .idle
        self.statusMessage = "Documento cargado: \(doc.pageCount) páginas."
        return true
    }

    /// Calcula la lista de páginas impares (1-indexed)
    public func oddPageIndices() -> [Int] {
        guard totalPages > 0 else { return [] }
        return stride(from: 1, through: totalPages, by: 2).map { $0 }
    }

    /// Calcula la lista de páginas pares (1-indexed), opcionalmente invertidas
    public func evenPageIndices() -> [Int] {
        guard totalPages > 1 else { return [] }
        let evens = stride(from: 2, through: totalPages, by: 2).map { $0 }
        return reverseEvenPages ? evens.reversed() : evens
    }

    /// Inicia la Fase 1: Envío de páginas impares
    public func startPrintingOdds(completion: @escaping (Bool) -> Void) {
        guard let url = selectedPdfURL, totalPages > 0 else {
            currentStep = .error(message: "No hay ningún documento seleccionado.")
            completion(false)
            return
        }

        let odds = oddPageIndices()
        guard !odds.isEmpty else {
            completion(false)
            return
        }

        isBusy = true
        let oddRanges = formatPageRangeString(odds)
        currentStep = .printingOdds(progress: "Enviando caras impares (\(oddRanges))...")
        statusMessage = "Imprimiendo páginas impares a la HP Smart Tank 500..."

        let args = [
            "-d", printerQueue,
            "-o", "page-ranges=\(oddRanges)",
            url.path
        ]

        ProcessRunner.runAsync("/usr/bin/lp", arguments: args) { [weak self] output, exitCode in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isBusy = false
                if exitCode == 0 {
                    let evens = self.evenPageIndices()
                    self.currentStep = .waitingForFlip(
                        totalPages: self.totalPages,
                        oddCount: odds.count,
                        evenCount: evens.count
                    )
                    self.statusMessage = "Caras impares impresas. Reubica el fajo de hojas en la bandeja."
                    completion(true)
                } else {
                    self.currentStep = .error(message: "Error enviando lote impar a CUPS: \(output)")
                    completion(false)
                }
            }
        }
    }

    /// Inicia la Fase 2: Envío de páginas pares tras confirmación del usuario
    public func startPrintingEvens(completion: @escaping (Bool) -> Void) {
        guard let url = selectedPdfURL, totalPages > 1 else {
            // Si el documento tiene solo 1 página, se completa de inmediato
            currentStep = .completed(totalPages: totalPages)
            completion(true)
            return
        }

        let evens = evenPageIndices()
        guard !evens.isEmpty else {
            currentStep = .completed(totalPages: totalPages)
            completion(true)
            return
        }

        isBusy = true
        let evenRanges = formatPageRangeString(evens)
        currentStep = .printingEvens(progress: "Enviando caras pares (\(evenRanges))...")
        statusMessage = "Imprimiendo páginas pares..."

        let args = [
            "-d", printerQueue,
            "-o", "page-ranges=\(evenRanges)",
            url.path
        ]

        ProcessRunner.runAsync("/usr/bin/lp", arguments: args) { [weak self] output, exitCode in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isBusy = false
                if exitCode == 0 {
                    self.currentStep = .completed(totalPages: self.totalPages)
                    self.statusMessage = "¡Impresión a doble cara completada exitosamente!"
                    completion(true)
                } else {
                    self.currentStep = .error(message: "Error enviando lote par a CUPS: \(output)")
                    completion(false)
                }
            }
        }
    }

    /// Cancela o restablece el asistente
    public func reset() {
        currentStep = .idle
        isBusy = false
        statusMessage = ""
    }

    /// Formatea una lista de enteros en formato de rangos CUPS (ej: "1,3,5" o "6,4,2")
    private func formatPageRangeString(_ pages: [Int]) -> String {
        pages.map { String($0) }.joined(separator: ",")
    }
}
