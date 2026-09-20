import Foundation
import AppKit
import PDFKit
import CoreGraphics

/// Configuración de geometría y despiece para afiches y mosaicos
public struct PosterTileInfo {
    public let columns: Int
    public let rows: Int
    public let totalPages: Int
    public let paperName: String
    public let pageWidthPt: CGFloat
    public let pageHeightPt: CGFloat
    public let posterWidthCm: Double
    public let posterHeightCm: Double
    public let overlapMm: Double
}

/// Servicio de generación geométrica de afiches multipágina (Tiled Poster Studio) para TankControl
public final class PosterTileService: ObservableObject {
    public static let shared = PosterTileService()

    @Published public var selectedImage: NSImage?
    @Published public var imageFileName: String?
    @Published public var gridColumns: Int = 2
    @Published public var gridRows: Int = 2
    @Published public var paperFormatId: String = "carta" // "carta", "a4", "oficio", "legal"
    @Published public var overlapMm: Double = 10.0 // Margen de pegado (5 a 25 mm)
    @Published public var includeCutGuides: Bool = true
    @Published public var includeGlueTabs: Bool = true
    @Published public var isGenerating: Bool = false
    @Published public var lastGeneratedPDFURL: URL?
    @Published public var statusMessage: String = ""

    private init() {
        createSampleImageIfNeeded()
    }

