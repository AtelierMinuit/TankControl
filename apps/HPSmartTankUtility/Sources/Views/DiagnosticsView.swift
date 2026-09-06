import SwiftUI

/// Centro de Diagnóstico del Sistema con auditoría modular y exportación de informes técnicos.
public struct DiagnosticsView: View {
    @ObservedObject var printer: PrinterManager
    @State private var showingExportSuccess = false
    @State private var exportedFilePath = ""

    var overallPassCount: Int {
        printer.diagnostics.filter { $0.status == .pass }.count
    }

    var overallWarningCount: Int {
        printer.diagnostics.filter { $0.status == .warning }.count
    }

    var overallFailCount: Int {
        printer.diagnostics.filter { $0.status == .fail }.count
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Centro de Diagnóstico Integral")
                            .font(DesignTokens.Fonts.headline)
                        Text("Auditoría técnica de subsistemas: CUPS, filtros RIP, permisos, USB y escáner.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: exportDiagnosticReport) {
                        Label("Exportar Reporte...", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.Colors.brandTeal)
                }

                Divider()

                // Resumen Global de Chequeos
                HStack(spacing: DesignTokens.Spacing.md) {
                    MetricCard(
                        icon: "checkmark.circle.fill",
                        title: "Verificaciones OK",
                        value: "\(overallPassCount)",
                        sublabel: "Subsistemas en estado óptimo",
                        tintColor: .green
                    )

                    MetricCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Advertencias",
                        value: "\(overallWarningCount)",
                        sublabel: overallWarningCount > 0 ? "Requiere revisión no crítica" : "Sin advertencias",
                        tintColor: .orange
                    )

                    MetricCard(
                        icon: "xmark.octagon.fill",
                        title: "Fallos Críticos",
                        value: "\(overallFailCount)",
                        sublabel: overallFailCount > 0 ? "Impedimento de operación" : "Cero fallos detectados",
                        tintColor: overallFailCount > 0 ? .red : .gray
                    )
                }

                // Lista Detallada de Subsistemas
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Resultados por Módulo")
                        .font(DesignTokens.Fonts.subheadline)

                    if printer.diagnostics.isEmpty {
                        EmptyStateView(
                            icon: "waveform.path.ecg",
                            title: "Ejecutando Comprobaciones...",
                            message: "Evaluando el estado del sistema CUPS y comunicación con el driver."
                        )
                        .frame(height: 160)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(printer.diagnostics) { item in
                                DiagnosticRow(item: item)
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
        .alert("Reporte Exportado", isPresented: $showingExportSuccess) {
            Button("Aceptar", role: .cancel) {}
            Button("Mostrar en Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: exportedFilePath)])
            }
        } message: {
            Text("El informe de diagnóstico técnico se guardó exitosamente en:\n\(exportedFilePath)\n\nNo contiene datos privados ni nombres de usuario.")
        }
    }

    private func exportDiagnosticReport() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let dateStr = formatter.string(from: Date())

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let fileURL = downloadsURL.appendingPathComponent("TankControl-Diagnostic-\(dateStr).txt")

        var report = """
        ================================================================================
        TANKCONTROL — INFORME DE DIAGNÓSTICO DEL SISTEMA
        Generado: \(Date().description)
        Host: macOS Apple Silicon (ARM64)
        Impresora Objetivo: HP Smart Tank 500 series (0x03F0:0x2B54)
        ================================================================================

        RESUMEN EJECUTIVO:
        - Estado de Conexión: \(printer.connectionState.label)
        - Modo Simulación Activo: \(printer.useMock ? "SÍ (Mock 100% Offline)" : "NO (Hardware Real)")
        - Pruebas Aprobadas: \(overallPassCount)
        - Advertencias: \(overallWarningCount)
        - Fallos: \(overallFailCount)

        DETALLE DE SUBSISTEMAS AUDITADOS:
        """

        for item in printer.diagnostics {
            report += """

            [\(item.status.rawValue.uppercased())] \(item.subsystem) — \(item.name)
              Mensaje: \(item.message)
            """
            if let tech = item.technicalDetails {
                report += "\n  Detalles: \(tech)"
            }
            if let rem = item.remediationSuggestion {
                report += "\n  Resolución: \(rem)"
            }
        }

        if let odo = printer.odometer {
            report += """


            TELEMETRÍA DE HARDWARE (ODÓMETRO):
            - Páginas Totales: \(odo.total_pages ?? 0)
            - Páginas B/N: \(odo.mono_pages ?? 0)
            - Páginas Color: \(odo.color_pages ?? 0)
            - Páginas Sin Bordes: \(odo.borderless_pages ?? 0)
            - Escaneos: \(odo.scans ?? 0)
            - Atascos Registrados: \(odo.jams ?? 0)
            - Gotas Totales K: \(odo.drops?.k ?? 0)
            - Gotas Totales CMY: \((odo.drops?.c ?? 0) + (odo.drops?.m ?? 0) + (odo.drops?.y ?? 0))
            """
        }

        report += """


        ================================================================================
        FIN DEL INFORME — TANKCONTROL OPEN SOURCE DRIVER
        ================================================================================
        """

        do {
            try report.write(to: fileURL, atomically: true, encoding: .utf8)
            exportedFilePath = fileURL.path
            showingExportSuccess = true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Error al exportar reporte"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}
