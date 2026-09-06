import SwiftUI

/// Comparador visual interactivo tipo slider Antes/Después.
public struct VisualComparatorView: View {
    @Binding var sliderPosition: CGFloat // 0.0 (todo original) a 1.0 (todo eco)
    let ecoLevel: InkSaverLevel

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let dividerX = width * sliderPosition

            ZStack(alignment: .leading) {
                // Lado Izquierdo: Vista Con InkSaver (Después)
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                        .fill(Color.white)
                    // Gráfico de muestra simulado aligerado
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INFORME EJECUTIVO ANUAL")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black) // Texto nítido con EdgePreserve

                        HStack(spacing: 8) {
                            // Barras con luminancia elevada
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.brandTeal.opacity(0.65))
                                .frame(width: 40, height: 75)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkMagenta.opacity(0.60))
                                .frame(width: 40, height: 110)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkYellow.opacity(0.70))
                                .frame(width: 40, height: 90)
                        }

                        Text("Texto de párrafo continuo optimizado para lectura clara con menor saturación de micro-gotas.")
                            .font(.system(size: 10))
                            .foregroundColor(Color.black.opacity(0.85))
                    }
                    .padding(16)
                }

                // Lado Derecho: Vista Original (Antes) recortada por máscara
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                        .fill(Color.white)
                    // Gráfico original saturado al 100%
                    VStack(alignment: .leading, spacing: 10) {
                        Text("INFORME EJECUTIVO ANUAL")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)

                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.brandTeal)
                                .frame(width: 40, height: 75)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkMagenta)
                                .frame(width: 40, height: 110)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkYellow)
                                .frame(width: 40, height: 90)
                        }

                        Text("Texto de párrafo continuo optimizado para lectura clara con menor saturación de micro-gotas.")
                            .font(.system(size: 10))
                            .foregroundColor(.black)
                    }
                    .padding(16)
                }
                .mask(
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: max(0, width - dividerX))
                    }
                )

                // Línea divisoria del slider
                Rectangle()
                    .fill(DesignTokens.Colors.brandTeal)
                    .frame(width: 2)
                    .offset(x: dividerX)

                // Tirador central
                Circle()
                    .fill(Color.white)
                    .frame(width: 28, height: 28)
                    .shadow(radius: 4)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.brandTeal)
                    )
                    .offset(x: dividerX - 14, y: height / 2 - 14)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = value.location.x / width
                                sliderPosition = max(0.05, min(0.95, newPos))
                            }
                    )

                // Etiquetas superpuestas
                VStack {
                    HStack {
                        Text("CON INKSAVER (\(ecoLevel.estimatedSavingsPercent)%)")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(4)
                            .background(Color.black.opacity(0.65))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(8)

                        Spacer()

                        Text("ORIGINAL (100%)")
                            .font(.system(size: 9, weight: .heavy))
                            .padding(4)
                            .background(Color.black.opacity(0.65))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(8)
                    }
                    Spacer()
                }
            }
            .cornerRadius(DesignTokens.Radii.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
            )
        }
        .frame(height: 220)
    }
}

/// Centro de Ahorro Inteligente de Tinta InkSaver.
public struct InkSaverCenterView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var inkSaverService = InkSaverService()
    @State private var sliderPos: CGFloat = 0.5
    @State private var estimatedAnnualPages: Double = 1200

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("InkSaver Center")
                        .font(DesignTokens.Fonts.headline)
                    Text("Tecnología de ahorro raster adaptativo con preservación de contraste tipográfico.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // Comparador Visual Interactivo Antes / Después
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Comparador Visual en Tiempo Real")
                            .font(DesignTokens.Fonts.subheadline)
                        Spacer()
                        Text("Arrastra el control deslizante para comparar")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    VisualComparatorView(
                        sliderPosition: $sliderPos,
                        ecoLevel: inkSaverService.activeLevel
                    )

                    // Métricas de Impacto del Comparador
                    HStack(spacing: DesignTokens.Spacing.md) {
                        MetricCard(
                            icon: "percent",
                            title: "Reducción Raster",
                            value: "-\(inkSaverService.activeLevel.estimatedSavingsPercent)%",
                            sublabel: "Estimación de densidad de píxeles",
                            tintColor: .green
                        )

                        MetricCard(
                            icon: "doc.fill",
                            title: "Delta Stream PCL3",
                            value: String(format: "-%.0f KB", Double(inkSaverService.activeLevel.estimatedSavingsPercent) * 3.4),
                            sublabel: "Menor carga en spooler CUPS",
                            tintColor: .blue
                        )

                        MetricCard(
                            icon: "textformat",
                            title: "Nitidez de Texto",
                            value: "100%",
                            sublabel: "Bordes negros puros protegidos",
                            tintColor: .purple
                        )
                    }
                }

                // Selector de Modos InkSaver
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Nivel de Ahorro Seleccionado")
                        .font(DesignTokens.Fonts.subheadline)

                    VStack(spacing: 8) {
                        ForEach(InkSaverLevel.allCases) { level in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(level.rawValue)
                                        .font(DesignTokens.Fonts.bodyMedium)
                                        .foregroundColor(.primary)
                                    Text(level.description)
                                        .font(DesignTokens.Fonts.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                if inkSaverService.activeLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(DesignTokens.Colors.brandTeal)
                                }
                            }
                            .padding(DesignTokens.Spacing.md)
                            .background(
                                inkSaverService.activeLevel == level
                                    ? DesignTokens.Colors.brandTeal.opacity(0.08)
                                    : DesignTokens.Colors.cardBackground
                            )
                            .cornerRadius(DesignTokens.Radii.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                    .stroke(
                                        inkSaverService.activeLevel == level
                                            ? DesignTokens.Colors.brandTeal
                                            : DesignTokens.Colors.borderSubtle,
                                        lineWidth: 1
                                    )
                            )
                            .onTapGesture {
                                inkSaverService.activeLevel = level
                            }
                        }
                    }
                }

                // Calculadora de Ahorro Anual Estimado
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Calculadora de Ahorro Anual")
                        .font(DesignTokens.Fonts.subheadline)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        HStack {
                            Text("Volumen anual estimado de impresión:")
                                .font(DesignTokens.Fonts.captionBold)
                            Spacer()
                            Text("\(Int(estimatedAnnualPages)) páginas/año")
                                .font(DesignTokens.Fonts.metricSmall)
                        }

                        Slider(value: $estimatedAnnualPages, in: 200...10000, step: 100)

                        let savings = inkSaverService.calculateEstimatedSavings(pageCount: Int(estimatedAnnualPages))

                        HStack {
                            Label(
                                String(format: "Ahorro aprox: %.1f ml de tinta", savings.millilitersSaved),
                                systemImage: "drop.fill"
                            )
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(.green)

                            Spacer()

                            Label(
                                String(format: "~ $%.2f USD preservados", savings.dollarsSaved),
                                systemImage: "dollarsign.circle.fill"
                            )
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.cardBackground)
                    .cornerRadius(DesignTokens.Radii.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                            .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                    )
                }

                // Aviso de Transparencia Técnica Obligatoria
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 16))
                    Text(InkSaverService.technicalTransparencyNotice)
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }
                .padding(DesignTokens.Spacing.md)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DesignTokens.Radii.medium)
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}
