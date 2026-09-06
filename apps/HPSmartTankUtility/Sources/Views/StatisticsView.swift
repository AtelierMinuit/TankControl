import SwiftUI

/// Vista de Estadísticas: Telemetría de contadores EWS, páginas, gotas y almohadillas.
/// Distingue explícitamente entre datos leídos de Hardware, Estimados o de Simulación Mock.
public struct StatisticsView: View {
    @ObservedObject var printer: PrinterManager

    private var telemetrySourceLabel: String {
        if printer.connectionState.isConnected {
            return "Lectura directa de hardware (EWS)"
        } else if printer.odometer != nil {
            return "Último registro local guardado"
        } else {
            return "Sin conexión activa"
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Estadísticas y Telemetría")
                            .font(DesignTokens.Fonts.title)
                        Text("Contadores oficiales de páginas, ciclos de escaneo y consumo acumulado.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    Text(telemetrySourceLabel)
                        .font(DesignTokens.Fonts.captionBold)
                        .foregroundColor(printer.connectionState.isConnected ? .green : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((printer.connectionState.isConnected ? Color.green : Color.secondary).opacity(0.12))
                        .cornerRadius(DesignTokens.Radii.small)
                }

                Divider()

                // MARK: - Contadores de Páginas y Documentos
                if let odo = printer.odometer {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Páginas Procesadas")
                            .font(DesignTokens.Fonts.sectionHeader)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.sm) {
                            MetricCard(
                                icon: "doc.text",
                                title: "Total Páginas",
                                value: "\(odo.total_pages ?? 0)",
                                sublabel: "Contador físico EWS",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "doc",
                                title: "Monocromo (B/N)",
                                value: "\(odo.mono_pages ?? 0)",
                                sublabel: "Canal negro K",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "paintpalette",
                                title: "Color (CMYK)",
                                value: "\(odo.color_pages ?? 0)",
                                sublabel: "Canales de color",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "photo",
                                title: "Sin Bordes",
                                value: "\(odo.borderless_pages ?? 0)",
                                sublabel: "Fotos y folletos sangrados",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "scanner",
                                title: "Escaneos",
                                value: "\(odo.scans ?? 0)",
                                sublabel: "Cristal óptico",
                                tintColor: .primary
                            )
                            MetricCard(
                                icon: "exclamationmark.triangle",
                                title: "Atascos",
                                value: "\(odo.jams ?? 0)",
                                sublabel: (odo.jams ?? 0) > 0 ? "Requiere revisión" : "Sin atascos activos",
                                tintColor: (odo.jams ?? 0) > 0 ? .orange : .green
                            )
                        }
                    }

                    Divider()

                    // MARK: - Gotas Disparadas y Volumen
                    if let drops = odo.drops {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            HStack {
                                Text("Micro-Gotas Disparadas por Canal")
                                    .font(DesignTokens.Fonts.sectionHeader)
                                Spacer()
                                Text("Estimación basada en micro-pasos PCL3GUI")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: DesignTokens.Spacing.sm) {
                                MetricCard(
                                    icon: "square.fill",
                                    title: "Negro (K)",
                                    value: String(format: "%.1fM", Double(drops.k ?? 0) / 1_000_000.0),
                                    sublabel: "gotas",
                                    tintColor: DesignTokens.Colors.inkBlack
                                )
                                MetricCard(
                                    icon: "triangle.fill",
                                    title: "Cian (C)",
                                    value: String(format: "%.1fM", Double(drops.c ?? 0) / 1_000_000.0),
                                    sublabel: "gotas",
                                    tintColor: DesignTokens.Colors.inkCyan
                                )
                                MetricCard(
                                    icon: "diamond.fill",
                                    title: "Magenta (M)",
                                    value: String(format: "%.1fM", Double(drops.m ?? 0) / 1_000_000.0),
                                    sublabel: "gotas",
                                    tintColor: DesignTokens.Colors.inkMagenta
                                )
                                MetricCard(
                                    icon: "circle.fill",
                                    title: "Amarillo (Y)",
                                    value: String(format: "%.1fM", Double(drops.y ?? 0) / 1_000_000.0),
                                    sublabel: "gotas",
                                    tintColor: DesignTokens.Colors.inkYellow
                                )
                            }
                        }
                    }

                    Divider()

                    // MARK: - Informes de Mantenimiento y Costes
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Informes de Hardware y Almohadillas")
                            .font(DesignTokens.Fonts.sectionHeader)

                        HStack(spacing: DesignTokens.Spacing.sm) {
                            ActionCard(
                                icon: "archivebox",
                                title: "Almohadillas de Desecho",
                                description: "Porcentaje de saturación de la esponja absorbedora de tinta residual.",
                                buttonLabel: "Consultar Almohadilla",
                                action: { printer.showWasteInk() }
                            )

                            ActionCard(
                                icon: "dollarsign.circle",
                                title: "Auditoría de Costes",
                                description: "Coste medio estimado por página impresa según consumo de tinta.",
                                buttonLabel: "Ver Costes",
                                action: { printer.showAccounting() }
                            )
                        }
                    }
                } else {
                    EmptyStateView(
                        icon: "chart.bar",
                        title: "Telemetría no Disponible",
                        message: "Conecta la impresora vía USB para leer los contadores de hardware o activa la simulación en Configuración."
                    )
                    .frame(height: 180)
                }
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}
