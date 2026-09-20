import SwiftUI
import AppKit

/// Estudio de Afiches y Mosaicos Gran Formato para TankControl
public struct PosterStudioView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var service = PosterTileService.shared
    @ObservedObject private var loc = LocalizationService.shared

    @State private var showingFilePicker = false
    @State private var showingPrintConfirmation = false
    @State private var showSuccessBanner = false
    @State private var successBannerText = ""

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // MARK: - Cabecera
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "square.grid.3x3.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.indigo)
                        .frame(width: 40, height: 40)
                        .background(Color.indigo.opacity(0.12))
                        .cornerRadius(DesignTokens.Radii.small)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc.t("section_poster_studio"))
                            .font(DesignTokens.Fonts.title)
                        Text("Impresión multipágina en mosaico con solapas y marcas de corte.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: selectFile) {
                        Label(service.selectedImage == nil ? "Cargar Imagen o PDF…" : "Cambiar Archivo…", systemImage: "photo.badge.plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }

                if showSuccessBanner {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successBannerText)
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(.green)
                        Spacer()
                        Button(action: { showSuccessBanner = false }) {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(DesignTokens.Radii.small)
                }

                // MARK: - Contenedor Principal en Dos Columnas Adaptables
                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    // Columna Izquierda: Ajustes de Cuadrícula y Papel (Ancho acotado para evitar overlay)
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // Presets de Mosaico
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distribución en Mosaico")
                                .font(DesignTokens.Fonts.sectionHeader)

                            HStack(spacing: 6) {
                                presetButton(title: "2×2 (4 Hojas)", cols: 2, rows: 2)
                                presetButton(title: "3×3 (9 Hojas)", cols: 3, rows: 3)
                                presetButton(title: "4×4 (16 Hojas)", cols: 4, rows: 4)
                            }

                            HStack(spacing: 6) {
                                presetButton(title: "2×1 (Díptico)", cols: 2, rows: 1)
                                presetButton(title: "1×3 (Pancarta)", cols: 3, rows: 1)
                                presetButton(title: "1×4 (Banner)", cols: 4, rows: 1)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )

                        // Selector de Papel y Solapa
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Sustrato y Solapas")
                                .font(DesignTokens.Fonts.sectionHeader)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tamaño de Papel:")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)

                                Picker("", selection: $service.paperFormatId) {
                                    Text("Carta (8.5 × 11 pulg.)").tag("carta")
                                    Text("Oficio (8.5 × 13 pulg. / Chile-LATAM)").tag("oficio")
                                    Text("Legal (8.5 × 14 pulg.)").tag("legal")
                                    Text("A4 (210 × 297 mm)").tag("a4")
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Margen de Solapa de Pegado:")
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(service.overlapMm, specifier: "%.0f") mm")
                                        .font(DesignTokens.Fonts.mono)
                                        .bold()
                                }

                                Slider(value: $service.overlapMm, in: 5...25, step: 1)
                            }

                            Toggle("Imprimir guías de corte punteadas", isOn: $service.includeCutGuides)
                                .font(DesignTokens.Fonts.caption)

                            Toggle("Marcas de registro y numeración", isOn: $service.includeGlueTabs)
                                .font(DesignTokens.Fonts.caption)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )

                        // Resumen Dimensional
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "ruler.fill")
                                    .foregroundColor(.indigo)
                                Text("Dimensiones Ensambladas")
                                    .font(DesignTokens.Fonts.bodyMedium)
                                Spacer()
                                Text("\(service.currentInfo.totalPages) Hojas")
                                    .font(.system(size: 11, weight: .bold))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.indigo.opacity(0.15))
                                    .foregroundColor(.indigo)
                                    .cornerRadius(4)
                            }

                            HStack(alignment: .firstTextBaseline) {
                                Text("\(service.currentInfo.posterWidthCm, specifier: "%.1f") × \(service.currentInfo.posterHeightCm, specifier: "%.1f") cm")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)

                                Spacer()

                                Text("(\(service.currentInfo.columns) col × \(service.currentInfo.rows) fil)")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Text("Formato base: \(service.currentInfo.paperName)")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                    }
                    .frame(width: 290)

                    // Columna Derecha: Previsualización Gráfica y Acciones
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        Text("Previsualización de Ensamblado")
                            .font(DesignTokens.Fonts.sectionHeader)

                        // Contenedor visual del afiche con cuadrícula
                        ZStack {
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                .fill(Color.secondary.opacity(0.06))
                                .frame(height: 320)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                        .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                )

                            if let image = service.selectedImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 300)
                                    .cornerRadius(DesignTokens.Radii.small)
                                    .overlay(
                                        // Cuadrícula sobrepuesta
                                        GeometryReader { geo in
                                            ZStack {
                                                // Líneas verticales
                                                ForEach(1..<service.gridColumns, id: \.self) { c in
                                                    Path { path in
                                                        let x = geo.size.width * CGFloat(c) / CGFloat(service.gridColumns)
                                                        path.move(to: CGPoint(x: x, y: 0))
                                                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                                                    }
                                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                                    .foregroundColor(Color.white.opacity(0.85))
                                                }

                                                // Líneas horizontales
                                                ForEach(1..<service.gridRows, id: \.self) { r in
                                                    Path { path in
                                                        let y = geo.size.height * CGFloat(r) / CGFloat(service.gridRows)
                                                        path.move(to: CGPoint(x: 0, y: y))
                                                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                                                    }
                                                    .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                                    .foregroundColor(Color.white.opacity(0.85))
                                                }
                                            }
                                        }
                                    )
                                    .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 40))
                                        .foregroundColor(.secondary.opacity(0.7))
                                    Text("Sin documento cargado")
                                        .font(DesignTokens.Fonts.bodyMedium)
                                        .foregroundColor(.secondary)
                                    Text("Selecciona una imagen o archivo PDF para generar el afiche en mosaico.")
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: 240)
                                    Button(action: selectFile) {
                                        Label("Seleccionar Archivo…", systemImage: "plus")
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .padding(.top, 4)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)

                        if let fname = service.imageFileName {
                            HStack {
                                Image(systemName: "doc.fill")
                                    .foregroundColor(.secondary)
                                Text(fname)
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                Spacer()
                                Button("Cambiar", action: selectFile)
                                    .font(DesignTokens.Fonts.caption)
                                    .buttonStyle(.plain)
                                    .foregroundColor(.accentColor)
                            }
                        }

                        // Botones de acción
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Button(action: { service.openInPreview() }) {
                                Label("Ver en Vista Previa", systemImage: "eye.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(service.selectedImage == nil || service.isGenerating)

                            Button(action: { showingPrintConfirmation = true }) {
                                Label("Imprimir Afiche (\(service.currentInfo.totalPages) Hojas)…", systemImage: "printer.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(service.selectedImage == nil || service.isGenerating)
                        }

                        if service.isGenerating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text(service.statusMessage)
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(minWidth: 260, maxWidth: .infinity)
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .confirmationDialog(
            "¿Enviar trabajo de afiche a la HP Smart Tank 500?",
            isPresented: $showingPrintConfirmation,
            titleVisibility: .visible
        ) {
            Button("Imprimir \(service.currentInfo.totalPages) Hojas (\(service.currentInfo.paperName))", role: .none) {
                service.printToSmartTank(printerName: "HP_Smart_Tank_500") { success in
                    if success {
                        successBannerText = "Afiche enviado exitosamente a la cola de impresión."
                        showSuccessBanner = true
                    }
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Se enviará un trabajo compuesto por \(service.currentInfo.totalPages) páginas a la bandeja de la HP Smart Tank 500. Asegúrate de tener al menos \(service.currentInfo.totalPages) hojas en la bandeja de entrada.")
        }
    }

    private func presetButton(title: String, cols: Int, rows: Int) -> some View {
        Button(action: {
            service.gridColumns = cols
            service.gridRows = rows
        }) {
            Text(title)
                .font(.system(size: 11, weight: service.gridColumns == cols && service.gridRows == rows ? .bold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .background(service.gridColumns == cols && service.gridRows == rows ? Color.indigo : Color.secondary.opacity(0.08))
                .foregroundColor(service.gridColumns == cols && service.gridRows == rows ? .white : .primary)
                .cornerRadius(DesignTokens.Radii.small)
        }
        .buttonStyle(.plain)
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            service.loadFile(url: url)
        }
    }
}
