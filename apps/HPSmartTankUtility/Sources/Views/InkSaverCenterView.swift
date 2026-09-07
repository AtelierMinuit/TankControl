import SwiftUI

/// Comparador visual interactivo Antes/Después con tirador central.
/// Simula con alta fidelidad una hoja de documento real impresa en papel común A4:
/// - Muestra texto negro con contornos 100% K protegidos por el algoritmo EdgePreserve™.
/// - Muestra gráficos e infografías CISS (Cian, Magenta, Amarillo) que atenúan su densidad
///   según el porcentaje de ahorro seleccionado.
/// - Un divisor vertical interactivo permite arrastrar y comparar la densidad original frente a la reducida.
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
            let colorAlpha = max(0.22, 1.0 - (attenuation * 0.70))

            ZStack(alignment: .leading) {
                // LADO IZQUIERDO: Vista Con InkSaver (Después - Tinta reducida)
                documentSheet(isEco: true, colorAlpha: colorAlpha, height: height)

                // LADO DERECHO: Vista Original 100% saturada (recortada por máscara)
                documentSheet(isEco: false, colorAlpha: 1.0, height: height)
                    .mask(
                        HStack(spacing: 0) {
                            Spacer()
                            Rectangle()
                                .frame(width: max(0, width - dividerX))
                        }
                    )

                // Línea divisoria interactiva
                Rectangle()
                    .fill(DesignTokens.Colors.brandTeal)
                    .frame(width: 2)
                    .offset(x: dividerX)

                // Tirador central con icono de flechas izquierda/derecha
                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 1)
                    .overlay(
                        Image(systemName: "arrow.left.and.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(DesignTokens.Colors.brandTeal)
                    )
                    .offset(x: dividerX - 12, y: (height / 2) - 12)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newPos = value.location.x / width
                                sliderPosition = max(0.06, min(0.94, newPos))
                            }
                    )

                // Badges discretos en las esquinas superiores (completamente despejados del contenido)
                VStack {
                    HStack {
                        Text("CON INKSAVER (\(savingsPercent)%)")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.black.opacity(0.72))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(5)

                        Spacer()

                        Text("ORIGINAL (100%)")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(Color.black.opacity(0.72))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                            .padding(5)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 116)
        .cornerRadius(DesignTokens.Radii.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    /// Renderizado de la hoja de documento de muestra
    private func documentSheet(isEco: Bool, colorAlpha: Double, height: CGFloat) -> some View {
        ZStack {
            Color.white

            VStack(alignment: .leading, spacing: 4) {
                // Cabecera del documento simulado (Título y regla con margen para badges)
                HStack(alignment: .firstTextBaseline) {
                    Text("INFORME DE GESTIÓN CISS")
                        .font(.system(size: 7.5, weight: .black))
                        .foregroundColor(Color.black.opacity(0.88))

                    Spacer()

                    Text("HP SMART TANK 500")
                        .font(.system(size: 6.8, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.black.opacity(0.60))
                }
                .padding(.top, 16) // Margen vertical para no solaparse jamás con los badges

                Rectangle()
                    .fill(Color.black.opacity(0.20))
                    .frame(height: 0.8)

                // Área de contenido con texto EdgePreserve 100% K y gráficos CISS
                HStack(alignment: .top, spacing: 14) {
                    // Columna izquierda: Líneas de texto tipográfico simulado (100% K)
                    VStack(alignment: .leading, spacing: 3.5) {
                        HStack(spacing: 3) {
                            Text("EdgePreserve™:")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.black)
                            Text("Texto negro 100% K nítido")
                                .font(.system(size: 6.8, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.75))
                        }

                        // Líneas de párrafo simuladas
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.80))
                            .frame(width: 140, height: 2.2)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.80))
                            .frame(width: 170, height: 2.2)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.80))
                            .frame(width: 125, height: 2.2)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black.opacity(0.80))
                            .frame(width: 155, height: 2.2)
                    }

                    Spacer()

                    // Columna derecha: Gráfico infográfico CISS (C, M, Y, K) con atenuación visual
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Distribución de Tinta")
                            .font(.system(size: 6.8, weight: .bold))
                            .foregroundColor(Color.black.opacity(0.70))

                        HStack(alignment: .bottom, spacing: 6) {
                            cissBar(label: "C", height: height * 0.32, color: DesignTokens.Colors.inkCyan.opacity(colorAlpha))
                            cissBar(label: "M", height: height * 0.40, color: DesignTokens.Colors.inkMagenta.opacity(colorAlpha * 0.95))
                            cissBar(label: "Y", height: height * 0.30, color: DesignTokens.Colors.inkYellow.opacity(min(1.0, colorAlpha * 1.05)))
                            cissBar(label: "K", height: height * 0.44, color: Color.black.opacity(0.88)) // El texto y barras K se mantienen oscuros
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func cissBar(label: String, height: CGFloat, color: Color) -> some View {
        VStack(spacing: 2) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 22, height: max(6, height))
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.65))
        }
    }
}

