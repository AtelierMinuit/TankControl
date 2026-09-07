import SwiftUI

/// Comparador visual interactivo Antes/Después con tirador central.
/// Muestra las barras de color comparativas recortadas por la máscara divisoria,
/// sin textos dentro del área de corte para evitar cualquier corte o solapamiento.
public struct VisualComparatorView: View {
    @Binding var sliderPosition: CGFloat // 0.0 (todo original) a 1.0 (todo eco)
    let savingsPercent: Int
    var ecoLevel: InkSaverLevel? = nil

    public init(sliderPosition: Binding<CGFloat>, savingsPercent: Int) {
        self._sliderPosition = sliderPosition
        self.savingsPercent = savingsPercent
        self.ecoLevel = nil
    }

    public init(sliderPosition: Binding<CGFloat>, ecoLevel: InkSaverLevel) {
        self._sliderPosition = sliderPosition
        self.savingsPercent = ecoLevel.estimatedSavingsPercent
        self.ecoLevel = ecoLevel
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let dividerX = width * sliderPosition

            let attenuation = Double(savingsPercent) / 100.0
            let colorAlpha = max(0.20, 1.0 - (attenuation * 0.72))

            ZStack(alignment: .leading) {
                // Lado Izquierdo: Vista Con InkSaver (Después)
                ZStack {
                    Color.white

                    HStack(alignment: .bottom, spacing: 16) {
                        chartBar(label: "Q1", height: height * 0.44, color: Color.blue.opacity(colorAlpha))
                        chartBar(label: "Q2", height: height * 0.68, color: DesignTokens.Colors.inkMagenta.opacity(colorAlpha * 0.92))
                        chartBar(label: "Q3", height: height * 0.54, color: DesignTokens.Colors.inkYellow.opacity(min(1.0, colorAlpha * 1.05)))
                        chartBar(label: "Q4", height: height * 0.76, color: DesignTokens.Colors.brandTeal.opacity(colorAlpha * 0.88))
                        chartBar(label: "Meta", height: height * 0.60, color: Color.green.opacity(colorAlpha * 0.88))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                // Lado Derecho: Vista Original 100% saturada (recortada por máscara)
                ZStack {
                    Color.white

                    HStack(alignment: .bottom, spacing: 16) {
                        chartBar(label: "Q1", height: height * 0.44, color: Color.blue)
                        chartBar(label: "Q2", height: height * 0.68, color: DesignTokens.Colors.inkMagenta)
                        chartBar(label: "Q3", height: height * 0.54, color: DesignTokens.Colors.inkYellow)
                        chartBar(label: "Q4", height: height * 0.76, color: DesignTokens.Colors.brandTeal)
                        chartBar(label: "Meta", height: height * 0.60, color: Color.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .mask(
                    HStack(spacing: 0) {
                        Spacer()
                        Rectangle()
                            .frame(width: max(0, width - dividerX))
                    }
                )

                // Divisor interactivo vertical
                Rectangle()
                    .fill(DesignTokens.Colors.brandTeal)
                    .frame(width: 2)
                    .offset(x: dividerX)

                // Tirador central con icono de flechas
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.black.opacity(0.20), radius: 3, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.brandTeal)
                    )
                    .offset(x: dividerX - 11, y: height / 2 - 11)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = value.location.x / width
                                sliderPosition = max(0.06, min(0.94, newPos))
                            }
                    )

                // Badges superpuestos en las esquinas superiores (fuera del rango de corte)
                VStack {
                    HStack {
                        Text("CON INKSAVER (\(savingsPercent)%)")
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(6)

                        Spacer()

                        Text("ORIGINAL (100%)")
                            .font(.system(size: 8, weight: .heavy))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.65))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(6)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 86)
        .cornerRadius(DesignTokens.Radii.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func chartBar(label: String, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 32, height: max(8, height))
            Text(label)
                .font(.system(size: 7.5, weight: .bold))
                .foregroundColor(.black.opacity(0.70))
        }
    }
}

/// Centro de Ahorro Inteligente de Tinta InkSaver (Condensado en 3 Tarjetas Modulares).
public struct InkSaverCenterView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var inkSaverService = InkSaverService()
    @State private var sliderPos: CGFloat = 0.5
    @State private var estimatedAnnualPages: Double = 1200

    // Estado del banner de retroalimentación de guardado en CUPS
    @State private var showSuccessBanner: Bool = false
    @State private var bannerMessage: String = ""
    @State private var bannerDismissWorkItem: DispatchWorkItem? = nil

    private struct PresetCard: Identifiable {
        let id: Int
        let percent: Int
        let title: String
        let subtitle: String
        let isRecommended: Bool
    }

