import SwiftUI

/// Métrica numérica compacta y sobria para contadores y telemetría.
public struct MetricCard: View {
    public let icon: String
    public let title: String
    public let value: String
    public let sublabel: String
    public let tintColor: Color

    public init(
        icon: String,
        title: String,
        value: String,
        sublabel: String,
        tintColor: Color = .primary
    ) {
        self.icon = icon
        self.title = title
        self.value = value
        self.sublabel = sublabel
        self.tintColor = tintColor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(tintColor)
                Text(title)
                    .font(DesignTokens.Fonts.captionBold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Text(value)
                .font(DesignTokens.Fonts.primaryValue)
                .foregroundColor(.primary)

            Text(sublabel)
                .font(DesignTokens.Fonts.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceGrouped)
        .cornerRadius(DesignTokens.Radii.medium)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.medium)
                .stroke(DesignTokens.Colors.border, lineWidth: 1)
        )
    }
}
