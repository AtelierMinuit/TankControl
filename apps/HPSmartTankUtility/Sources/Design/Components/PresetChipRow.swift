import SwiftUI

/// Fila de presets de un clic para tareas comunes del usuario.
/// Mejora la facilidad de uso sin ocultar los controles técnicos:
/// cada preset solo ajusta valores, el usuario puede refinar después
/// con los pickers avanzados que permanecen intactos.
public struct PresetChipRow: View {
    public struct Preset: Identifiable {
        public let id: String
        public let icon: String
        public let title: String
        public let subtitle: String
        public let action: () -> Void

        public init(id: String, icon: String, title: String, subtitle: String, action: @escaping () -> Void) {
            self.id = id
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
            self.action = action
        }
    }

    public let header: String
    public let presets: [Preset]

    public init(header: String, presets: [Preset]) {
        self.header = header
        self.presets = presets
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(header)
                .font(DesignTokens.Fonts.sectionHeader)
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(presets) { preset in
                    Button(action: preset.action) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(preset.title)
                                    .font(DesignTokens.Fonts.bodyMedium)
                                    .lineLimit(1)
                            }
                            Text(preset.subtitle)
                                .font(DesignTokens.Fonts.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(DesignTokens.Colors.surfaceGrouped)
                        .cornerRadius(DesignTokens.Radii.small)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radii.small)
                                .stroke(DesignTokens.Colors.border, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(preset.subtitle)
                }
            }
        }
    }
}
