import SwiftUI

/// Historial local de trabajos impresos y ahorro acumulado.
public struct HistoryView: View {
    @ObservedObject var printer: PrinterManager

    // Lista de trabajos locales de muestra / simulados
    @State private var sampleJobs: [PrintJob] = [
        PrintJob(id: 101, title: "Reporte_Trimestral_Q3.pdf", user: "jorge", pages: 14, sizeBytes: 1024 * 850, state: .completed, date: Date().addingTimeInterval(-3600 * 2)),
        PrintJob(id: 102, title: "Factura_Servicios_0826.pdf", user: "jorge", pages: 2, sizeBytes: 1024 * 120, state: .completed, date: Date().addingTimeInterval(-3600 * 24)),
        PrintJob(id: 103, title: "Fotografia_Paisaje_A4.jpg", user: "jorge", pages: 1, sizeBytes: 1024 * 4200, state: .completed, date: Date().addingTimeInterval(-3600 * 48)),
        PrintJob(id: 104, title: "Esquema_Circuito_PCB.pdf", user: "jorge", pages: 4, sizeBytes: 1024 * 340, state: .completed, date: Date().addingTimeInterval(-3600 * 72))
    ]

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Historial Local de Impresión")
                            .font(DesignTokens.Fonts.headline)
                        Text("Registro de actividad procesada localmente en este Mac.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Limpiar Registro") {
                        sampleJobs.removeAll()
                    }
                    .buttonStyle(.bordered)
                    .disabled(sampleJobs.isEmpty)
                }

                Divider()

                // Declaración de Privacidad
                HStack(spacing: DesignTokens.Spacing.md) {
                    Image(systemName: "hand.raised.shield.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignTokens.Colors.brandTeal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacidad 100% Local y Transparente")
                            .font(DesignTokens.Fonts.bodyMedium)
                        Text("TankControl no recopila contenidos de documentos, nombres privados de archivos ni telemetría remota. Este historial reside únicamente en la memoria local de tu equipo.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .background(DesignTokens.Colors.brandTeal.opacity(0.08))
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.brandTeal.opacity(0.2), lineWidth: 1)
                )

                // Tabla de Trabajos
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Trabajos Recientes")
                        .font(DesignTokens.Fonts.subheadline)

                    if sampleJobs.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "Sin Historial Registrado",
                            message: "Los nuevos documentos procesados aparecerán listados aquí."
                        )
                        .frame(height: 160)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(sampleJobs) { job in
                                HStack(spacing: DesignTokens.Spacing.md) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(DesignTokens.Colors.brandTeal)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(job.title)
                                            .font(DesignTokens.Fonts.bodyMedium)
                                        Text("\(job.pages) páginas • \(job.formattedSize)")
                                            .font(DesignTokens.Fonts.caption)
                                            .foregroundColor(.secondary)
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(job.state.localizedName)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.green)
                                        Text(job.date, style: .date)
                                            .font(DesignTokens.Fonts.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(DesignTokens.Spacing.md)
                                .background(DesignTokens.Colors.cardBackground)
                                .cornerRadius(DesignTokens.Radii.medium)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}