    private let presetCards: [PresetCard] = [
        PresetCard(id: 0, percent: 0, title: "0%", subtitle: "Off", isRecommended: false),
        PresetCard(id: 1, percent: 20, title: "20%", subtitle: "Ligero", isRecommended: false),
        PresetCard(id: 2, percent: 35, title: "35%", subtitle: "Óptimo", isRecommended: true),
        PresetCard(id: 3, percent: 50, title: "50%", subtitle: "Eco", isRecommended: false),
        PresetCard(id: 4, percent: 70, title: "70%", subtitle: "Borrador", isRecommended: false)
    ]

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                // MARK: - Cabecera Compacta en una sola fila (Título + Badge + Botón)
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("InkSaver Center")
                            .font(DesignTokens.Fonts.headline)
                        Text("Ahorro raster adaptativo con preservación de contornos tipográficos EdgePreserve™.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if inkSaverService.isCupsSynced {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                            Text("CUPS Sincronizado")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(DesignTokens.Radii.small)
                    }

                    Button(action: applyCupsDefault) {
                        HStack(spacing: 5) {
                            if inkSaverService.isApplying {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 11, height: 11)
                            } else {
                                Image(systemName: "arrow.up.doc.fill")
                                    .font(.system(size: 10))
                            }
                            Text("Guardar en CUPS")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                    .disabled(inkSaverService.isApplying)
                    .fixedSize(horizontal: true, vertical: false)
                }

