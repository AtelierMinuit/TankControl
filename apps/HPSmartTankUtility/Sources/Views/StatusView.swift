import SwiftUI

/// Vista de Tinta y Estado: Niveles CISS compactos, estado de sensores y verificación visual.
public struct StatusView: View {
    @ObservedObject var printer: PrinterManager

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                // Cabecera
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tinta")
                        .font(DesignTokens.Fonts.title)
                    Text("Niveles estimados de los cuatro depósitos.")
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Divider()

                // MARK: - Depósitos CISS Compactos
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    HStack {
                        Text("Depósitos")
                            .font(DesignTokens.Fonts.sectionHeader)
                        Spacer()
                        if printer.useMock {
                            Text("Datos simulados (Mock)")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .cornerRadius(3)
                        } else {
                            Text("Estimación por conteo de gotas")
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: DesignTokens.Spacing.lg) {
                        Spacer()
                        if printer.supplies.isEmpty || (!printer.useMock && !printer.connectionState.isConnected) {
                            EmptyStateView(
                                icon: "drop.triangle",
                                title: "Sin Lectura de Depósitos",
                                message: "Conecta la impresora vía USB para consultar los niveles de tinta."
                            )
                            .frame(minHeight: 140)
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
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Comprueba el nivel real en los depósitos transparentes de la impresora. Estos valores son estimaciones.")
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }

                Text("Los detalles técnicos están disponibles en Desarrollo.")
                    .font(.callout).foregroundColor(.secondary)
            }
            .padding(DesignTokens.Spacing.xl)
        }
    }
}
