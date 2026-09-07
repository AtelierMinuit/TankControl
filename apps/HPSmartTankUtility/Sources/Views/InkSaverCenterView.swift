import SwiftUI

/// Comparador visual interactivo tipo slider Antes/Después.
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

            // Factor dinámico de atenuación según el Slider:
            // 0% -> 1.0 (sin atenuación, saturación completa)
            // 35% -> ~0.75
            // 70% -> ~0.51
            let attenuation = Double(savingsPercent) / 100.0
            let colorAlpha = max(0.25, 1.0 - (attenuation * 0.70))

            ZStack(alignment: .leading) {
                // Lado Izquierdo: Vista Con InkSaver (Después)
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                        .fill(Color.white)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("INFORME EJECUTIVO ANUAL")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black) // Texto nítido con EdgePreserve

                            Spacer()

                            if savingsPercent > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 9, weight: .bold))
                                    Text("EdgePreserve™ Activo")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .cornerRadius(4)
                            }
                        }

                        HStack(spacing: 8) {
                            // Barras con luminancia dinámicamente atenuada según Slider
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.brandTeal.opacity(colorAlpha))
                                .frame(width: 40, height: 75)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkMagenta.opacity(colorAlpha * 0.92))
                                .frame(width: 40, height: 110)
                            RoundedRectangle(cornerRadius: 3)
                                .fill(DesignTokens.Colors.inkYellow.opacity(min(1.0, colorAlpha * 1.05)))
                                .frame(width: 40, height: 90)
                        }

                        // Párrafo con bordes tipográficos conservados al 100% de contraste negro puro
                        Text("Texto de párrafo continuo optimizado para lectura clara con menor saturación de micro-gotas.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .padding(16)
                }

                // Lado Derecho: Vista Original (Antes) recortada por máscara
                ZStack {
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                        .fill(Color.white)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("INFORME EJECUTIVO ANUAL")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)

                            Spacer()
                        }

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

                // Tirador central interactivo
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

                // Etiquetas superpuestas comparativas
                VStack {
                    HStack {
                        Text("CON INKSAVER (\(savingsPercent)%)")
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

    // Estado para la retroalimentación de aplicación persistente a CUPS
    @State private var showSuccessBanner: Bool = false
    @State private var bannerMessage: String = ""
    @State private var bannerDismissWorkItem: DispatchWorkItem? = nil

    private struct PresetItem: Identifiable {
        let id: Int
        let percent: Int
        let label: String
        let isRecommended: Bool
    }

    private let quickPresets: [PresetItem] = [
        PresetItem(id: 0, percent: 0, label: "Desactivado (0%)", isRecommended: false),
        PresetItem(id: 1, percent: 20, label: "Ligero (20%)", isRecommended: false),
        PresetItem(id: 2, percent: 35, label: "Equilibrado (35%)", isRecommended: true),
        PresetItem(id: 3, percent: 50, label: "Económico (50%)", isRecommended: false),
        PresetItem(id: 4, percent: 70, label: "Máximo (70%)", isRecommended: false)
    ]

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // MARK: - Cabecera
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("InkSaver Center")
                            .font(DesignTokens.Fonts.headline)
                        Text("Tecnología de ahorro raster adaptativo con preservación de contraste tipográfico.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()

                    // Indicador de sincronización con CUPS
                    if inkSaverService.isCupsSynced {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                            Text("CUPS Sincronizado")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(DesignTokens.Radii.small)
                    }
                }

                // MARK: - Banner de Éxito al Aplicar a CUPS
                if showSuccessBanner {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bannerMessage)
                                .font(DesignTokens.Fonts.bodyMedium)
                                .foregroundColor(.green)
                            Text("Ajuste registrado: HPInkSaver=\(inkSaverService.cupsOptionValue(for: inkSaverService.savingsPercent)) (\(inkSaverService.savingsPercent)%). Las aplicaciones de macOS utilizarán esta reducción por omisión.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showSuccessBanner = false
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(Color.green.opacity(0.35), lineWidth: 1)
                    )
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
                }

                Divider()

                // MARK: - Comparador Visual Interactivo Antes / Después
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Comparador Visual en Tiempo Real")
                            .font(DesignTokens.Fonts.subheadline)
                        Spacer()
                        Text("Arrastra el tirador central para contrastar el documento")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    VisualComparatorView(
                        sliderPosition: $sliderPos,
                        savingsPercent: inkSaverService.savingsPercent
                    )

                    // Métricas de Impacto del Comparador
                    HStack(spacing: DesignTokens.Spacing.md) {
                        MetricCard(
                            icon: "percent",
                            title: "Reducción Raster",
                            value: "-\(inkSaverService.savingsPercent)%",
                            sublabel: "Estimación de densidad de píxeles",
                            tintColor: .green
                        )

                        MetricCard(
                            icon: "doc.fill",
                            title: "Delta Stream PCL3",
                            value: String(format: "-%.0f KB", Double(inkSaverService.savingsPercent) * 3.4),
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

                // MARK: - Control Deslizante Continuo y Presets Rápidos
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Configuración del Nivel de Ahorro")
                        .font(DesignTokens.Fonts.subheadline)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                        // 1. Botones de Presets Rápidos (Pills)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Presets rápidos:")
                                .font(DesignTokens.Fonts.captionBold)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ForEach(quickPresets) { preset in
                                    let isSelected = inkSaverService.savingsPercent == preset.percent
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            inkSaverService.savingsPercent = preset.percent
                                        }
                                    }) {
                                        HStack(spacing: 5) {
                                            if isSelected {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.system(size: 11, weight: .bold))
                                            }
                                            Text(preset.label)
                                                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))

                                            if preset.isRecommended {
                                                Text("★")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundColor(isSelected ? .white : .green)
                                            }
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(
                                            isSelected
                                                ? DesignTokens.Colors.brandTeal
                                                : Color(NSColor.controlColor)
                                        )
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .cornerRadius(DesignTokens.Radii.pill)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DesignTokens.Radii.pill)
                                                .stroke(
                                                    isSelected
                                                        ? DesignTokens.Colors.brandTeal
                                                        : DesignTokens.Colors.borderSubtle,
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        Divider()

                        // 2. Control Deslizante Continuo Nativo (0...75, step: 5)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Ajuste continuo:")
                                    .font(DesignTokens.Fonts.captionBold)
                                    .foregroundColor(.secondary)

                                Spacer()

                                Text("\(inkSaverService.savingsPercent)%")
                                    .font(DesignTokens.Fonts.headline)
                                    .foregroundColor(DesignTokens.Colors.brandTeal)

                                Text(levelLabel(for: inkSaverService.savingsPercent))
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Slider(
                                value: Binding<Double>(
                                    get: { Double(inkSaverService.savingsPercent) },
                                    set: { inkSaverService.savingsPercent = Int($0) }
                                ),
                                in: 0...75,
                                step: 5
                            )
                            .accentColor(DesignTokens.Colors.brandTeal)

                            // Etiquetas visuales claras bajo el Slider
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("0%")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Desactivado")
                                        .font(.system(size: 10))
                                }
                                Spacer()

                                VStack(alignment: .center, spacing: 2) {
                                    Text("20%")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Ligero")
                                        .font(.system(size: 10))
                                }
                                Spacer()

                                VStack(alignment: .center, spacing: 2) {
                                    Text("35%")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.green)
                                    Text("Equilibrado Recomendado")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.green)
                                }
                                Spacer()

                                VStack(alignment: .center, spacing: 2) {
                                    Text("50%")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Económico")
                                        .font(.system(size: 10))
                                }
                                Spacer()

                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("70%")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Máximo Borrador")
                                        .font(.system(size: 10))
                                }
                            }
                            .foregroundColor(.secondary)
                        }

                        Divider()

                        // 3. Botón para Establecer como Predeterminado del Sistema en CUPS
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ajuste Predeterminado en CUPS")
                                    .font(DesignTokens.Fonts.captionBold)
                                Text("Guarda 'HPInkSaver=\(inkSaverService.cupsOptionValue(for: inkSaverService.savingsPercent))' en la cola HP Smart Tank 500.")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button(action: applyCupsDefault) {
                                HStack(spacing: 6) {
                                    if inkSaverService.isApplying {
                                        ProgressView()
                                            .scaleEffect(0.65)
                                            .frame(width: 14, height: 14)
                                    } else {
                                        Image(systemName: "checkmark.seal.fill")
                                    }
                                    Text("Establecer como Predeterminado del Sistema")
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 4)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(inkSaverService.isApplying)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.cardBackground)
                    .cornerRadius(DesignTokens.Radii.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                            .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                    )
                }

                // MARK: - Calculadora de Ahorro Precisa GT51 / GT52 / GT53
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    Text("Calculadora de Ahorro y Consumo de Tinta CISS")
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

                        HStack(spacing: DesignTokens.Spacing.md) {
                            // Negro Pigmento GT51 / GT53
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 8, height: 8)
                                    Text("Negro GT51 / GT53")
                                        .font(DesignTokens.Fonts.captionBold)
                                }
                                Text(String(format: "%.1f ml", savings.blackMlSaved))
                                    .font(DesignTokens.Fonts.metricNumber)
                                Text(String(format: "~%.0f%% botella 135ml", savings.blackBottleFraction * 100.0))
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.sm)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(DesignTokens.Radii.small)

                            // Colores Colorante Dye GT52 (C, M, Y)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    HStack(spacing: 2) {
                                        Circle().fill(DesignTokens.Colors.inkCyan).frame(width: 6, height: 6)
                                        Circle().fill(DesignTokens.Colors.inkMagenta).frame(width: 6, height: 6)
                                        Circle().fill(DesignTokens.Colors.inkYellow).frame(width: 6, height: 6)
                                    }
                                    Text("Color GT52 (C/M/Y)")
                                        .font(DesignTokens.Fonts.captionBold)
                                }
                                Text(String(format: "%.1f ml", savings.colorMlSaved))
                                    .font(DesignTokens.Fonts.metricNumber)
                                Text(String(format: "~%.0f%% frasco 70ml", savings.colorBottleFraction * 100.0))
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.sm)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(DesignTokens.Radii.small)

                            // Dinero Preservado en USD
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 5) {
                                    Image(systemName: "dollarsign.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Ahorro Financiero")
                                        .font(DesignTokens.Fonts.captionBold)
                                }
                                Text(String(format: "$%.2f USD", savings.dollarsSaved))
                                    .font(DesignTokens.Fonts.metricNumber)
                                    .foregroundColor(.green)
                                Text("Ahorro proyectado")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(DesignTokens.Spacing.sm)
                            .background(Color(NSColor.windowBackgroundColor))
                            .cornerRadius(DesignTokens.Radii.small)
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

                // MARK: - Aviso de Transparencia Técnica
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
        .onAppear {
            inkSaverService.queryCupsSetting()
        }
    }

    // MARK: - Métodos Auxiliares

    private func applyCupsDefault() {
        inkSaverService.applyCupsSetting { result in
            switch result {
            case .success:
                bannerDismissWorkItem?.cancel()
                withAnimation(.easeInOut(duration: 0.25)) {
                    bannerMessage = "Ajuste aplicado a la cola HP Smart Tank 500"
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

    private func levelLabel(for percent: Int) -> String {
        switch percent {
        case 0: return "(Desactivado)"
        case 1...25: return "(Ahorro Ligero)"
        case 26...45: return "(Equilibrado Recomendado)"
        case 46...60: return "(Económico)"
        default: return "(Máximo Borrador)"
        }
    }
}