/// Centro de Ahorro Inteligente de Tinta InkSaver.
/// Diseño ergonómico macOS HIG sin selectores redundantes ni datos sintéticos:
/// - Graduación continua mediante una única línea de control (Slider) con saltos de 5%.
/// - Comparador visual con simulación de documento impreso real y algoritmos EdgePreserve™.
/// - Telemetría transparente CISS de botellas HP GT53/GT52 calculada sobre base estándar.
public struct InkSaverCenterView: View {
    @ObservedObject var printer: PrinterManager
    @StateObject private var inkSaverService = InkSaverService()
    @State private var sliderPos: CGFloat = 0.5

    // Estado del banner de retroalimentación al guardar en CUPS
    @State private var showSuccessBanner: Bool = false
    @State private var bannerMessage: String = ""
    @State private var bannerDismissWorkItem: DispatchWorkItem? = nil

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                // MARK: - Cabecera Compacta (Título + Sincronización CUPS + Botón de Aplicación)
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
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

                // MARK: - TARJETA 1: Graduación Continua (La Línea Única de Porcentaje)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Graduación de Ahorro")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Ajuste raster continuo de 0% a 75%")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    // Fila de control: Steppers [-][+] + Slider de línea única + Badge Numérico
                    HStack(alignment: .center, spacing: 10) {
                        // Stepper de microajuste
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

                        // La línea continua del control deslizante
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding<Double>(
                                    get: { Double(inkSaverService.savingsPercent) },
                                    set: { inkSaverService.savingsPercent = Int($0) }
                                ),
                                in: 0...75,
                                step: 5
                            )
                            .accentColor(zoneColor(for: inkSaverService.savingsPercent))

