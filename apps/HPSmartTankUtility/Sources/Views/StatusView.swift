import SwiftUI

/// Vista de Tinta y Estado: Niveles CISS compactos, estado de sensores y verificación visual.
public struct StatusView: View {
    @ObservedObject var printer: PrinterManager

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tinta")
                        .font(DesignTokens.Fonts.title)
                    Text("Niveles estimados de los cuatro depósitos y especificaciones CISS.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Depósitos CISS Compactos
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack {
                        Text("Depósitos CISS")
                            .font(DesignTokens.Fonts.sectionHeader)
                        Spacer()
                        Text("Estimación por conteo de microgotas")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: DesignTokens.Spacing.lg) {
                        Spacer()
                        if printer.supplies.isEmpty || !printer.connectionState.isConnected {
                            EmptyStateView(
                                icon: "drop.triangle",
                                title: "Sin Lectura de Depósitos",
                                message: "Conecta la impresora vía USB para consultar los niveles de tinta."
                            )
                            .frame(minHeight: 130)
                        } else {
                            ForEach(printer.supplies.sorted { (["K", "C", "M", "Y"].firstIndex(of: $0.code) ?? 4) < (["K", "C", "M", "Y"].firstIndex(of: $1.code) ?? 4) }) { item in
                                InkTankGauge(item: item)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(DesignTokens.Colors.surfaceGrouped)
                    .cornerRadius(DesignTokens.Radii.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                            .stroke(DesignTokens.Colors.border, lineWidth: 1)
                    )

                    // Aviso de verificación física en ventana frontal
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "eye.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Comprueba visualmente el nivel en los depósitos transparentes de la impresora. La lectura de software es una estimación.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 2)
                }

                // MARK: - Referencia de Botellas de Repuesto CISS
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text("Botellas de Repuesto Compatibles")
                        .font(DesignTokens.Fonts.sectionHeader)

                    HStack(spacing: DesignTokens.Spacing.sm) {
                        // Negro
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.black)
                                .frame(width: 8, height: 8)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Negro (K)")
                                    .font(DesignTokens.Fonts.captionBold)
                                Text("HP GT53XL (135 ml) / GT51")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )

                        // Colores
                        HStack(spacing: 8) {
                            HStack(spacing: 2) {
                                Circle().fill(DesignTokens.Colors.inkCyan).frame(width: 4, height: 4)
                                Circle().fill(DesignTokens.Colors.inkMagenta).frame(width: 4, height: 4)
                                Circle().fill(DesignTokens.Colors.inkYellow).frame(width: 4, height: 4)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Colores (C, M, Y)")
                                    .font(DesignTokens.Fonts.captionBold)
                                Text("HP GT52 (70 ml c/u)")
                                    .font(DesignTokens.Fonts.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Spacing.sm)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                    }
                }

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Button("Ajustar Ahorro en InkSaver Center…") {
                        printer.selectedSection = .inkSaver
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                    Spacer()

                    Button("Ver actividad de la impresora") {
                        printer.selectedSection = .activity
                    }
                    .buttonStyle(.link)
                    .font(DesignTokens.Fonts.caption)
                }
                .padding(.top, 4)
            }
            .padding(DesignTokens.Spacing.md)
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }
}