    /// Carga una imagen de prueba de alta resolución si no hay ninguna cargada
    public func createSampleImageIfNeeded() {
        if selectedImage != nil { return }
        // Generar un afiche de muestra vectorial con degradado y tipografía
        let size = NSSize(width: 1200, height: 1600)
        let image = NSImage(size: size)
        image.lockFocus()

        let context = NSGraphicsContext.current?.cgContext
        let colors = [
            NSColor(red: 0.05, green: 0.15, blue: 0.35, alpha: 1.0).cgColor,
            NSColor(red: 0.0, green: 0.64, blue: 0.88, alpha: 1.0).cgColor,
            NSColor(red: 0.92, green: 0.0, blue: 0.55, alpha: 1.0).cgColor
        ] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.5, 1.0]) {
            context?.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1200, y: 1600), options: [])
        }

        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 72, weight: .black),
            .foregroundColor: NSColor.white
        ]
        let subAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ]

        "ATELIER MINUIT".draw(at: NSPoint(x: 100, y: 1400), withAttributes: titleAttrs)
        "TankControl Poster & Tiling Studio".draw(at: NSPoint(x: 100, y: 1320), withAttributes: subAttrs)
        "HP Smart Tank 500 · Impresión Gran Formato Mosaico".draw(at: NSPoint(x: 100, y: 1260), withAttributes: subAttrs)

        // Cuadrícula decorativa
        if let ctx = context {
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.2).cgColor)
            ctx.setLineWidth(2.0)
            for i in stride(from: 100, to: 1500, by: 100) {
                ctx.move(to: CGPoint(x: 50, y: i))
                ctx.addLine(to: CGPoint(x: 1150, y: i))
            }
            ctx.strokePath()
        }

        image.unlockFocus()
        self.selectedImage = image
        self.imageFileName = "Muestra_Afiche_AtelierMinuit.png"
    }

    /// Información geométrica calculada del afiche
    public var currentInfo: PosterTileInfo {
        let (pw, ph, name) = paperDimensions(for: paperFormatId)
        let marginMm = 6.0 // Margen mecánico no imprimible aproximado
        let marginPt = marginMm * 2.83465
        let overlapPt = overlapMm * 2.83465

        let tilePrintableW = (pw - 2 * marginPt)
        let tilePrintableH = (ph - 2 * marginPt)

        let netTileW = max(50.0, tilePrintableW - overlapPt)
        let netTileH = max(50.0, tilePrintableH - overlapPt)

        let totalWidthPt = (netTileW * CGFloat(gridColumns)) + overlapPt
        let totalHeightPt = (netTileH * CGFloat(gridRows)) + overlapPt

        let totalWidthCm = Double(totalWidthPt / 2.83465) / 10.0
        let totalHeightCm = Double(totalHeightPt / 2.83465) / 10.0

        return PosterTileInfo(
            columns: gridColumns,
            rows: gridRows,
            totalPages: gridColumns * gridRows,
            paperName: name,
            pageWidthPt: pw,
            pageHeightPt: ph,
            posterWidthCm: totalWidthCm,
            posterHeightCm: totalHeightCm,
            overlapMm: overlapMm
        )
    }

    private func paperDimensions(for id: String) -> (CGFloat, CGFloat, String) {
        switch id {
        case "carta": return (612, 792, "Carta (8.5x11'')")
        case "a4": return (595.44, 841.68, "A4 (210x297 mm)")
        case "oficio": return (612, 936, "Oficio Chile (8.5x13'')")
        case "legal": return (612, 1008, "Legal (8.5x14'')")
        default: return (612, 792, "Carta")
        }
    }

    /// Carga una imagen o página PDF desde una URL seleccionada por el usuario
    public func loadFile(url: URL) {
        if url.pathExtension.lowercased() == "pdf" {
            if let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) {
                let pageRect = page.bounds(for: .mediaBox)
                let image = NSImage(size: pageRect.size)
                image.lockFocus()
                if let ctx = NSGraphicsContext.current?.cgContext {
                    ctx.setFillColor(NSColor.white.cgColor)
                    ctx.fill(pageRect)
                    page.draw(with: .mediaBox, to: ctx)
                }
                image.unlockFocus()
                self.selectedImage = image
                self.imageFileName = url.lastPathComponent
            }
        } else if let img = NSImage(contentsOf: url) {
            self.selectedImage = img
            self.imageFileName = url.lastPathComponent
        }
    }

    /// Genera el documento PDF con el afiche dividido en mosaico
    public func generatePosterPDF(completion: @escaping (Result<URL, Error>) -> Void) {
        guard let image = selectedImage else {
            completion(.failure(NSError(domain: "TankControl", code: 1, userInfo: [NSLocalizedDescriptionKey: "No hay imagen seleccionada"])))
            return
        }

        isGenerating = true
        statusMessage = "Generando despiece en mosaico (\(gridColumns)×\(gridRows))..."

        DispatchQueue.global(qos: .userInitiated).async {
            let info = self.currentInfo
            let tempDir = FileManager.default.temporaryDirectory
            let outURL = tempDir.appendingPathComponent("TankControl_Afiche_\(info.columns)x\(info.rows)_\(Int(Date().timeIntervalSince1970)).pdf")

            var mediaBox = CGRect(x: 0, y: 0, width: info.pageWidthPt, height: info.pageHeightPt)
            guard let consumer = CGDataConsumer(url: outURL as CFURL),
                  let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    completion(.failure(NSError(domain: "TankControl", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo inicializar el generador de PDF"])))
                }
                return
            }

            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let cgImage = bitmap.cgImage else {
                DispatchQueue.main.async {
                    self.isGenerating = false
                    completion(.failure(NSError(domain: "TankControl", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error convirtiendo imagen de mapa de bits"])))
                }
                return
            }

            let imgW = CGFloat(cgImage.width)
            let imgH = CGFloat(cgImage.height)

            let marginPt: CGFloat = 6.0 * 2.83465
            let overlapPt: CGFloat = CGFloat(info.overlapMm) * 2.83465

            let tilePrintableW = info.pageWidthPt - 2 * marginPt
            let tilePrintableH = info.pageHeightPt - 2 * marginPt

            let netTileW = max(50.0, tilePrintableW - overlapPt)
            let netTileH = max(50.0, tilePrintableH - overlapPt)

            let sliceNormW = 1.0 / CGFloat(info.columns)
            let sliceNormH = 1.0 / CGFloat(info.rows)
            let overlapNormX = (overlapPt / (netTileW * CGFloat(info.columns)))
            let overlapNormY = (overlapPt / (netTileH * CGFloat(info.rows)))

            var pageNumber = 1
            let totalPages = info.columns * info.rows

            // Recorrer filas desde arriba hacia abajo (filas 0 = superior)
            for r in 0..<info.rows {
                for c in 0..<info.columns {
                    pdfCtx.beginPage(mediaBox: &mediaBox)

                    // Fondo blanco
                    pdfCtx.setFillColor(NSColor.white.cgColor)
                    pdfCtx.fill(mediaBox)

                    // Área de impresión del mosaico
                    let targetRect = CGRect(x: marginPt, y: marginPt, width: tilePrintableW, height: tilePrintableH)

                    // Calcular la porción de la imagen original a recortar
                    let normX = CGFloat(c) * sliceNormW
                    let normY = CGFloat(info.rows - 1 - r) * sliceNormH

                    let srcX = max(0, normX * imgW)
                    let srcY = max(0, normY * imgH)
                    let srcW = min(imgW - srcX, (sliceNormW + overlapNormX) * imgW)
                    let srcH = min(imgH - srcY, (sliceNormH + overlapNormY) * imgH)

                    let cropRect = CGRect(x: srcX, y: srcY, width: srcW, height: srcH)

                    if let croppedCG = cgImage.cropping(to: cropRect) {
                        pdfCtx.saveGState()
                        pdfCtx.clip(to: targetRect)
                        pdfCtx.draw(croppedCG, in: targetRect)
                        pdfCtx.restoreGState()
                    }

                    // Guías de corte y marcas de registro
                    if self.includeCutGuides {
                        pdfCtx.saveGState()
                        pdfCtx.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.6).cgColor)
                        pdfCtx.setLineWidth(0.75)
                        let lengths: [CGFloat] = [4, 4]
                        pdfCtx.setLineDash(phase: 0, lengths: lengths)
                        pdfCtx.stroke(targetRect)

                        // Cruces de registro en las esquinas
                        let crossSize: CGFloat = 8.0
                        pdfCtx.setLineDash(phase: 0, lengths: [])
                        pdfCtx.setStrokeColor(NSColor.black.cgColor)
                        pdfCtx.setLineWidth(1.0)

                        let corners = [
                            CGPoint(x: targetRect.minX, y: targetRect.minY),
                            CGPoint(x: targetRect.maxX, y: targetRect.minY),
                            CGPoint(x: targetRect.minX, y: targetRect.maxY),
                            CGPoint(x: targetRect.maxX, y: targetRect.maxY)
                        ]
                        for pt in corners {
                            pdfCtx.move(to: CGPoint(x: pt.x - crossSize, y: pt.y))
                            pdfCtx.addLine(to: CGPoint(x: pt.x + crossSize, y: pt.y))
                            pdfCtx.move(to: CGPoint(x: pt.x, y: pt.y - crossSize))
                            pdfCtx.addLine(to: CGPoint(x: pt.x, y: pt.y + crossSize))
                        }
                        pdfCtx.strokePath()
                        pdfCtx.restoreGState()
                    }

                    // Pie de página de ensamblado en la solapa inferior
                    if self.includeGlueTabs {
                        let labelText = "TankControl Afiche · Cuadrícula [Fila \(r + 1)/\(info.rows), Columna \(c + 1)/\(info.columns)] · Hoja \(pageNumber) de \(totalPages) · Solapa \(Int(info.overlapMm)) mm"
                        let attrs: [NSAttributedString.Key: Any] = [
                            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
                            .foregroundColor: NSColor.secondaryLabelColor
                        ]
                        let str = NSAttributedString(string: labelText, attributes: attrs)
                        let textRect = CGRect(x: marginPt, y: 4, width: info.pageWidthPt - 2 * marginPt, height: 12)
                        let line = CTLineCreateWithAttributedString(str)
                        pdfCtx.saveGState()
                        pdfCtx.textPosition = CGPoint(x: textRect.minX, y: textRect.minY)
                        CTLineDraw(line, pdfCtx)
                        pdfCtx.restoreGState()
                    }

                    pdfCtx.endPage()
                    pageNumber += 1
                }
            }

            pdfCtx.closePDF()

            DispatchQueue.main.async {
                self.isGenerating = false
                self.lastGeneratedPDFURL = outURL
                self.statusMessage = "Afiche generado con éxito: \(totalPages) hojas listas para imprimir."
                completion(.success(outURL))
            }
        }
    }

    /// Abre el afiche generado en la aplicación Vista Previa (Preview.app) nativa de macOS
    public func openInPreview() {
        if let url = lastGeneratedPDFURL {
            NSWorkspace.shared.open(url)
        } else {
            generatePosterPDF { result in
                if case .success(let url) = result {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    /// Envía directamente el afiche a la cola CUPS de la HP Smart Tank 500
    public func printToSmartTank(printerName: String = "HP_Smart_Tank_500", completion: @escaping (Bool) -> Void) {
        let action = { (url: URL) in
            var args = ["-P", printerName]
            switch self.paperFormatId {
            case "carta": args += ["-o", "PageSize=Letter"]
            case "a4": args += ["-o", "PageSize=A4"]
            case "oficio": args += ["-o", "PageSize=8.5x13"]
            case "legal": args += ["-o", "PageSize=Legal"]
            default: break
            }
            args.append(url.path)

            DispatchQueue.global(qos: .userInitiated).async {
                let lprURL = URL(fileURLWithPath: "/usr/bin/lpr")
                let result = ProcessRunner.shared.run(executableURL: lprURL, arguments: args)
                DispatchQueue.main.async {
                    if result.exitCode == 0 {
                        self.statusMessage = "Trabajo de afiche (\(self.currentInfo.totalPages) hojas) enviado a la impresora."
                        completion(true)
                    } else {
                        self.statusMessage = "Error enviando a la impresora: \(result.stderr)"
                        completion(false)
                    }
                }
            }
        }

        if let url = lastGeneratedPDFURL {
            action(url)
        } else {
            generatePosterPDF { result in
                switch result {
                case .success(let url): action(url)
                case .failure: completion(false)
                }
            }
        }
    }
}
