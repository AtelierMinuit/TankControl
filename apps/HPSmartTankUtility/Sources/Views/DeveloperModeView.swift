import SwiftUI

/// Sección exclusiva de Desarrollo y Diagnóstico de Bajo Nivel (Developer Mode).
/// Oculta por defecto; se activa únicamente desde Configuración.
public struct DeveloperModeView: View {
    @ObservedObject var printer: PrinterManager

    @State private var showingRawInjectConfirmation = false
    @State private var showingPrimeTubesConfirmation = false
    @State private var copiedToClipboard = false

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Cabecera
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Desarrollo")
                                .font(DesignTokens.Fonts.title)
                            Text("DEVELOPER MODE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .cornerRadius(3)
                        }
                        Text("Acceso a descriptores USB, volcados XML de firmware y telemetría cruda.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: copyDiagnosticToClipboard) {
                        Label(copiedToClipboard ? "Copiado" : "Copiar Diagnóstico", systemImage: copiedToClipboard ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }

                Divider()

                // MARK: - Topología y Descriptores USB
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Referencia USB del modelo · no es una lectura en vivo")
                        .font(DesignTokens.Fonts.sectionHeader)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        LabeledRow("Interfaz 0 (0xFF/0xCC/0x00):") {
                            Text("Vendor Specific Printing • OUT EP 0x02 • IN EP 0x81")
                                .font(DesignTokens.Fonts.mono)
                        }
                        Divider()
                        LabeledRow("Interfaz 1 (0x07/0x01/0x02):") {
                            Text("1284.4 Bidirectional Printer • OUT EP 0x02 • IN EP 0x82")
                                .font(DesignTokens.Fonts.mono)
                        }
                        Divider()
                        LabeledRow("Interfaz 2 (0xFF/0x04/0x01):") {
                            Text("Vendor Specific Scanner • OUT EP 0x02 • IN EP 0x82")
                                .font(DesignTokens.Fonts.mono)
                        }
                    }
                    .padding(DesignTokens.Spacing.sm)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.small)
                }

                // MARK: - Volcado LEDM y Pruebas Crudas
                DisclosureGroup("Operaciones de hardware · avanzadas") {

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.sm) {
                        ActionCard(
                            icon: "network",
                            title: "Volcado Árbol LEDM",
                            description: "Consulta y vuelca las capacidades XML de firmware directamente del dispositivo.",
                            buttonLabel: "Volcar Árbol XML",
                            action: { printer.dumpFirmwareTree() }
                        )

                        ActionCard(
                            icon: "terminal",
                            title: "Inyección Raw USB",
                            description: "Envía un paquete de prueba directo al Endpoint 0x02 (Bulk OUT).",
                            buttonLabel: "Inyectar Paquete...",
                            tintColor: .secondary,
                            isDangerous: true,
                            action: { showingRawInjectConfirmation = true }
                        )

                        ActionCard(
                            icon: "drop.triangle.fill",
                            title: "Cebado Forzado CISS",
                            description: "Purga de burbujas en mangueras de silicona con bomba peristáltica.",
                            buttonLabel: "Cebar Tubos...",
                            tintColor: .red,
                            badge: "Crítico",
                            isDangerous: true,
                            action: { showingPrimeTubesConfirmation = true }
                        )

                        ActionCard(
                            icon: "checkerboard.rectangle",
                            title: "Patrón CMYK Completo",
                            description: "Imprime la cuadrícula de alineación y micropaso de papel.",
                            buttonLabel: "Imprimir CMYK",
                            action: { printer.printTestPattern(type: "cmyk") }
                        )
                    }
                }

                Divider()

                // MARK: - Auditoría de Subsistemas del Driver
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Diagnóstico Modular de Subsistemas")
                        .font(DesignTokens.Fonts.sectionHeader)

                    if printer.diagnostics.isEmpty {
                        EmptyStateView(
                            icon: "waveform.path.ecg",
                            title: "Sin Verificaciones",
                            message: "Actualiza el estado para ejecutar los chequeos de sistema."
                        )
                        .frame(height: 100)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(printer.diagnostics) { item in
                                DiagnosticRow(item: item)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(isPresented: $showingRawInjectConfirmation) {
            ConfirmationSheet(
                title: "Confirmar Inyección Raw USB",
                operationName: "Raw USB Bulk Transfer (EP 0x02)",
                riskLevel: "Riesgo de bloqueo de firmware",
                inkConsumption: "0 ml (Trama PJL pura)",
                estimatedDuration: "< 2 segundos",
                technicalWarning: "Esta acción transfiere bytes crudos directamente al puerto USB de la impresora. Úsala exclusivamente para verificar descriptores y respuesta a comandos PJL.",
                onConfirm: {
                    showingRawInjectConfirmation = false
                    printer.injectRawDemo()
                },
                onCancel: {
                    showingRawInjectConfirmation = false
                }
            )
        }
        .sheet(isPresented: $showingPrimeTubesConfirmation) {
            ConfirmationSheet(
                title: "Confirmar Cebado Forzado CISS",
                operationName: "Cebado y Purga de Tubos de Tinta",
                riskLevel: "Desgaste de Bomba / Consumo Severo",
                inkConsumption: "~15 a 20 ml de tinta total de los 4 tanques",
                estimatedDuration: "4 a 6 minutos",
                technicalWarning: "Esta rutina activa la bomba peristáltica a máxima velocidad para forzar la evacuación de aire en las mangueras. Solo debe usarse si se vaciaron completamente los depósitos.",
                onConfirm: {
                    showingPrimeTubesConfirmation = false
                    printer.primeTubes()
                },
                onCancel: {
                    showingPrimeTubesConfirmation = false
                }
            )
        }
    }

    private func copyDiagnosticToClipboard() {
        var text = """
        TANKCONTROL — DIAGNÓSTICO DEL SISTEMA (SEGURO / SIN DATOS PRIVADOS)
        Fecha: \(Date().description)
        Host: macOS Apple Silicon (ARM64)
        Impresora: HP Smart Tank 500 series (0x03F0:0x2B54, ASIC P15_CISS)
        Estado: \(printer.connectionState.label)
        Modo de Operación: Exclusivamente Hardware Real

        SUBSISTEMAS:
        """
        for item in printer.diagnostics {
            text += "\n[\(item.status.rawValue.uppercased())] \(item.subsystem): \(item.name) — \(item.message)"
            if let tech = item.technicalDetails {
                text += " (\(tech))"
            }
        }
        if let odo = printer.odometer {
            text += "\n\nODÓMETRO: \(odo.total_pages ?? 0) págs (\(odo.mono_pages ?? 0) mono, \(odo.color_pages ?? 0) col), \(odo.scans ?? 0) scans, \(odo.jams ?? 0) jams."
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        copiedToClipboard = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            copiedToClipboard = false
        }
    }
}
