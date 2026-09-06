import SwiftUI

/// Vista de Actividad: Odómetro oficial de hardware, confiabilidad mecánica e historial de trabajos locales.
public struct ActivityView: View {
    @ObservedObject var printer: PrinterManager

    @ObservedObject private var historyStore = JobHistoryStore.shared

    private var numberFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        return f
    }

    private func formatNumber(_ val: Int?) -> String {
        guard let v = val else { return "—" }
        return numberFormatter.string(from: NSNumber(value: v)) ?? "\(v)"
    }

    private var telemetrySourceLabel: String {
        if printer.connectionState.isConnected {
            return "Lectura directa de hardware (LIVE)"
        } else if printer.odometer != nil {
            return "Último registro guardado"
        } else {
            return "Sin conexión activa"
        }
    }

    private var telemetrySourceColor: Color {
        if printer.connectionState.isConnected {
            return .green
        } else {
            return .secondary
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // MARK: - Cabecera Principal
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Actividad")
                            .font(DesignTokens.Fonts.title)
                        Text("Contadores comunicados por la impresora.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    HStack(spacing: 6) {
                        Circle()
                            .fill(telemetrySourceColor)
                            .frame(width: 8, height: 8)
                        Text(telemetrySourceLabel)
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(printer.connectionState.isConnected ? .green : .secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(telemetrySourceColor.opacity(0.12))
                    .cornerRadius(DesignTokens.Radii.small)
                }

                Divider()

                // MARK: - Odómetro de Hardware (EWS / ProductUsageDyn)
                if let odo = printer.odometer {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("Uso de la impresora")
                                .font(DesignTokens.Fonts.sectionHeader)
                            Spacer()
                            Text("Modelo: HP Smart Tank 500")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 210))], spacing: DesignTokens.Spacing.sm) {
                            MetricCard(
                                icon: "doc.text.fill",
                                title: "Total Páginas Impresas",
                                value: formatNumber(odo.calculatedTotalPages),
                                sublabel: "\(formatNumber(odo.mono_pages)) B/N • \(formatNumber(odo.color_pages)) Color",
                                tintColor: .accentColor
                            )
                            MetricCard(
                                icon: "doc.plaintext",
                                title: "Monocromático (Texto)",
                                value: formatNumber(odo.mono_pages),
                                sublabel: "Páginas con tinta negra K",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "paintpalette.fill",
                                title: "Color (Gráficos/Fotos)",
                                value: formatNumber(odo.color_pages),
                                sublabel: "Páginas con tinta CMY",
                                tintColor: .purple
                            )
                            MetricCard(
                                icon: "scanner.fill",
                                title: "Digitalizaciones Ópticas",
                                value: formatNumber(odo.scans),
                                sublabel: "Ciclos de platina plana CIS",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "checkmark.shield.fill",
                                title: "Atascos de Papel",
                                value: formatNumber(odo.jams),
                                sublabel: (odo.jams ?? 0) == 0 ? "Atascos registrados" : "Requiere inspección mecánica",
                                tintColor: (odo.jams ?? 0) == 0 ? .green : .red
                            )
                            MetricCard(
                                icon: "arrow.triangle.2.circlepath",
                                title: "Reintentos de Arrastre",
                                value: formatNumber(odo.pick_failures),
                                sublabel: (odo.pick_failures ?? 0) == 0 ? "Reintentos registrados" : "Limpiar rodillo de toma",
                                tintColor: (odo.pick_failures ?? 0) == 0 ? .green : .orange
                            )
                        }
                    }

                    // MARK: - Gotas Disparadas y Estimación de Tinta
                    if let drops = odo.drops, drops.totalDrops > 0 {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Consumo Acumulado por Conteo de Microgotas")
                                .font(DesignTokens.Fonts.sectionHeader)

                            HStack(spacing: DesignTokens.Spacing.md) {
                                Image(systemName: "drop.degreesign.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Total Gotas Disparadas: \(formatNumber(drops.totalDrops)) gotas")
                                        .font(DesignTokens.Fonts.bodyMedium)
                                    Text("Volumen acumulado estimado en inyectores: \(String(format: "%.2f ml", drops.estimatedVolumeMilliliters))")
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            .padding(DesignTokens.Spacing.md)
                            .background(DesignTokens.Colors.surfaceGrouped)
                            .cornerRadius(DesignTokens.Radii.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                    .stroke(DesignTokens.Colors.border, lineWidth: 1)
                            )
                        }
                    }
                } else {
                    VStack(spacing: DesignTokens.Spacing.sm) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundColor(.secondary)
                        Text("Telemetría de Odómetro No Disponible")
                            .font(DesignTokens.Fonts.headline)
                        Text("Conecte la HP Smart Tank 500 por USB para consultar los contadores de hardware.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.Spacing.xl)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                Divider()

                // MARK: - Historial Local de Trabajos
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Historial Local de Trabajos")
                                .font(DesignTokens.Fonts.sectionHeader)
                            Text("Registro persistente sincronizado con la cola CUPS local.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        Button("Limpiar Registro") {
                            historyStore.clearJobs()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(historyStore.jobs.isEmpty)
                    }

                    if historyStore.jobs.isEmpty {
                        EmptyStateView(
                            icon: "clock.arrow.circlepath",
                            title: "Sin Trabajos Registrados",
                            message: "Los trabajos enviados a la impresora se registrarán automáticamente."
                        )
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                    } else {
                        VStack(spacing: 6) {
                            ForEach(historyStore.jobs) { job in
                                HStack(spacing: DesignTokens.Spacing.md) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.accentColor)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(job.title)
                                            .font(DesignTokens.Fonts.bodyMedium)
                                        Text("\(job.pages) páginas • \(job.formattedSize) • Usuario: \(job.user)")
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
                                .background(DesignTokens.Colors.surfaceGrouped)
                                .cornerRadius(DesignTokens.Radii.small)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                        .stroke(DesignTokens.Colors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }
            .padding(DesignTokens.Spacing.xl)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
