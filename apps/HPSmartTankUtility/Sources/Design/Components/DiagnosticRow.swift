import SwiftUI

/// Fila estructurada de diagnóstico de subsistema con DisclosureGroup nativo.
public struct DiagnosticRow: View {
    public let item: DiagnosticItem
    @State private var isExpanded: Bool = false

    public init(item: DiagnosticItem) {
        self.item = item
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxs) {
            HStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: item.status.iconName)
                    .foregroundColor(item.status.color)
                    .font(.body)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(DesignTokens.Fonts.bodyMedium)
                    Text(item.message)
                        .font(DesignTokens.Fonts.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(item.subsystem)
                    .font(DesignTokens.Fonts.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(DesignTokens.Radii.small)

                if item.technicalDetails != nil || item.remediationSuggestion != nil {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    if let tech = item.technicalDetails {
                        Text("Detalles:")
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(.secondary)
                        Text(tech)
                            .font(DesignTokens.Fonts.mono)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(4)
                    }

                    if let rem = item.remediationSuggestion {
                        Text("Sugerencia:")
                            .font(DesignTokens.Fonts.captionBold)
                            .foregroundColor(DesignTokens.Colors.statusProcessing)
                        Text(rem)
                            .font(DesignTokens.Fonts.caption)
                            .foregroundColor(.primary)
                    }
                }
                .padding(.leading, 22)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .background(DesignTokens.Colors.surfaceGrouped)
        .cornerRadius(DesignTokens.Radii.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                .stroke(DesignTokens.Colors.border, lineWidth: 1)
        )
    }
}