                            // Marcadores textuales claros debajo de la línea
                            HStack {
                                markerButton(label: "0% Apagado", targetPercent: 0)
                                Spacer()
                                markerButton(label: "20% Ligero", targetPercent: 20)
                                Spacer()
                                markerButton(label: "35% Óptimo ★", targetPercent: 35, isRecommended: true)
                                Spacer()
                                markerButton(label: "50% Económico", targetPercent: 50)
                                Spacer()
                                markerButton(label: "70% Borrador", targetPercent: 70)
                            }
                        }

                        // Indicador numérico principal destacado
                        VStack(alignment: .trailing, spacing: 1) {
                            HStack(alignment: .firstTextBaseline, spacing: 1) {
                                Text("\(inkSaverService.savingsPercent)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                Text("%")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))

                            Text(zoneLabel(for: inkSaverService.savingsPercent))
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                        }
                        .frame(minWidth: 80, alignment: .trailing)
                    }
                }
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // MARK: - TARJETA 2: Comparador Visual Antes / Después + Métricas de RIP
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Comparador Visual Antes / Después")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Arrastra el tirador central para contrastar la densidad")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    VisualComparatorView(
                        sliderPosition: $sliderPos,
                        savingsPercent: inkSaverService.savingsPercent
                    )

                    // Métricas técnicas del motor de rasterización
                    HStack(spacing: 6) {
                        // Reducción de cobertura
                        HStack(spacing: 3) {
                            Image(systemName: "percent")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                            (Text("Reducción: ").foregroundColor(.secondary) +
                             Text(inkSaverService.savingsPercent > 0 ? "-\(inkSaverService.savingsPercent)%" : "0%").bold())
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(zoneColor(for: inkSaverService.savingsPercent))
                                .lineLimit(1)
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

                        // Algoritmo EdgePreserve
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            (Text("Algoritmo: ").foregroundColor(.secondary) +
                             Text("EdgePreserve™ (100% K)").bold())
                                .font(.system(size: 8.5))
                                .foregroundColor(.primary)
                                .lineLimit(1)
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

                        // Formato RIP
                        HStack(spacing: 3) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.blue)
                            (Text("Filtro RIP: ").foregroundColor(.secondary) +
                             Text("PCL3GUI Modo 10").bold())
                                .font(.system(size: 8.5))
                                .foregroundColor(.blue)
                                .lineLimit(1)
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
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // MARK: - TARJETA 3: Rendimiento CISS de Botellas HP GT53 y GT52
                // Basado en cálculo ISO/IEC 24712 por cada 1.000 páginas estándar (sin sliders sintéticos)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Rendimiento CISS Proyectado")
                            .font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Text("Base técnica: 1.000 páginas estándar (ISO/IEC 24712)")
                            .font(.system(size: 9.5))
                            .foregroundColor(.secondary)
                    }

                    let savings = inkSaverService.calculateEstimatedSavings(pageCount: 1000)

                    HStack(spacing: 6) {
                        // Frasco Negro HP GT51 / GT53 (135 ml)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 6, height: 6)
                            (Text("Negro GT53 (135ml): ").foregroundColor(.secondary) +
                             Text(String(format: "%.1f ml", savings.blackMlSaved)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .lineLimit(1)
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

                        // Frascos Color HP GT52 (3 x 70 ml)
                        HStack(spacing: 4) {
                            HStack(spacing: 1.5) {
                                Circle().fill(DesignTokens.Colors.inkCyan).frame(width: 3.5, height: 3.5)
                                Circle().fill(DesignTokens.Colors.inkMagenta).frame(width: 3.5, height: 3.5)
                                Circle().fill(DesignTokens.Colors.inkYellow).frame(width: 3.5, height: 3.5)
                            }
                            (Text("Color GT52 (70ml): ").foregroundColor(.secondary) +
                             Text(String(format: "%.1f ml", savings.colorMlSaved)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .lineLimit(1)
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

                        // Ahorro Estimado en USD
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 10.5))
                            (Text("Ahorro / 1.000 pág: ").foregroundColor(.secondary) +
                             Text(String(format: "$%.2f USD", savings.dollarsSaved)).bold())
                                .font(.system(size: 9, design: .rounded))
                                .foregroundColor(.green)
                                .lineLimit(1)
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
                .padding(DesignTokens.Spacing.sm)
                .background(DesignTokens.Colors.cardBackground)
                .cornerRadius(DesignTokens.Radii.card)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radii.card)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )

                // Nota técnica transparente al pie
                HStack(alignment: .center, spacing: 5) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.secondary)
                        .font(.system(size: 9))
                    Text("Atenuación calculada en buffer raster RGB por el filtro CUPS rastertopcl3gui preservando bordes tipográficos.")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 1)
            }
            .padding(DesignTokens.Spacing.md)
        }
        .onAppear {
            inkSaverService.queryCupsSetting()
        }
    }

    // MARK: - Componentes y Métodos Auxiliares

    private func markerButton(label: String, targetPercent: Int, isRecommended: Bool = false) -> some View {
        let isCurrent = inkSaverService.savingsPercent == targetPercent
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                inkSaverService.savingsPercent = targetPercent
            }
        }) {
            Text(label)
                .font(.system(size: 8.5, weight: isCurrent ? .bold : (isRecommended ? .semibold : .regular), design: .rounded))
                .foregroundColor(isCurrent ? zoneColor(for: targetPercent) : (isRecommended ? .green : .secondary))
                .underline(isCurrent)
        }
        .buttonStyle(.plain)
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
