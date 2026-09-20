import SwiftUI

/// Vista interactiva para el asistente de calibración cromática ColorSync en bucle cerrado (HP Smart Tank 500).
public struct ColorCalibrationView: View {
    @ObservedObject var printer: PrinterManager
    @ObservedObject private var calibService = ColorCalibrationService.shared
    @ObservedObject private var loc = LocalizationService.shared
    @State private var showingExportSuccess = false
    @State private var showingInstallSuccess = false

    public init(printer: PrinterManager) {
        self.printer = printer
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // MARK: 1. Cabecera
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundColor(.purple)
                            .font(.system(size: 20))
                        Text("Calibración Cromática ColorSync")
                            .font(DesignTokens.Fonts.title)
                    }

                    Text("Modelado espectral de curvas TRC y compensación de ganancia de punto para tintas HP GT51/GT52/GT53.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: 2. Pasos Guiados
                HStack(spacing: DesignTokens.Spacing.md) {
                    stepIndicator(number: 1, title: "1. Imprimir Carta", subtitle: "24 parches ColorChecker", isActive: calibService.currentStep >= 1)
                    stepIndicator(number: 2, title: "2. Escanear a 600 DPI", subtitle: "Análisis espectral y deskew", isActive: calibService.currentStep >= 2)
                    stepIndicator(number: 3, title: "3. Perfil ColorSync", subtitle: "Instalación en macOS", isActive: calibService.currentStep >= 3)
                }

                // MARK: 3. Tarjeta Paso 1: Carta de Calibración
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Paso 1: Generación e Impresión del Patrón de Prueba")
                        .font(DesignTokens.Fonts.sectionHeader)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "doc.text.image.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.purple)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Carta Macbeth ColorChecker de 24 Parches con Rampas CMYK")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Imprime una hoja con dianas de registro en las esquinas, 16 niveles de gris y densidades puras.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Button(action: {
                                calibService.printTargetSheet { _ in }
                            }) {
                                Label("Imprimir Carta", systemImage: "printer")
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)

                            Button(action: {
                                calibService.generateTargetSheet { ok in
                                    if ok {
                                        NSWorkspace.shared.open(URL(fileURLWithPath: calibService.targetPdfPath))
                                    }
                                }
                            }) {
                                Label("Abrir PDF…", systemImage: "arrow.up.forward.app")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: 4. Tarjeta Paso 2: Escaneo y Análisis
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text("Paso 2: Captura y Lectura Espectral")
                        .font(DesignTokens.Fonts.sectionHeader)

                    HStack(spacing: DesignTokens.Spacing.md) {
                        Image(systemName: "scanner.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.blue)
                            .frame(width: 50)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Coloque la hoja impresa en el cristal del escáner")
                                .font(DesignTokens.Fonts.bodyMedium)
                            Text("Asegúrese de alinear la hoja con la esquina superior derecha. El motor compensará automáticamente cualquier desviación angular.")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Button(action: {
                                calibService.runCalibration(mock: false) { result in
                                    if result != nil { showingInstallSuccess = true }
                                }
                            }) {
                                if calibService.isProcessing {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Label("Escanear y Calibrar", systemImage: "play.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(calibService.isProcessing)

                            Button(action: {
                                calibService.runCalibration(mock: true) { result in
                                    if result != nil { showingInstallSuccess = true }
                                }
                            }) {
                                Label("Simular Prueba", systemImage: "wand.and.stars")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(calibService.isProcessing)
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )
                }

                // MARK: 5. Tarjeta Paso 3: Resultados y Perfil ColorSync
                if let res = calibService.lastResult {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text("Paso 3: Diagnóstico Espectral y Perfil Generado")
                            .font(DesignTokens.Fonts.sectionHeader)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                metricTile(title: "ΔE Promedio", value: String(format: "%.2f", res.averageDeltaE), icon: "checkmark.seal.fill", color: .green)
                                metricTile(title: "ΔE Máximo", value: String(format: "%.2f", res.maxDeltaE), icon: "exclamationmark.triangle.fill", color: .orange)
                                metricTile(title: "Gamma R-G-B", value: String(format: "%.2f/%.2f/%.2f", res.rGamma, res.gGamma, res.bGamma), icon: "waveform.path.ecg", color: .purple)
                            }

                            Divider()

                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Perfil ColorSync Activo:")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("~/Library/ColorSync/Profiles/HP_Smart_Tank_500_Precision.icc")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("● INSTALADO")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.green.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                                .stroke(Color.green.opacity(0.4), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
    }

    private func stepIndicator(number: Int, title: String, subtitle: String, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.purple : Color.secondary.opacity(0.3))
                .frame(width: 24, height: 24)
                .overlay(
                    Text("\(number)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isActive ? .primary : .secondary)
                Text(subtitle)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(DesignTokens.Colors.surfaceGrouped)
        .cornerRadius(6)
    }

    private func metricTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }
}