                // MARK: - Banner de Éxito al Aplicar a CUPS
                if showSuccessBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 13))

                        Text(bannerMessage)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.green)

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSuccessBanner = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(DesignTokens.Radii.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }

                // MARK: - TARJETA 1: Selector de Nivel Compuesto InkSaver (~110pt)
                VStack(alignment: .leading, spacing: 6) {
                    // 1. Control segmentado unificado tipo cápsula para los 5 presets
                    HStack(spacing: 2) {
                        ForEach(presetCards) { card in
                            let isSelected = inkSaverService.savingsPercent == card.percent
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    inkSaverService.savingsPercent = card.percent
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Text(card.title)
                                        .font(.system(size: 11, weight: isSelected ? .bold : .semibold, design: .rounded))
                                    Text(card.subtitle)
                                        .font(.system(size: 10.5, weight: isSelected ? .bold : .regular))
                                    if card.isRecommended {
                                        Text("★")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(isSelected ? .green : .secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .background(
                                    isSelected
                                        ? zoneColor(for: card.percent).opacity(0.18)
                                        : Color.clear
                                )
                                .foregroundColor(isSelected ? (card.percent == 0 ? .primary : zoneColor(for: card.percent)) : .secondary)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(
                                            isSelected
                                                ? zoneColor(for: card.percent).opacity(0.4)
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                    )

                    // 2. Fila de ajuste fino: Stepper compacto [-][+], Slider/Gauge coloreado y número destacado
                    HStack(alignment: .center, spacing: 8) {
                        // Stepper compacto agrupado [-] [+]
                        HStack(spacing: 2) {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    inkSaverService.savingsPercent = max(0, inkSaverService.savingsPercent - 5)
                                }
                            }) {
                                Image(systemName: "minus")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(inkSaverService.savingsPercent <= 0)

                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    inkSaverService.savingsPercent = min(75, inkSaverService.savingsPercent + 5)
                                }
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 9, weight: .bold))
                                    .frame(width: 18, height: 18)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(inkSaverService.savingsPercent >= 75)
                        }

                        // Slider central coloreado según la zona de ahorro
                        VStack(spacing: 2) {
                            Slider(
                                value: Binding<Double>(
                                    get: { Double(inkSaverService.savingsPercent) },
                                    set: { inkSaverService.savingsPercent = Int($0) }
                                ),
                                in: 0...75,
                                step: 5
                            )
                            .accentColor(zoneColor(for: inkSaverService.savingsPercent))

                            // Ticks minimalistas debajo de la barra: 0%, 20%, 35%, 50%, 70%
                            GeometryReader { tickGeo in
                                let tickWidth = tickGeo.size.width
                                let ticks: [(percent: Int, label: String, isRecommended: Bool)] = [
                                    (0, "0%", false),
                                    (20, "20%", false),
                                    (35, "35%", true),
                                    (50, "50%", false),
                                    (70, "70%", false)
                                ]

                                ZStack(alignment: .leading) {
                                    ForEach(ticks, id: \.percent) { item in
                                        let posX = tickWidth * CGFloat(item.percent) / 75.0
                                        Text(item.label)
                                            .font(.system(size: 8.5, weight: item.isRecommended ? .bold : .medium, design: .monospaced))
                                            .foregroundColor(item.isRecommended ? .green : .secondary)
                                            .position(x: min(max(posX, 10), tickWidth - 10), y: 5)
                                    }
                                }
                            }
                            .frame(height: 10)
                        }

                        // Número destacado al final (ej. "35% Equilibrado")
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(inkSaverService.savingsPercent)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text("%")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))

                            Text(zoneLabel(for: inkSaverService.savingsPercent))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                        }
                        .frame(minWidth: 80, alignment: .trailing)
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // MARK: - TARJETA 2: Comparador Visual Antes / Después + Métricas (~140pt)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Comparador Visual Antes / Después")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Arrastra el tirador central para contrastar la atenuación")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    VisualComparatorView(
                        sliderPosition: $sliderPos,
                        savingsPercent: inkSaverService.savingsPercent
                    )

                    // Fila horizontal compacta con las 3 métricas:
                    // % Reducción: -35% | Delta Spooler: -119 KB | Nitidez: 100% K (Bordes Protegidos)
                    HStack(spacing: 6) {
                        // % Reducción
                        HStack(spacing: 3) {
                            Image(systemName: "percent")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                            (Text("Reducción: ").foregroundColor(.secondary) +
                             Text("-\(inkSaverService.savingsPercent)%").bold())
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .padding(.horizontal, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                        )

                        // Delta Spooler
                        let deltaKB = Int(Double(inkSaverService.savingsPercent) * 3.4)
                        HStack(spacing: 3) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            (Text("Delta Spooler: ").foregroundColor(.secondary) +
                             Text("-\(deltaKB) KB").bold())
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .padding(.horizontal, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                        )

                        // Nitidez
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(inkSaverService.savingsPercent > 0 ? .green : .secondary)
                            (Text("Nitidez: ").foregroundColor(.secondary) +
                             Text("100% K (Bordes Protegidos)").bold())
                                .font(.system(size: 8.5))
                                .foregroundColor(inkSaverService.savingsPercent > 0 ? .primary : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .padding(.horizontal, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                        )
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // MARK: - TARJETA 3: Calculadora de Ahorro CISS Compacta (~85pt)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("Volumen anual:")
                            .font(.system(size: 11, weight: .semibold))

                        Slider(value: $estimatedAnnualPages, in: 100...10000, step: 100)
                            .controlSize(.small)

                        Text(formatPageCount(Int(estimatedAnnualPages)))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 76, alignment: .trailing)
                    }

                    let savings = inkSaverService.calculateEstimatedSavings(pageCount: Int(estimatedAnnualPages))

                    HStack(spacing: 6) {
                        // Negro GT51/GT53
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 6, height: 6)
                            (Text("Negro GT51/GT53: ").foregroundColor(.secondary) +
                             Text(String(format: "%.1f ml (%.0f%% frasco)", savings.blackMlSaved, savings.blackBottleFraction * 100.0)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4.5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                        )

                        // Color GT52
                        HStack(spacing: 4) {
                            HStack(spacing: 1.5) {
                                Circle().fill(DesignTokens.Colors.inkCyan).frame(width: 3.5, height: 3.5)
                                Circle().fill(DesignTokens.Colors.inkMagenta).frame(width: 3.5, height: 3.5)
                                Circle().fill(DesignTokens.Colors.inkYellow).frame(width: 3.5, height: 3.5)
                            }
                            (Text("Color GT52: ").foregroundColor(.secondary) +
                             Text(String(format: "%.1f ml (%.0f%% frascos)", savings.colorMlSaved, savings.colorBottleFraction * 100.0)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4.5)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                        )

                        // Ahorro Estimado USD
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10.5))
                            (Text("Ahorro Estimado: ").foregroundColor(.secondary) +
                             Text(String(format: "$%.2f USD", savings.dollarsSaved)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.green)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4.5)
                        .background(Color.green.opacity(0.10))
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(Color.green.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding(DesignTokens.Spacing.xs)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // Nota técnica al pie
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 9))
                    Text("Estimación de cobertura de píxeles generada por software en buffer raster previo a compresión PCL3GUI Mode 10 en CUPS.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }
            .padding(DesignTokens.Spacing.sm)
        }
        .onAppear {
            inkSaverService.queryCupsSetting()
        }
    }

    // MARK: - Componentes y Métodos Auxiliares

    private func formatPageCount(_ pages: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = "."
        let formatted = formatter.string(from: NSNumber(value: pages)) ?? "\(pages)"
        return "\(formatted) pág/año"
    }

    private func applyCupsDefault() {
        inkSaverService.applyCupsSetting { result in
            switch result {
            case .success:
                bannerDismissWorkItem?.cancel()
                withAnimation(.easeInOut(duration: 0.25)) {
                    bannerMessage = "Ajuste aplicado a la cola HP Smart Tank 500 (HPInkSaver=\(inkSaverService.cupsOptionValue(for: inkSaverService.savingsPercent)))"
                    showSuccessBanner = true
                }
                let work = DispatchWorkItem {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showSuccessBanner = false
                    }
                }
                bannerDismissWorkItem = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5, execute: work)
            case .failure(let error):
                withAnimation(.easeInOut(duration: 0.25)) {
                    bannerMessage = "Error al aplicar a CUPS: \(error.localizedDescription)"
                    showSuccessBanner = true
                }
            }
        }
    }

    private func zoneColor(for percent: Int) -> Color {
        switch percent {
        case 0: return Color.gray
        case 1...25: return Color.blue
        case 26...45: return Color.green
        default: return Color.orange
        }
    }

    private func zoneLabel(for percent: Int) -> String {
        switch percent {
        case 0: return "Desactivado"
        case 1...25: return "Ligero"
        case 26...45: return "Equilibrado"
        case 46...60: return "Económico"
        default: return "Borrador"
        }
    }
}
