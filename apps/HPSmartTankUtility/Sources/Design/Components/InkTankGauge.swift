import SwiftUI

/// Calibrador compacto y sobrio de depósito CISS de tinta.
/// Soporta VoiceOver y diferenciación geométrica sin depender exclusivamente del color.
public struct InkTankGauge: View {
    public let item: SupplyItem

    public init(item: SupplyItem) {
        self.item = item
    }

    public var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxs) {
            // Depósito vertical compacto
            ZStack(alignment: .bottom) {
                // Contenedor exterior
                RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                    )
                    .frame(width: 44, height: 78)

                // Nivel de tinta
                let fillHeight = CGFloat(max(4, min(100, item.level))) * 0.70
                RoundedRectangle(cornerRadius: 4)
                    .fill(item.code == "K" ? Color(red: 0.16, green: 0.16, blue: 0.19) : item.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(item.code == "K" ? Color.white.opacity(0.35) : Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .frame(width: 36, height: fillHeight)
                    .padding(3)

                // Línea de referencia de mínimo físico en depósito
                Rectangle()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 38, height: 1)
                    .offset(y: -14)

                // Símbolo de diferenciación accesible
                Image(systemName: item.shapeSymbol)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(item.code == "K" || item.code == "C" ? .white.opacity(0.9) : .black.opacity(0.8))
                    .offset(y: -6)
            }

            // Porcentaje y Código
            HStack(spacing: 2) {
                Text("\(item.level)%")
                    .font(DesignTokens.Fonts.captionBold)
            }

            Text(item.colorName)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            if item.level <= 15 {
                Label("Bajo", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }

        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityLabel)
    }
}
