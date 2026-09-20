import SwiftUI
import AppKit
import PDFKit

/// Hoja modal asistida paso a paso para la impresión a doble cara manual en la HP Smart Tank 500
public struct ManualDuplexSheetView: View {
    @ObservedObject private var duplexService = DuplexPrintService.shared
    @Environment(\.presentationMode) var presentationMode

    @State private var showingFilePicker = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Barra Superior
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "doc.on.doc.fill")
                        .foregroundColor(DesignTokens.Colors.brandTeal)
                        .font(.system(size: 16, weight: .bold))
                    Text("Asistente de Impresión Doble Cara (Dúplex)")
                        .font(DesignTokens.Fonts.headline)
                }
                Spacer()
                Button("Cerrar") {
                    duplexService.reset()
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(DesignTokens.Colors.surfaceGrouped)

            Divider()

            // MARK: - Contenido Central Dinámico según el Paso
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch duplexService.currentStep {
                    case .idle:
                        idleSetupView

                    case .printingOdds(let progress):
                        processingView(title: "Imprimiendo Caras Impares", detail: progress, icon: "paperplane.fill")

                    case .waitingForFlip(let total, let odds, let evens):
                        flipInstructionsView(totalPages: total, oddCount: odds, evenCount: evens)

                    case .printingEvens(let progress):
                        processingView(title: "Imprimiendo Caras Pares", detail: progress, icon: "paperplane.fill")

                    case .completed(let total):
                        completedView(totalPages: total)

                    case .error(let msg):
                        errorView(message: msg)
                    }
                }
                .padding(20)
            }

            Divider()

            // MARK: - Barra Inferior con Botones de Acción
            HStack {
                Text(duplexService.statusMessage)
                    .font(DesignTokens.Fonts.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                actionButtonsForCurrentStep
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(DesignTokens.Colors.surfaceGrouped)
        }
        .frame(width: 580, height: 490)
    }

    // MARK: - Subvistas por Paso

    private var idleSetupView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Configura el documento PDF para imprimir a doble cara coordinada.")
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)

            // Selector de Archivo PDF
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 28))
                    .foregroundColor(duplexService.selectedPdfURL != nil ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(duplexService.selectedPdfURL?.lastPathComponent ?? "Ningún archivo seleccionado")
                        .font(DesignTokens.Fonts.bodyMedium)
                        .lineLimit(1)
                    Text(duplexService.totalPages > 0 ? "\(duplexService.totalPages) páginas totales (\(duplexService.oddPageIndices().count) impares / \(duplexService.evenPageIndices().count) pares)" : "Formatos soportados: PDF de cualquier tamaño")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Seleccionar PDF…") {
                    selectPDFFile()
                }
                .buttonStyle(.bordered)
            }
            .padding(12)
            .background(DesignTokens.Colors.surfaceGrouped)
            .cornerRadius(DesignTokens.Radii.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            )

            // Opciones de Paginación
            VStack(alignment: .leading, spacing: 10) {
                Text("Opciones de Alimentación de Bandeja")
                    .font(DesignTokens.Fonts.sectionHeader)

                Toggle(isOn: $duplexService.reverseEvenPages) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Invertir orden de caras pares (Recomendado)")
                            .font(DesignTokens.Fonts.bodyMedium)
                        Text("Optimizado para la bandeja vertical trasera: evita tener que ordenar las hojas a mano tras imprimir.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(12)
            .background(DesignTokens.Colors.surfaceGrouped)
            .cornerRadius(DesignTokens.Radii.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
            )
        }
    }

    private func processingView(title: String, detail: String, icon: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text(title)
                .font(DesignTokens.Fonts.headline)
            Text(detail)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func flipInstructionsView(totalPages: Int, oddCount: Int, evenCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 20))
                Text("Fase 1 completada: \(oddCount) caras impares impresas.")
                    .font(DesignTokens.Fonts.headline)
            }

            Text("Sigue estos 3 pasos antes de imprimir las caras pares:")
                .font(DesignTokens.Fonts.bodyMedium)

            // Diagrama de Instrucciones Visuales
            VStack(alignment: .leading, spacing: 12) {
                instructionRow(
                    step: "1",
                    title: "Retira el fajo de la bandeja de salida inferior",
                    desc: "Toma las hojas exactamente como cayeron, sin cambiar el orden de las páginas."
                )

                instructionRow(
                    step: "2",
                    title: "Gira el fajo 180° (de abajo hacia arriba)",
                    desc: "La cara impresa debe quedar mirando hacia atrás; la cara en blanco debe mirar hacia el frente."
                )

                instructionRow(
                    step: "3",
                    title: "Inserta el fajo en la bandeja trasera superior",
                    desc: "Asegura la guía de ancho de papel para evitar que las hojas se tuerzan durante el arrastre."
                )
            }
            .padding(14)
            .background(Color.accentColor.opacity(0.06))
            .cornerRadius(DesignTokens.Radii.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func instructionRow(step: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.brandTeal)
                    .frame(width: 24, height: 24)
                Text(step)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignTokens.Fonts.bodyMedium)
                Text(desc)
                    .font(DesignTokens.Fonts.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func completedView(totalPages: Int) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("¡Documento Dúplex Completado!")
                .font(DesignTokens.Fonts.title)

            Text("Se imprimieron las \(totalPages) páginas a doble cara en la HP Smart Tank 500.")
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.red)
            Text("Error en la Impresión")
                .font(DesignTokens.Fonts.headline)
            Text(message)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private var actionButtonsForCurrentStep: some View {
        switch duplexService.currentStep {
        case .idle:
            Button("Imprimir Caras Impares") {
                duplexService.startPrintingOdds { _ in }
            }
            .buttonStyle(.borderedProminent)
            .disabled(duplexService.selectedPdfURL == nil || duplexService.isBusy)

        case .waitingForFlip:
            Button("Continuar con Caras Pares") {
                duplexService.startPrintingEvens { _ in }
            }
            .buttonStyle(.borderedProminent)
            .disabled(duplexService.isBusy)

        case .completed, .error:
            Button("Finalizar") {
                duplexService.reset()
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.borderedProminent)

        default:
            EmptyView()
        }
    }

    private func selectPDFFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.pdf]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Seleccionar PDF"

        if panel.runModal() == .OK, let url = panel.url {
            _ = duplexService.loadPDF(url: url)
        }
    }
}
